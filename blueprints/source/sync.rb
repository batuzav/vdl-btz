#!/usr/bin/env ruby
# frozen_string_literal: true

# Fuente única del plano: genera tasks.json, el mapa y los pasos de §9 de blueprint.md y los bloques de tarea de
# cada épica a partir de blueprints/source/<slug>/steps.yml.
#
#   ruby blueprints/source/sync.rb vdl-btz-gui           # reescribe las zonas generadas
#   ruby blueprints/source/sync.rb vdl-btz-gui --check   # no escribe nada: sale con 1 si algo no coincide
#
# Solo se tocan las zonas entre marcadores `<!-- GENERATED:... BEGIN -->` y `<!-- GENERATED:... END -->`, y tasks.json
# (conservando el `status` de cada tarea). Todo lo demás del plano se edita a mano.

Encoding.default_external = Encoding::UTF_8 # sin esto, un sistema sin locale UTF-8 lee el plano como ASCII

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
slug = ARGV.find { |a| !a.start_with?("--") } or abort("Uso: ruby blueprints/source/sync.rb <slug> [--check]")
CHECK = ARGV.include?("--check")
BUNDLE = File.join(ROOT, slug)
SOURCE = YAML.safe_load(File.read(File.join(ROOT, "source", slug, "steps.yml")))
EPICS = SOURCE.fetch("epics")
STEPS = SOURCE.fetch("steps")

def fail_source(msg)
  abort("steps.yml inválido: #{msg}")
end

STEPS.each_with_index do |s, i|
  s["n"] = i + 1
  s["checkpoint"] = format("step-%02d-%s", s["n"], s.fetch("slug"))
end
BY_ID = STEPS.to_h { |s| [s["id"], s] }

# Reglas de plantilla: se comprueban aquí para que una edición no pueda romperlas sin que nadie se entere.
fail_source("ids repetidos") unless BY_ID.size == STEPS.size
fail_source("checkpoints repetidos") unless STEPS.map { |s| s["checkpoint"] }.uniq.size == STEPS.size
STEPS.each do |s|
  fail_source("#{s['id']}: título de más de 60 caracteres") if s["title"].size > 60
  fail_source("#{s['id']}: debe tener de 1 a 6 criterios") unless (1..6).cover?(s["acceptance"].size)
  fail_source("#{s['id']}: más de 5 archivos") if s["files"].size > 5
  fail_source("#{s['id']}: new_files debe estar dentro de files") unless (s["new_files"] - s["files"]).empty?
  fail_source("#{s['id']}: épica desconocida #{s['epic']}") unless EPICS.include?(s["epic"])
  s["dependencies"].each do |d|
    fail_source("#{s['id']}: dependencia #{d} inexistente o posterior") unless BY_ID[d] && BY_ID[d]["n"] < s["n"]
  end
end

def tasks_json
  path = File.join(BUNDLE, "tasks.json")
  status = File.exist?(path) ? JSON.parse(File.read(path)).to_h { |t| [t["id"], t["status"]] } : {}
  list = STEPS.map do |s|
    { "id" => s["id"], "title" => s["title"], "epic" => s["epic"], "dependencies" => s["dependencies"],
      "priority" => s["priority"], "acceptance" => s["acceptance"], "verify" => s["verify"],
      "checkpoint" => s["checkpoint"], "files" => s["files"], "status" => status.fetch(s["id"], "pending") }
  end
  "#{JSON.pretty_generate(list)}\n"
end

def step_map
  rows = STEPS.map do |s|
    deps = s["dependencies"].empty? ? "—" : s["dependencies"].map { |d| BY_ID[d]["n"] }.join(", ")
    touches = s["files"].map { |f| "`#{f}`" }.join(", ")
    "| #{s['n']} | #{s['title']} | #{deps} | #{touches} | `#{s['verify'].first.split('  #').first}` |"
  end
  ["| # | Paso | Depende de | Toca | Compuerta |", "|---|---|---|---|---|", *rows].join("\n")
end

