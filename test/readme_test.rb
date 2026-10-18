# frozen_string_literal: true

require "test_helper"

class ReadmeTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  README = File.read(File.join(ROOT, "README.md"))

  # Texto de una sección de nivel 2 (hasta el siguiente "## ").
  def section(title)
    README[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1] or flunk("falta el encabezado '## #{title}'")
  end

  def test_required_headings_exist
    ["App de escritorio", "Descargas", "Requisitos de sistema", "Si el sistema bloquea la app", "Aviso legal"].each { |t| section(t) }
  end

  def test_downloads_section_names_every_artifact_and_the_releases_page
    s = section("Descargas")
    %w[vdl-btz-macos-arm64 vdl-btz-macos-x64 vdl-btz-linux-x64 vdl-btz-windows-x64-setup.exe
       https://github.com/batuzav/vdl-btz/releases].each { |frag| assert_includes s, frag }
  end

  def test_blocked_app_section_explains_macos_and_windows
    s = section("Si el sistema bloquea la app")
    ["xattr -d com.apple.quarantine", "SmartScreen"].each { |frag| assert_includes s, frag }
  end

  def test_system_requirements_and_cli_note
    s = section("Requisitos de sistema")
    ["macOS 15", "Ubuntu 24.04"].each { |frag| assert_includes s, frag }
    assert_includes section("App de escritorio"), "vdl-btz help"
  end

  def test_relative_links_point_to_existing_files
    README.scan(/\]\(([^)\s]+)\)/).flatten.reject { |l| l.start_with?("http", "#", "mailto:") }.each do |link|
      assert File.exist?(File.join(ROOT, link.split("#").first)), "enlace roto en el README: #{link}"
    end
  end
end
