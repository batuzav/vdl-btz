"use strict";

// Comportamiento de la pantalla. Los títulos y errores vienen de sitios remotos: todo se escribe con textContent.
(function () {
  const token = document.querySelector('meta[name="vdl-token"]').content;
  const el = {
    dateline: document.getElementById("dateline"),
    theme: document.getElementById("theme-toggle"),
    setup: document.getElementById("setup"),
    setupLabel: document.getElementById("setup-label"),
    setupProgress: document.getElementById("setup-progress"),
    form: document.getElementById("form-add"),
    urls: document.getElementById("urls"),
    modeAudio: document.getElementById("mode-audio"),
    quality: document.getElementById("quality"),
    msg: document.getElementById("msg"),
    jobs: document.getElementById("jobs"),
    empty: document.getElementById("empty"),
    cfgOutput: document.getElementById("cfg-output"),
    cfgQuality: document.getElementById("cfg-quality"),
    cfgCookies: document.getElementById("cfg-cookies"),
    save: document.getElementById("btn-save-config"),
    update: document.getElementById("btn-update-engine"),
  };
  const STATUS = { queued: "EN COLA", running: "DESCARGANDO", done: "LISTO", error: "ERROR", canceled: "CANCELADO" };
  const THEMES = [["auto", "Auto"], ["light", "Claro"], ["dark", "Oscuro"]];
  let pollTimer;

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const say = (text) => { el.msg.textContent = text; };

  async function api(path, method, body) {
    const opts = { method: method || "GET", headers: { "X-VDL-Token": token } };
    if (body !== undefined) {
      opts.body = JSON.stringify(body);
      opts.headers["Content-Type"] = "application/json";
    }
    const res = await fetch(path, opts);
    const json = await res.json();
    if (!json.ok) {
      const err = new Error(json.error.message);
      err.code = json.error.code;
      throw err;
    }
    return json.data;
  }

  function season(month) {
    if (month === 11 || month <= 1) return "Invierno";
    if (month <= 4) return "Primavera";
    if (month <= 7) return "Verano";
    return "Otoño";
  }

  function fillConfig(config) {
    el.cfgOutput.value = config.output || "";
    el.cfgQuality.value = config.quality || "best";
    el.cfgCookies.value = config.cookies || "none";
  }

  // Espera a que termine la instalación en segundo plano mostrando su avance.
  async function watchInstall() {
    for (;;) {
      const s = (await api("/api/state")).setup;
      el.setupLabel.textContent = s.label ? "Instalando " + s.label : "Instalando componentes";
      el.setupProgress.max = 100;
      el.setupProgress.value = s.percent || 0;
      if (s.error) { say(s.error); return s; }
      if (!s.running) return s;
      await sleep(500);
    }
  }

  async function firstRunSetup() {
    el.setup.hidden = false;
    try { await api("/api/setup", "POST"); } catch (err) { if (err.code !== "already_running") say(err.message); }
    const s = await watchInstall();
    if (s.ytdlp && !s.error) el.setup.hidden = true;
  }

  function button(label, onClick) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.addEventListener("click", onClick);
    return b;
  }

  function row(job, index) {
    const li = document.createElement("li");
    if (job.status === "error") li.className = "is-error";
    const title = document.createElement("div");
    title.className = "job-title";
    title.textContent = String(index + 1).padStart(2, "0") + " · " + (job.title || job.url);
    const meta = document.createElement("div");
    meta.className = "job-meta";
    const platform = document.createElement("span");
    platform.textContent = job.platform;
    const status = document.createElement("span");
    status.className = "status";
    status.textContent = STATUS[job.status] || job.status;
    meta.append(platform, status);
    li.append(title, meta);
    if (job.status === "queued" || job.status === "running") {
      const bar = document.createElement("progress");
      bar.max = 100;
      bar.value = job.percent || 0;
      bar.setAttribute("aria-label", "Progreso de la descarga");
      li.append(bar);
      li.append(button("Cancelar", () => api("/api/jobs/" + job.id + "/cancel", "POST").then(refresh).catch((e) => say(e.message))));
    }
    if (job.status === "done") {
      li.append(button("Abrir carpeta", () => api("/api/open", "POST", { id: job.id }).catch((e) => say(e.message))));
    }
    if (job.error) {
      const note = document.createElement("p");
      note.textContent = job.error + (job.hint ? " " + job.hint : "");
      li.append(note);
    }
    return li;
  }

  function render(jobs) {
    el.jobs.replaceChildren(...jobs.map(row));
    el.empty.hidden = jobs.length > 0;
  }

  async function refresh() {
    clearTimeout(pollTimer);
    let jobs = [];
    try {
      jobs = (await api("/api/jobs")).jobs;
      render(jobs);
    } catch (err) {
      say(err.message);
    }
    const active = jobs.some((j) => j.status === "queued" || j.status === "running");
    pollTimer = setTimeout(refresh, active ? 500 : 2000);
  }

  function applyTheme(mode) {
    if (mode === "auto") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", mode);
    el.theme.textContent = "Tema: " + THEMES.find((t) => t[0] === mode)[1];
    try { localStorage.setItem("vdl-theme", mode); } catch (err) { /* sin almacenamiento: no pasa nada */ }
  }

  function initTheme() {
    let mode = "auto";
    try { mode = localStorage.getItem("vdl-theme") || "auto"; } catch (err) { /* idem */ }
    if (!THEMES.some((t) => t[0] === mode)) mode = "auto";
    applyTheme(mode);
    el.theme.addEventListener("click", () => {
      const i = THEMES.findIndex((t) => t[0] === (document.documentElement.getAttribute("data-theme") || "auto"));
      applyTheme(THEMES[(i + 1) % THEMES.length][0]);
    });
  }

  el.form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const urls = el.urls.value.split("\n").map((s) => s.trim()).filter(Boolean);
    try {
      await api("/api/jobs", "POST", { urls: urls, audio: el.modeAudio.checked, quality: el.quality.value });
      say("");
      el.urls.value = "";
      refresh();
    } catch (err) {
      say(err.message); // el texto de #urls se conserva para no obligar a reescribirlo
    }
  });

  el.save.addEventListener("click", async () => {
    try {
      const data = await api("/api/config", "POST", {
        output: el.cfgOutput.value, quality: el.cfgQuality.value, cookies: el.cfgCookies.value || "none",
      });
      fillConfig(data.config);
      say("Ajustes guardados.");
    } catch (err) {
      say(err.message);
    }
  });

  el.update.addEventListener("click", async () => {
    try {
      await api("/api/engine/update", "POST");
      say("Actualizando el motor…");
      const s = await watchInstall();
      if (!s.error) say("Motor actualizado.");
    } catch (err) {
      say(err.message);
    }
  });

  async function init() {
    initTheme();
    const state = await api("/api/state");
    el.dateline.textContent = "N°01 · " + season(new Date().getMonth()) + " " + new Date().getFullYear() + " · v" + state.version;
    fillConfig(state.config);
    setInterval(() => api("/api/ping", "POST").catch(() => {}), 2000);
    if (!state.setup.ytdlp) await firstRunSetup();
    refresh();
  }

  init().catch((err) => say(err.message));
})();