def epic_ranges
  EPICS.map do |e|
    ns = STEPS.select { |s| s["epic"] == e }.map { |s| s["n"] }
    "`#{e}` = pasos #{ns.first}–#{ns.last}"
  end.join(", ")
end

def step_block(s)
  last = s["n"] == STEPS.size
  rollback = last ? "# last step: #{s['checkpoint']} is the final rollback target" :
                    "# rollback target if step #{s['n'] + 1} goes wrong: git reset --hard #{s['checkpoint']}"
  [
    "#### Step #{s['n']} — #{s['title']}", "", "**Do**", *s["do"].map { |d| "- #{d}" }, "",
    "**Done when**", *s["acceptance"].map { |a| "- [ ] #{a}" }, "",
    "**Verify**", "```bash", *s["verify"], "```", "",
    "**Checkpoint**", "```bash",
    "git add -A && git commit -m \"step #{s['n']}: #{s['slug']}\"", "git tag #{s['checkpoint']}",
    *s["new_files"].map { |f| "git ls-files --error-unmatch #{f}   # expect: exit 0 — the new file is now committed" },
    rollback, "```", ""
  ].join("\n")
end

def blueprint_region
  intro = "Las épicas agrupan estos mismos pasos: #{epic_ranges}. Un paso = una tarea de `tasks.json` = un bloque de tarea en su épica.\n"
  ["### Step map\n\n#{step_map}\n", intro, *STEPS.map { |s| step_block(s) }].join("\n").chomp
end

def task_block(s)
  deps = s["dependencies"].empty? ? "nothing" : s["dependencies"].map { |d| "`#{d}`" }.join(", ")
  [
    "### `#{s['id']}` — #{s['title']}", "",
    "**Depends on:** #{deps} · **Priority:** #{s['priority']} — metadata for scope cuts, not a running order", "",
    s["direction"], "",
    "**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)", "",
    *s["do"].map { |d| "- #{d}" }, "",
    "**Files**", *s["files"].map { |f| "- `#{f}` — #{s['new_files'].include?(f) ? 'new' : 'edit'}" }, "",
    "**Acceptance**", "",
    "Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.", "",
    *s["acceptance"].each_with_index.map { |a, i| "#{i + 1}. #{a}" }, "",
    "**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.", "",
    "```bash", *s["verify"], "```", "",
    "**Checkpoint**", "", "```bash",
    "git add -A && git commit -m \"#{s['id']}: #{s['title']}\"", "git tag #{s['checkpoint']}", "```", "",
    "Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.", ""
  ].join("\n")
end

def epic_region(epic)
  STEPS.select { |s| s["epic"] == epic }.map { |s| task_block(s) }.join("\n").chomp
end

def replace_region(text, name, content, file)
  re = /(<!-- GENERATED:#{name} BEGIN[^\n]*-->\n).*?(\n<!-- GENERATED:#{name} END -->)/m
  abort("#{file}: faltan los marcadores GENERATED:#{name}") unless text.match?(re)
  text.sub(re) { "#{Regexp.last_match(1)}#{content}#{Regexp.last_match(2)}" }
end

outputs = { File.join(BUNDLE, "tasks.json") => tasks_json }
bp = File.join(BUNDLE, "blueprint.md")
outputs[bp] = replace_region(File.read(bp), "steps", blueprint_region, bp)
EPICS.each do |e|
  f = File.join(BUNDLE, "epics", "#{e}.md")
  outputs[f] = replace_region(File.read(f), "tasks", epic_region(e), f)
end

stale = outputs.reject { |f, text| File.exist?(f) && File.read(f) == text }.keys
if CHECK
  if stale.empty?
    puts "OK: tasks.json, blueprint.md y épicas coinciden con steps.yml"
  else
    warn "Desfasados respecto a steps.yml (ejecuta: ruby blueprints/source/sync.rb #{slug}):"
    stale.each { |f| warn "  #{f.sub("#{ROOT}/", 'blueprints/')}" }
    exit 1
  end
else
  stale.each { |f| File.write(f, outputs[f]) }
  puts stale.empty? ? "Sin cambios: todo coincide con steps.yml" : "Actualizados: #{stale.map { |f| File.basename(f) }.join(', ')}"
end
