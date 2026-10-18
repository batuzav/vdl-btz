# Epic 02: API, pantalla de periódico y ventana

> Existe la aplicación completa en local: API, página con el diseño de periódico, comportamiento en el navegador y una ventana propia que se abre sola.

| | |
|---|---|
| **Epic id** | `02-pantalla` |
| **Tasks** | `E2-T1` … `E2-T5` |
| **Depends on** | 01-nucleo |
| **Unlocks** | 03-empaquetado |
| **Parallel with** | nothing (comparte `cli.rb`, `os.rb` y `server.rb` con la épica 01) |

You do not need any other file to complete this epic. Everything below is repeated here on purpose.

---

## Stack

Ruby (la versión del binario empaquetado está en `.github/workflows/build.yml`) · biblioteca estándar solamente, sin gemas de ejecución · Minitest + rake para pruebas · servidor HTTP local propio sobre `socket` · interfaz en HTML/CSS/JS planos · GitHub Actions + Tebako para empaquetar. Gestor de paquetes: Bundler solo para desarrollo (el `Gemfile` contiene únicamente `gemspec`). Las versiones de desarrollo están en `vdl-btz.gemspec`; no hay archivo de versión de Ruby ni dependencias de ejecución.

| Tarea | Comando |
|---|---|
| Instalar dependencias de desarrollo | `bundle install` |
| Todas las pruebas | `rake test` |
| Una prueba | `ruby -Ilib -Itest test/<archivo>_test.rb` |
| Ejecutar el CLI | `ruby bin/vdl-btz <argumentos>` |
| Servidor sin ventana | `ruby bin/vdl-btz gui --no-window` |
| Lint / typecheck | el proyecto no define ninguno |
| Servicios locales | ninguno |

**Gate:** `rake test` termina con estado 0 antes de marcar cualquier tarea de esta épica como hecha.

## Directory subtree

Solo lo que toca esta épica:

```
lib/
  vdl_btz.rb                     # edit (T1, T5): require_relative de api y shell
  vdl_btz/
    cli.rb                       # edit (T1, T5): cablea cola + API; abre la ventana
    os.rb                        # edit (T2, T5): open_path, open_url
    gui/
      server.rb                  # edit (T1, T3): delegación al handler, GET / y /assets/
      api.rb                     # NEW (T1), edit (T2): rutas de la API
      shell.rb                   # NEW (T5): ventana de aplicación y respaldo
      jobs.rb                    # existe (épica 01), solo lectura
      assets/
        index.html               # NEW (T3), edit (T4)
        app.css                  # NEW (T3)
        app.js                   # NEW (T4)
        fonts/hanken-grotesk-var.woff2   # existe (copiado desde workspace/), NO modificar
        fonts/space-mono-400.woff2       # existe, NO modificar
        fonts/space-mono-700.woff2       # existe, NO modificar
vdl-btz.gemspec                  # edit (T3): spec.files incluye html/css/js/woff2
test/
  gui_api_jobs_test.rb           # NEW (T1)
  gui_api_settings_test.rb       # NEW (T2)
  gui_assets_test.rb             # NEW (T3), edit (T4)
  gui_shell_test.rb              # NEW (T5)
  test_helper.rb                 # edit (T2): aísla HOME en las pruebas
```

Todo lo que no aparezca arriba queda fuera de esta épica.

## Data model touched here

| Entidad | Campos | Notas |
|---|---|---|
| `Job` (solo memoria, de la épica 01) | `id, url, platform, status, title, percent, speed, eta, file, error, hint, audio, quality` | la API lo serializa con `to_h` |
| `config.yml` (existente) | `output` (ruta), `quality` (`best/2160/1440/1080/720/480/360`), `cookies` (`nil` o navegador) | formato YAML que escribe `Config#set`; NO cambies su formato ni sus claves |
| Estado de instalación (solo memoria, en `Api`) | `running, label, percent, error` | se recalcula `ytdlp`/`ffmpeg` en cada `GET /api/state` |

## Contracts

**Consumed** — ya existen (épica 01 y código previo), no los reescribas:

| De | Interfaz | Garantía |
|---|---|---|
| `gui/server.rb` | `Server.new(token:, handler: nil, port: 0, idle_timeout: nil)`, `#start`, `#stop`, `#join`; rutas propias `/api/health`, `/api/shutdown`, `/api/ping` | seguridad y cabeceras ya aplicadas antes de cualquier ruta |
| `gui/jobs.rb` | `JobQueue.new(workers:, runner:)`, `#add`, `#list`, `#cancel`, `#shutdown`, `JobQueue.downloader_runner(installer:, config:)` | `add` lanza `VdlBtz::Error` con `URL inválida: <url>` si alguna URL es inválida |
| `installer.rb` | `Installer#ytdlp_path`, `#ffmpeg_path`, `#deno_path`, `#ensure_ytdlp!`, `#ensure_ffmpeg`, `#ensure_deno!`, `#install_ytdlp`, `#on_progress=` | las rutas son `String` o `nil` |
| `config.rb` | `Config.load`, `#[]`, `#to_h`, `#set(clave, valor)` (valida y persiste), `Config.normalize_quality`, `Config::QUALITIES`, `Config::BROWSERS`, `#path` | `set` lanza `VdlBtz::Error` si el valor es inválido |
| `paths.rb`, `os.rb` | `Paths.home`, `Paths.config_file`, `OS.name`, `OS.windows?`, `OS.which` | — |

**Produced** — lo que consumen las tareas siguientes y la épica 03:

| Export | Firma | Usado por |
|---|---|---|
| `gui/api.rb` → `VdlBtz::GUI::Api` | `new(queue:, config:, installer:, opener: OS.method(:open_path))`, `#call(request) → [estado, cabeceras, cuerpo]` | `cli.rb`, pruebas |
| `os.rb` → `OS.open_path(path)`, `OS.open_url(url)` | devuelven `true`/`false`; usan arrays de argumentos | `api.rb`, `shell.rb` |
| `gui/shell.rb` → `VdlBtz::GUI::Shell` | `window_args(exe, url, profile_dir)`, `candidates(os, env: ENV)`, `launch(url, **inyectables) → :app_window/:browser/:manual` | `cli.rb` |
| `gui/assets/*` | los archivos y ids del contrato DOM y de diseño | `server.rb`, épica 03 (se empaquetan dentro del binario) |

**Contrato del servidor local** (`VdlBtz::GUI::Server`, solo stdlib):

| Aspecto | Regla |
|---|---|
| Enlace de red | `TCPServer.new("127.0.0.1", port)`; nunca `0.0.0.0` ni `localhost`; `port` 0 = puerto efímero |
| Token | `SecureRandom.hex(16)` (32 hex minúsculas) generado por el comando `gui`; las rutas `/api/*` exigen la cabecera `X-VDL-Token` |
| Primera línea de stdout del comando `gui` | exactamente `URL: http://127.0.0.1:<puerto>/?t=<token>` |
| Orden de comprobaciones | petición mal formada (`400 bad_request`) → `Host` ajeno (`403 bad_host`) → `Content-Length` > 65536 (`413 too_large`) → si la ruta empieza por `/api/`, token (`401 unauthorized`) → ruta conocida con método no admitido (`405 method_not_allowed`) o desconocida (`404 not_found`) → ejecutar la ruta |
| `Host` permitido | `127.0.0.1:<puerto>` o `localhost:<puerto>` |
| Cabeceras en TODA respuesta | `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Content-Security-Policy: default-src 'self'; img-src 'self' data:; frame-ancestors 'none'`, `Content-Length`, `Connection: close` |
| Sobre JSON | éxito `{"ok":true,"data":{...}}`; error `{"ok":false,"error":{"code":"<código>","message":"<texto en español>"}}` |
| Rutas propias | `GET /api/health` → `data.version`; `POST /api/shutdown` → `data` `{}` y detiene el servidor; `POST /api/ping` → `data` `{}` y reinicia el temporizador de inactividad |
| Inactividad | `idle_timeout:` segundos (`nil` = sin límite); si pasa desde el arranque o desde el último `POST /api/ping` autenticado, el servidor se detiene |
| Delegación | rutas no propias → `handler.call(request)`; `request` = `Struct` `(method, path, query, headers, body)`; el `handler` devuelve `[estado, cabeceras_extra, cuerpo]` o `nil` (→ `404 not_found`) |

**Rutas de la aplicación:**

| Método | Ruta | Cuerpo / respuesta `data` | Errores |
|---|---|---|---|
| GET | `/api/health` | `{version}` | 401 |
| POST | `/api/ping` | `{}` | 401 |
| POST | `/api/shutdown` | `{}` | 401 |
| GET | `/api/state` | `{version, os, config, qualities, browsers, setup}`; `setup` = `{ytdlp, ffmpeg, deno, running, label, percent, error}` | 401 |
| POST | `/api/jobs` | entrada `{urls:[...], audio:bool, quality:"..."}` → `202` `{jobs:[...]}` | 400 `bad_json` · `no_urls` · `invalid_url` · `invalid_quality`; 409 `setup_required` |
| GET | `/api/jobs` | `{jobs:[...]}` | 401 |
| POST | `/api/jobs/<id>/cancel` | `{jobs:[job]}` | 404 `not_found` |
| POST | `/api/config` | entrada `{output?, quality?, cookies?}` → `{config}` | 400 `invalid_config` |
| POST | `/api/setup` | `202` `{setup}` | 409 `already_running` |
| POST | `/api/engine/update` | `202` `{setup}` | 409 `already_running` |
| POST | `/api/open` | entrada `{id}` o `{}` → `{opened:true}` | 404 `no_file` |
| GET | `/` (con `?t=<token>`) | HTML | 401 |
| GET | `/assets/<lista blanca>` | `app.css`, `app.js`, `fonts/hanken-grotesk-var.woff2`, `fonts/space-mono-400.woff2`, `fonts/space-mono-700.woff2` | 404 `not_found` |

**Registro `Job`** (solo en memoria): `id` (8 hex), `url`, `platform` (`youtube`/`tiktok`/`instagram`/`facebook`/`otros`), `status` (`queued`/`running`/`done`/`error`/`canceled`), `title`, `percent` (0–100), `speed`, `eta`, `file`, `error`, `hint`, `audio`, `quality`.

**Contrato DOM de la página** (los ids son exactos; las pruebas los buscan):

| id | Elemento | Función |
|---|---|---|
| `masthead` | `<header>` con `<h1>` «VDL-BTZ» | cabecera de periódico |
| `dateline` | `<p>` | `N°01 · <Estación> <año> · v<versión>` en Space Mono |
| `theme-toggle` | `<button type="button">` | alterna Auto / Claro / Oscuro |
| `setup` | `<section hidden>` | pantalla «Preparando la herramienta…» del primer uso |
| `setup-label` | `<p>` | paso en curso |
| `setup-progress` | `<progress max="100">` | avance de la instalación |
| `form-add` | `<form>` | formulario de descarga |
| `urls` | `<textarea>` | enlaces, uno por línea |
| `mode-video`, `mode-audio` | `<input type="radio" name="mode">` | video o solo audio |
| `quality` | `<select>` | `best`, `2160`, `1440`, `1080`, `720`, `480`, `360` |
| `btn-add` | `<button type="submit">` | «Descargar» |
| `msg` | `<div role="status" aria-live="polite">` | mensajes y errores |
| `jobs` | `<ol tabindex="0" aria-label="Lista de descargas">` | lista de descargas con scroll interno |
| `empty` | `<p>` | «Todavía no hay descargas.» |
| `cfg-output` | `<input type="text">` | carpeta de destino |
| `cfg-quality` | `<select>` | calidad por defecto |
| `cfg-cookies` | `<select>` | `none` + navegadores |
| `btn-save-config` | `<button type="button">` | «Guardar ajustes» |
| `btn-update-engine` | `<button type="button">` | «Actualizar motor» |
| `legal` | `<footer>` | aviso legal |

Estructura: enlace «Saltar al contenido» (`<a class="skip" href="#main">`) → `<header id="masthead">` → `<main id="main">` con tres secciones numeradas «01 Pega un enlace» (formulario), «02 En cola» (lista) y «03 Ajustes», más `#setup` → `<footer id="legal">`. Sin scripts ni estilos en línea; `<script src="/assets/app.js" defer>`.

**Sistema de diseño — «periódico»** (extraído de batuzav.com el 2026-10-16; monocromo, sin color de acento):

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `--paper` | `#ece9e1` | `#0c0b09` | fondo de página |
| `--paper-2` | `#e3dfd4` | `#131210` | franjas, campos |
| `--ink` | `#000000` | `#ede8db` | texto, bordes de botón, foco |
| `--ink-soft` | `#1b1b17` | `#d8d2c4` | texto secundario |
| `--rule` | `#000000` | `#ede8db` | filetes (1–2 px) |
| `--grain-opacity` | `.055` | `.07` | textura de grano |
| `--grain-blend` | `multiply` | `screen` | mezcla del grano |

Tema oscuro: `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { … } }` y `:root[data-theme="dark"] { … }`; `:root[data-theme="light"]` fuerza el claro.

Tipografía (autoalojada, `font-display: swap`; respaldo `system-ui, sans-serif` y `ui-monospace, monospace`): título `Hanken Grotesk` 800, `clamp(2.6rem, 9vw, 6rem)`, interlineado .9, mayúsculas, `letter-spacing: -.02em`; encabezados de sección `Hanken Grotesk` 700, 1.1rem, mayúsculas, `letter-spacing: .06em`, con el número («01») en `Space Mono`; cuerpo `Hanken Grotesk` 400, 1rem/1.55; etiquetas y estados `Space Mono`, mayúsculas, `clamp(.62rem, 1.3vw, .74rem)`, `letter-spacing: .12em` (la línea de fecha `.2em`).

Maquetación: ancho máximo 1100 px; espacio base 4 px (4, 8, 12, 16, 24, 32, 48, 64); radio 0 (esquinas rectas); sin sombras (solo filetes); cabecera con `border-top: 2px solid var(--rule)` y `border-bottom: 1px solid var(--rule)`; cada sección con `border-top: 2px solid var(--rule)`; cada trabajo con `border-bottom: 1px solid var(--rule)` y, si falla, `border-bottom: 3px double var(--rule)`; a partir de 900 px dos columnas `1.15fr 1fr` separadas por un filete vertical de 1 px (izquierda: «01» y «03»; derecha: «02», que ocupa el alto de la izquierda y hace scroll interno en `#jobs` con `overflow-y: auto`); por debajo, una columna con `#jobs` limitado a `max-height: 70vh` con scroll.

Controles: botones con `border: 2px solid var(--ink)`, fondo transparente, texto `Space Mono` en mayúsculas, altura mínima 44 px; al pasar el puntero o enfocar se invierten (fondo `--ink`, texto `--paper`); foco visible `outline: 2px solid var(--ink); outline-offset: 2px`. Estados de trabajo en `Space Mono` mayúsculas: `EN COLA`, `DESCARGANDO`, `LISTO`, `ERROR`, `CANCELADO`; el estado nunca se comunica solo con color (no hay colores de acento). `<progress>` con `appearance: none`, alto 6 px, borde de 1 px y relleno `var(--ink)`.

Grano: `body::before` fijo (`position: fixed; inset: 0; pointer-events: none`), `opacity: var(--grain-opacity)`, `mix-blend-mode: var(--grain-blend)` y fondo `url("data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")`.

Movimiento: ninguna animación ni transición; `@media (prefers-reduced-motion: reduce)` se declara igualmente y no cambia nada.

Contraste medido (WCAG 2.2): tinta sobre papel claro 17.31:1; `--ink-soft` sobre `--paper-2` claro 12.97:1; tinta sobre papel oscuro 16.08:1; `--ink-soft` sobre `--paper-2` oscuro 12.42:1.

**Fuentes autoalojadas** (ya presentes; la prueba comprueba su SHA-256):

| Archivo (en `lib/vdl_btz/gui/assets/fonts/`) | Familia | Peso | Bytes | SHA-256 |
|---|---|---|---|---|
| `hanken-grotesk-var.woff2` | Hanken Grotesk (variable, latín) | 400–900 | 34664 | `1f21c6eaa0000f3329cfcfac966b43d5bebf5aa610303e33294ac31bc6f4bb59` |
| `space-mono-400.woff2` | Space Mono (latín) | 400 | 9464 | `e0c8e616bda27642f4c3cebaecff6525d901e73afc8a227cbbb0f2af4810f300` |
| `space-mono-700.woff2` | Space Mono (latín) | 700 | 9552 | `af7cf6d2b897ec453acdcdacde4e9bcc8410718af5914de865b453e09f10eebc` |

**Contrato de la ventana** (`VdlBtz::GUI::Shell`):

| Sistema | Candidatos, en orden |
|---|---|
| macOS (`:mac`) | `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` · `/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge` · `/Applications/Brave Browser.app/Contents/MacOS/Brave Browser` · `/Applications/Chromium.app/Contents/MacOS/Chromium` |
| Windows (`:windows`) | para cada base de `[env["ProgramFiles"], env["ProgramFiles(x86)"], env["LOCALAPPDATA"]]` (las nulas se omiten): `<base>\Microsoft\Edge\Application\msedge.exe`, `<base>\Google\Chrome\Application\chrome.exe`, `<base>\BraveSoftware\Brave-Browser\Application\brave.exe` |
| Linux (`:linux`) | nombres resueltos con `OS.which`: `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, `microsoft-edge`, `brave-browser` |

Argumentos de la ventana: `[exe, "--app=<url>", "--user-data-dir=<Paths.home>/gui-profile", "--no-first-run", "--window-size=980,780"]`. Cadena de respaldo: ventana de aplicación (`:app_window`) → navegador por defecto con `OS.open_url` (`:browser`) → solo imprimir `Abre esta dirección en tu navegador: <url>` (`:manual`).

## Conventions that bite in this area

- Cada archivo Ruby empieza con `# frozen_string_literal: true` y vive dentro de `module VdlBtz`; los errores controlados son `VdlBtz::Error` (el CLI los muestra sin traza) y todo texto para el usuario va en español.
- Solo biblioteca estándar. Si crees que necesitas una gema, detente e informa: cada gema nueva rompe el empaquetado (el binario se arma desde una carpeta sin `Gemfile`).
- Las rutas se construyen con `File.join`/`File.expand_path` y nunca se asume `/` como raíz: las pruebas corren también en Windows (ahí `File.expand_path("/tmp/x")` devuelve `D:/tmp/x`).
- Las pruebas usan la `VDL_BTZ_HOME` temporal que ya fija `test/test_helper.rb` (desde la tarea E2-T2 también `HOME`); nunca escribas, crees ni borres nada fuera de directorios temporales y nunca uses `rm_rf` sobre una ruta que no hayas comprobado que está bajo `Dir.tmpdir`.
- `Process.spawn`/`Open3` siempre con array de argumentos, nunca con una cadena de shell.
- No hay `.claude/commands/`; las reglas de área están en `.claude/rules/` y las instrucciones completas en `CLAUDE.md` (ambos en la raíz del proyecto).
- **Seguridad del navegador:** los títulos y errores de los trabajos vienen de sitios remotos. `app.js` los escribe SOLO con `textContent`/`createElement`; está prohibido `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `eval(` y `document.write` (una prueba lo comprueba).
- La política CSP (`default-src 'self'`) prohíbe scripts y estilos en línea: nada de `<script>…</script>` con código ni de `style="…"`; el token llega en un `<meta>`.
- La API nunca recibe rutas del cliente para abrir carpetas: solo ids de trabajo (o nada).
- El diseño es monocromo: no añadas colores de acento, sombras ni bordes redondeados; el estado se comunica con texto en mayúsculas, no con color.
- `Shell` no abre nada por sí solo en las pruebas: todo lo que toca el sistema entra por parámetros inyectables.

Reglas completas: `CLAUDE.md`. Reglas de área: `.claude/rules/ruby-gui.md`, `.claude/rules/assets.md` y `.claude/rules/tests.md`, todas en la raíz del proyecto.

---

## Tasks

Listed in the same order as `tasks.json`. That order is the build order — work top to bottom and do not re-rank by priority or by what looks quick.

<!-- GENERATED:tasks BEGIN — no editar a mano: lo genera blueprints/source/sync.rb desde blueprints/source/vdl-btz-gui/steps.yml -->
### `E2-T1` — Add jobs API routes and wire the gui command

**Depends on:** `E1-T2`, `E1-T5` · **Priority:** p0 — metadata for scope cuts, not a running order

`Api` no toca sockets: recibe un `Request` y devuelve un triple, así que se prueba sin red. Mantén el orden de validación fijo para que los códigos de error sean predecibles para la pantalla. El instalador falso del test es un objeto con los mismos métodos públicos que `Installer`.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/gui/server.rb` — si una ruta no es propia del servidor (`/api/health`, `/api/shutdown`, `/api/ping`) y `handler` no es nulo, llamar `handler.call(request)`; `request` es un `Struct` `Request(:method, :path, :query, :headers, :body)` (`headers` con claves en minúsculas, `query` como `Hash` de `String`) y el `handler` devuelve `[estado, cabeceras_extra, cuerpo_string]`; el servidor añade las cabeceras de seguridad, `Content-Length` y `Connection`. La autenticación por token de `/api/` sigue ocurriendo antes. Si `handler` devuelve `nil` → `404 not_found`.
- `lib/vdl_btz/gui/api.rb` — clase `VdlBtz::GUI::Api` con `initialize(queue:, config:, installer:)` y `call(request)`; respuestas siempre en el sobre `{"ok":true,"data":...}` o `{"ok":false,"error":{"code":...,"message":...}}`. Rutas: `GET /api/state` → `data` con `version` (`VdlBtz::VERSION`), `os` (`OS.name`), `config` (`config.to_h`), `qualities` (`Config::QUALITIES`), `browsers` (`Config::BROWSERS`) y `setup` = `{ytdlp: <bool>, ffmpeg: <bool>, deno: <bool>, running: false, label: nil, percent: nil, error: nil}` donde `ytdlp`/`ffmpeg`/`deno` son `!installer.ytdlp_path.nil?` / `!installer.ffmpeg_path.nil?` / `!installer.deno_path.nil?`; `POST /api/jobs` con cuerpo JSON `{"urls":[...],"audio":bool,"quality":"..."}`; `GET /api/jobs` → `data.jobs` = `queue.list`; `POST /api/jobs/<id>/cancel` → `200` con `data.jobs` = `[el trabajo]` o `404 not_found`.
- Validaciones de `POST /api/jobs`, en este orden: cuerpo que no es un objeto JSON → `400 bad_json`; `urls` ausente, vacío, con más de 20 elementos o con elementos que no son cadenas → `400 no_urls`; alguna URL inválida (`queue.add` lanza `VdlBtz::Error`) → `400 invalid_url` con el mensaje de la excepción; `quality` presente pero no válida según `Config.normalize_quality` → `400 invalid_quality` (si falta se usa `config["quality"]`); yt-dlp no instalado (`installer.ytdlp_path` nulo) → `409 setup_required`; éxito → `202` con `data.jobs`. `audio` falso por defecto.
- `lib/vdl_btz.rb` — `require_relative "vdl_btz/gui/api"`. `lib/vdl_btz/cli.rb` — en `gui`: crear `queue = GUI::JobQueue.new(runner: GUI::JobQueue.downloader_runner(installer: @installer, config: @config))`, `api = GUI::Api.new(queue: queue, config: @config, installer: @installer)` y pasar `handler: api` a `Server.new`; al terminar `server.join` llamar `queue.shutdown`.
- `test/gui_api_jobs_test.rb` — arranca `Server` en proceso con `Api` y una cola con `runner` falso (devuelve un objeto `ok: true` de inmediato) y un instalador falso (`ytdlp_path`/`ffmpeg_path`/`deno_path` devuelven una ruta o `nil`); comprueba cada criterio con `Net::HTTP`. Incluye un caso de extremo a extremo con subproceso: `bin/vdl-btz gui --no-window` responde `GET /api/jobs` con `200` y `data.jobs == []` y se apaga con `POST /api/shutdown`.

**Files**
- `lib/vdl_btz/gui/api.rb` — new
- `lib/vdl_btz/gui/server.rb` — edit
- `lib/vdl_btz.rb` — edit
- `lib/vdl_btz/cli.rb` — edit
- `test/gui_api_jobs_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `GET /api/state` is requested with a valid token THE SYSTEM SHALL respond `200` with `data` containing the keys `version, os, config, qualities, browsers, setup`, where `setup` contains the keys `ytdlp, ffmpeg, deno, running, label, percent, error`.
2. WHEN `POST /api/jobs` receives `{"urls":["https://youtu.be/abc123"],"audio":false,"quality":"720"}` and yt-dlp is installed THE SYSTEM SHALL respond `202` with `data.jobs` holding one job whose `status` is `queued` or `running`.
3. WHEN the body is not a JSON object, or `urls` is missing, empty, longer than 20 or not strings, or a URL is invalid, or `quality` is not in `Config::QUALITIES`, THE SYSTEM SHALL respond `400` with the codes `bad_json`, `no_urls`, `invalid_url` or `invalid_quality` respectively and enqueue nothing.
4. WHEN `POST /api/jobs` arrives while yt-dlp is not installed THE SYSTEM SHALL respond `409` with error code `setup_required` and enqueue nothing.
5. WHEN `GET /api/jobs` is requested THE SYSTEM SHALL respond `200` with `data.jobs`, and WHEN `POST /api/jobs/<id>/cancel` targets a known job THE SYSTEM SHALL respond `200` and for an unknown id `404` with error code `not_found`.
6. WHEN `ruby bin/vdl-btz gui --no-window` is running THE SYSTEM SHALL answer `GET /api/jobs` with `200` and `data.jobs` equal to `[]`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_api_jobs_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_boot_test.rb  # expect: exit 0, 0 failures, 0 errors (earlier gate still passes)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E2-T1: Add jobs API routes and wire the gui command"
git tag step-06-api-jobs
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E2-T2` — Add settings, engine update and open-folder API

**Depends on:** `E1-T4`, `E2-T1` · **Priority:** p0 — metadata for scope cuts, not a running order

Esta es la primera tarea que escribe en disco (`config.yml`), así que el test lee el archivo real. Valida primero, persiste después: un cuerpo con una calidad válida y un navegador inválido no debe cambiar nada. Las instalaciones corren en un hilo; protege el estado compartido con un `Mutex`.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/os.rb` — método de módulo `OS.open_path(path)`: abre una carpeta en el explorador del sistema con un ARRAY de argumentos (nunca una cadena de shell): `["open", path]` en macOS, `["explorer", path]` en Windows, `["xdg-open", path]` en Linux; usa `Process.spawn(*args, out: File::NULL, err: File::NULL)` seguido de `Process.detach`, devuelve `true`, y devuelve `false` si lanza `SystemCallError`.
- `lib/vdl_btz/gui/api.rb` — `Api.new` acepta además `opener: OS.method(:open_path)` (invocable) para poder probarla. Rutas nuevas: `POST /api/config` con JSON de las claves `output`, `quality`, `cookies` (cualquier subconjunto): primero VALIDA todas sin escribir (`Config#set` guarda en disco al validar, así que no sirve para validar): `quality` debe cumplir `Config.normalize_quality(valor)` no nulo; `cookies` debe ser `none`, `ninguno`, `no`, `off` (sin distinguir mayúsculas) o cumplir `Config.normalize_browser(valor)` no nulo; `output` debe ser una cadena no vacía; cualquier otra clave o valor inválido → `400 invalid_config` con un mensaje en español y el archivo `Paths.config_file` no cambia ni un byte. Solo si todo es válido llama `config.set(clave, valor)` para cada clave y responde `200` con `data.config`.
- `POST /api/setup`: si ya hay una instalación en marcha → `409 already_running`; si no, marca `setup.running` verdadero y lanza un hilo que ejecuta `installer.ensure_ytdlp!`, después `installer.ensure_ffmpeg` y por último `installer.ensure_deno!` (como sentencias seguidas, no encadenadas con `&&`: `ensure_ffmpeg` devuelve `nil` si falla y no debe impedir instalar Deno), y responde `202` con `data.setup`. `POST /api/engine/update`: igual, pero el hilo ejecuta `installer.install_ytdlp`. Ambos fijan `installer.on_progress = ->(label, percent) { ... }` para actualizar `setup.label` y `setup.percent`; al terminar `running` pasa a falso, `label` y `percent` a nulo y, si el hilo lanzó una excepción, `setup.error` es su mensaje. `GET /api/state` devuelve este estado actualizado (`ytdlp`/`ffmpeg` se recalculan en cada llamada).
- `POST /api/open`: con cuerpo `{"id":"<id>"}` busca el trabajo en `queue.list`; si existe y tiene `file`, llama `opener.call(File.dirname(file))` y responde `200` con `data` `{"opened":true}`; si el id no existe o no tiene `file` → `404 no_file`. Con cuerpo `{}` crea (si falta) `config["output"]` con `FileUtils.mkdir_p` y lo abre. El cliente nunca envía una ruta.
- `test/test_helper.rb` — AISLAR LA CARPETA PERSONAL: justo después de fijar `ENV["VDL_BTZ_HOME"]` y antes de `require "vdl_btz"`, añadir `ENV["HOME"] = ENV["VDL_BTZ_HOME"]`, de modo que `Dir.home` (y con él la carpeta de salida por defecto `~/Downloads/vdl-btz`) apunte al directorio temporal. Desde este paso ninguna prueba puede tocar la carpeta personal real; ninguna prueba crea ni borra nada fuera de directorios temporales (`Dir.mktmpdir`), ni usa `rm_rf` sobre una ruta que no haya comprobado que está bajo `Dir.tmpdir`.
- `test/gui_api_settings_test.rb` — con `VDL_BTZ_HOME` temporal (ya lo hace `test_helper`), un instalador falso con `ensure_ytdlp!`, `ensure_ffmpeg`, `ensure_deno!`, `install_ytdlp`, `ytdlp_path`, `ffmpeg_path`, `deno_path`, `on_progress=` y un `opener` que registra las rutas: comprueba cada criterio; la prueba de configuración lee `Paths.config_file` del disco y compara su contenido YAML antes y después.

**Files**
- `lib/vdl_btz/gui/api.rb` — edit
- `lib/vdl_btz/os.rb` — edit
- `test/test_helper.rb` — edit
- `test/gui_api_settings_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `POST /api/config` receives valid values for `output`, `quality` and `cookies` THE SYSTEM SHALL write them to the file at `Paths.config_file` and respond `200` with `data.config` reflecting them.
2. WHEN any submitted config value is invalid (for example `quality` `999` or `cookies` `netscape`) THE SYSTEM SHALL respond `400` with error code `invalid_config` and leave the config file byte-for-byte unchanged.
3. WHEN `POST /api/setup` is requested and yt-dlp, ffmpeg or Deno is missing THE SYSTEM SHALL respond `202`, run `ensure_ytdlp!`, `ensure_ffmpeg` and `ensure_deno!` in that order in a background thread (ffmpeg is optional: its failure SHALL NOT stop Deno from being installed), expose `setup.running`, `setup.label` and `setup.percent` through `GET /api/state` while `on_progress` is called, and finish with `running` false.
4. WHEN the background install raises an error THE SYSTEM SHALL set `setup.error` to the error message with `running` false, and WHEN `POST /api/setup` or `POST /api/engine/update` arrives while `running` is true THE SYSTEM SHALL respond `409` with error code `already_running`.
5. WHEN `POST /api/engine/update` is requested THE SYSTEM SHALL respond `202` and run `install_ytdlp` in a background thread with the same `setup` fields.
6. WHEN `POST /api/open` receives the id of a job that has a `file` THE SYSTEM SHALL call the opener with that file's directory and respond `200`; for an unknown id or a job without `file` it SHALL respond `404` with error code `no_file`; for `{}` it SHALL create the configured output folder if missing and open it; and WHEN any test runs THE SYSTEM SHALL have `ENV["HOME"]` equal to the temporary `ENV["VDL_BTZ_HOME"]`, so `Dir.home` never points at the real home folder.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest -e 'require "test_helper"; abort("HOME is not isolated") unless ENV["HOME"] == ENV["VDL_BTZ_HOME"] && Dir.home == ENV["HOME"]'  # expect: exit 0 (tests never touch the real home folder)
ruby -Ilib -Itest test/gui_api_settings_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_api_jobs_test.rb  # expect: exit 0, 0 failures, 0 errors (step 6 gate still passes)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E2-T2: Add settings, engine update and open-folder API"
git tag step-07-api-settings
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E2-T3` — Serve the newspaper-style page and its assets

**Depends on:** `E2-T1` · **Priority:** p0 — metadata for scope cuts, not a running order

El servidor solo sirve una lista blanca fija de nombres: así no hay recorrido de directorios posible. El token entra en la página como `<meta>` (no en un script en línea) porque la política CSP prohíbe scripts y estilos en línea. Usa la paleta y las reglas del diseño tal como aparecen en el contrato de diseño (plano §7 y §19.6; en la épica, sección Contracts); no inventes colores de acento (el diseño es monocromo).

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- Las tres fuentes ya existen en `lib/vdl_btz/gui/assets/fonts/` (las trajo la copia de `workspace/`): `hanken-grotesk-var.woff2`, `space-mono-400.woff2`, `space-mono-700.woff2`. NO las descargues ni las modifiques.
- `lib/vdl_btz/gui/server.rb` — constante `ASSETS_DIR = File.expand_path("assets", __dir__)`. `GET /` exige el parámetro de consulta `t` igual al token (si no → `401` con el sobre JSON `unauthorized`) y responde `200` `text/html; charset=utf-8` con el contenido de `index.html` donde la cadena `__VDL_TOKEN__` se sustituye por el token. `GET /assets/<ruta>` sirve SOLO esta lista blanca, con estos tipos: `app.css` → `text/css; charset=utf-8`, `app.js` → `text/javascript; charset=utf-8`, `fonts/hanken-grotesk-var.woff2`, `fonts/space-mono-400.woff2`, `fonts/space-mono-700.woff2` → `font/woff2`; cualquier otra ruta, incluida cualquiera con `..`, → `404 not_found`; si el archivo de la lista no existe todavía → `404`. Los assets no requieren token. Lee los archivos con `File.binread` desde `ASSETS_DIR` (no uses rutas relativas al directorio actual).
- `lib/vdl_btz/gui/assets/index.html` — documento en español (`<html lang="es">`), UTF-8, `<meta name="viewport" content="width=device-width, initial-scale=1">`, `<meta name="vdl-token" content="__VDL_TOKEN__">`, `<link rel="stylesheet" href="/assets/app.css">` y `<script src="/assets/app.js" defer></script>`; SIN scripts ni estilos en línea y sin atributos `style=`. Estructura semántica y los ids exactos del contrato DOM (plano §6; en la épica, sección Contracts): masthead, formulario, cola, ajustes, pantalla de preparación y aviso legal; la lista de descargas es `<ol id="jobs" tabindex="0" aria-label="Lista de descargas">`.
- `lib/vdl_btz/gui/assets/app.css` — el sistema de diseño (plano §7 y §19.6; en la épica, sección Contracts): variables `:root` claro, bloque oscuro por `@media (prefers-color-scheme: dark)` (guardado con `:root:not([data-theme="light"])`) y por `:root[data-theme="dark"]`, `@font-face` de las tres fuentes con `font-display: swap`, filetes de 1–2 px, etiquetas en mayúsculas con `letter-spacing`, rejilla de dos columnas a partir de 900 px (la columna derecha ocupa el alto de la izquierda y `#jobs` hace scroll interno con `overflow-y:auto`; por debajo de 900 px `#jobs` tiene `max-height: 70vh` con scroll), textura de grano con `body::before` (SVG en `data:`), foco visible de 2 px y `@media (prefers-reduced-motion: reduce)`.
- `vdl-btz.gemspec` — cambiar `spec.files` a `Dir["lib/**/*.{rb,html,css,js,woff2}", "bin/*", "README.md", "LICENSE"]` para que la gema incluya las páginas y fuentes.
- `test/gui_assets_test.rb` — arranca `Server` en proceso con token conocido y comprueba cada criterio (HTML, CSS, fuentes con `Digest::SHA256`, rutas fuera de la lista blanca, `Gem::Specification.load("vdl-btz.gemspec").files`). Incluye un caso que comprueba el `tabindex="0"` de `#jobs` y una regla `#jobs{... overflow-y:auto}` en el CSS.

**Files**
- `lib/vdl_btz/gui/assets/index.html` — new
- `lib/vdl_btz/gui/assets/app.css` — new
- `lib/vdl_btz/gui/server.rb` — edit
- `vdl-btz.gemspec` — edit
- `test/gui_assets_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `GET /?t=<token>` is requested THE SYSTEM SHALL respond `200` with `Content-Type: text/html; charset=utf-8` and a body containing `<meta name="vdl-token" content="<token>">`, and WHEN `t` is missing or wrong THE SYSTEM SHALL respond `401` with the JSON error code `unauthorized`.
2. WHEN the served HTML is inspected THE SYSTEM SHALL contain every element id of the DOM contract (`masthead`, `dateline`, `theme-toggle`, `setup`, `setup-label`, `setup-progress`, `form-add`, `urls`, `mode-video`, `mode-audio`, `quality`, `btn-add`, `msg`, `jobs`, `empty`, `cfg-output`, `cfg-quality`, `cfg-cookies`, `btn-save-config`, `btn-update-engine`, `legal`), no inline `<script>` content and no `style=` attribute, and the `jobs` list SHALL carry `tabindex="0"` so the scrollable list can be reached with the keyboard.
3. WHEN `GET /assets/app.css` is requested THE SYSTEM SHALL respond `200` with `Content-Type: text/css; charset=utf-8` and a body containing the literals `--paper:#ece9e1`, `--ink:#000000`, `--paper:#0c0b09`, `--ink:#ede8db`, `prefers-color-scheme`, `Hanken Grotesk`, `Space Mono` and a rule giving `#jobs` the declaration `overflow-y:auto`.
4. WHEN the three files under `/assets/fonts/` are requested THE SYSTEM SHALL respond `200` with `Content-Type: font/woff2` and bodies whose SHA-256 digests are `1f21c6eaa0000f3329cfcfac966b43d5bebf5aa610303e33294ac31bc6f4bb59` (`hanken-grotesk-var.woff2`), `e0c8e616bda27642f4c3cebaecff6525d901e73afc8a227cbbb0f2af4810f300` (`space-mono-400.woff2`) and `af7cf6d2b897ec453acdcdacde4e9bcc8410718af5914de865b453e09f10eebc` (`space-mono-700.woff2`).
5. WHEN a path outside the allowlist is requested (`/assets/unknown.js`, `/assets/../server.rb`, `/assets/fonts/../../server.rb`) THE SYSTEM SHALL respond `404` with error code `not_found`.
6. WHEN `vdl-btz.gemspec` is loaded with `Gem::Specification.load` THE SYSTEM SHALL list `lib/vdl_btz/gui/assets/index.html`, `lib/vdl_btz/gui/assets/app.css` and the three `lib/vdl_btz/gui/assets/fonts/*.woff2` files in `files`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_assets_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -e 'abort("gemspec misses assets") unless Gem::Specification.load("vdl-btz.gemspec").files.include?("lib/vdl_btz/gui/assets/app.css")'  # expect: exit 0
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E2-T3: Serve the newspaper-style page and its assets"
git tag step-08-static-page
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E2-T4` — Add the page behaviour in app.js

**Depends on:** `E2-T2`, `E2-T3` · **Priority:** p0 — metadata for scope cuts, not a running order

La lógica del navegador no se puede ejecutar en CI sin un navegador, así que el contrato se comprueba de forma estática (ids, rutas y construcciones prohibidas) y el comportamiento real queda en la lista de lanzamiento. Escribe funciones pequeñas (`api(ruta, opciones)`, `renderJobs(lista)`, `pollState()`). Nada de frameworks.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/gui/assets/app.js` — JavaScript sin dependencias ni `import`, en modo estricto, que usa `fetch` con la cabecera `X-VDL-Token` (valor del `<meta name="vdl-token">`). Comportamiento: (1) al cargar, rellena `dateline` con `N°01 · <Estación> <año> · v<version>` (estación por mes del equipo: dic–feb Invierno, mar–may Primavera, jun–ago Verano, sep–nov Otoño; versión de `GET /api/state`); (2) pide `GET /api/state`; si `setup.ytdlp` o `setup.deno` es falso muestra `#setup` (quita el atributo `hidden`), llama `POST /api/setup` y consulta `/api/state` cada 500 ms actualizando `#setup-label` y `#setup-progress` (`value`/`max`) hasta que `ytdlp` sea verdadero y `running` falso (si `setup.error`, lo muestra en `#msg`); (3) envía `POST /api/ping` cada 2000 ms; (4) el formulario `#form-add` envía `POST /api/jobs` con las URLs de `#urls` (una por línea, vacías descartadas), `audio` según `#mode-audio` y `quality` de `#quality`; los errores `4xx` se muestran en `#msg` con el `error.message`; (5) consulta `GET /api/jobs` cada 500 ms mientras haya trabajos `queued` o `running` y cada 2000 ms si no, y pinta `#jobs` (un `<li>` por trabajo: número `01`, título, plataforma, estado en mayúsculas, un `<progress max="100">`, botón Cancelar → `POST /api/jobs/<id>/cancel`, y si `done` botón Abrir carpeta → `POST /api/open` con `{id}`); `#empty` se oculta cuando hay trabajos; (6) `#btn-save-config` envía `POST /api/config` con `output`, `quality`, `cookies` (`none` si se deja vacío) y `#btn-update-engine` envía `POST /api/engine/update`; (7) `#theme-toggle` alterna `data-theme` entre automático (sin atributo), `light` y `dark`, guardando la elección en `localStorage` dentro de `try/catch`.
- REGLA DE SEGURIDAD: los títulos y errores vienen de sitios remotos y no son de confianza. El JavaScript escribe SIEMPRE con `textContent`/`createElement`/`setAttribute`; no usa `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `eval(` ni `document.write`. Los mensajes de estado se escriben en `#msg` (`role="status"`, `aria-live="polite"`).
- `lib/vdl_btz/gui/assets/index.html` — si hace falta, ajustar atributos (por ejemplo `hidden` en `#setup`, `type="button"` en los botones que no envían el formulario) sin cambiar los ids del contrato DOM.
- `test/gui_assets_test.rb` — añadir comprobaciones estáticas sobre `app.js`: no contiene ninguna de las cinco construcciones prohibidas; cada literal de `getElementById("...")` existe como `id="..."` en `index.html`; contiene las cadenas `/api/ping`, `/api/state`, `/api/jobs`, `/api/setup`, `/api/config`, `/api/engine/update`, `/api/open` y `X-VDL-Token`; y, solo si `node` está instalado (`system("node --version", out: File::NULL, err: File::NULL)`), `node --check` sobre el archivo devuelve 0 (si no, `skip`).

**Files**
- `lib/vdl_btz/gui/assets/app.js` — new
- `lib/vdl_btz/gui/assets/index.html` — edit
- `test/gui_assets_test.rb` — edit

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `app.js` is read THE SYSTEM SHALL contain none of `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `eval(` and `document.write`.
2. WHEN every `getElementById("<id>")` literal in `app.js` is extracted THE SYSTEM SHALL find each `<id>` as an `id` attribute in `index.html`.
3. WHEN `app.js` is read THE SYSTEM SHALL contain the strings `/api/ping`, `/api/state`, `/api/jobs`, `/api/setup`, `/api/config`, `/api/engine/update`, `/api/open` and `X-VDL-Token`.
4. WHEN `GET /assets/app.js` is requested THE SYSTEM SHALL respond `200` with `Content-Type: text/javascript; charset=utf-8`.
5. WHEN `node` is installed and `node --check lib/vdl_btz/gui/assets/app.js` runs THE SYSTEM SHALL exit 0.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_assets_test.rb  # expect: exit 0, 0 failures, 0 errors (the node syntax case is skipped when node is missing)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E2-T4: Add the page behaviour in app.js"
git tag step-09-app-behavior
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E2-T5` — Open the app window with browser fallback

**Depends on:** `E2-T2`, `E2-T4` · **Priority:** p0 — metadata for scope cuts, not a running order

`Shell` no abre nada por sí solo en los tests: todo lo que toca el sistema entra por parámetros inyectables. Se usa un perfil propio de Chromium (`--user-data-dir`) para no tocar el del usuario y para que la ventana sea un proceso nuevo. Cerrar la ventana provoca que dejen de llegar `POST /api/ping` y el servidor se apaga solo a los 20 s.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/os.rb` — método de módulo `OS.open_url(url)`: ejecuta `Process.spawn(*args, out: File::NULL, err: File::NULL)` + `Process.detach` con `args` = `["open", url]` (macOS), `["cmd", "/c", "start", "", url]` (Windows) o `["xdg-open", url]` (Linux); devuelve `true`, o `false` si lanza `SystemCallError`. Siempre array de argumentos.
- `lib/vdl_btz/gui/shell.rb` — módulo `VdlBtz::GUI::Shell`. `Shell.window_args(exe, url, profile_dir)` devuelve exactamente `[exe, "--app=#{url}", "--user-data-dir=#{profile_dir}", "--no-first-run", "--window-size=980,780"]`. `Shell.candidates(os, env: ENV)` con `os` en `:mac`, `:windows` o `:linux` devuelve la lista ordenada del contrato de la ventana (plano §19.6; en la épica, sección Contracts). `Shell.launch(url, os: <símbolo del sistema actual>, spawner: Process.method(:spawn), exists: File.method(:file?), which: OS.method(:which), opener: OS.method(:open_url), profile_dir: File.join(Paths.home, "gui-profile"))`: recorre los candidatos (en macOS/Windows rutas absolutas comprobadas con `exists`; en Linux nombres resueltos con `which`), con el primero disponible lanza `spawner.call(*window_args(...), out: File::NULL, err: File::NULL)` y devuelve `:app_window`; si no hay ninguno y `opener.call(url)` es verdadero devuelve `:browser`; si no, `:manual`.
- `lib/vdl_btz/cli.rb` — `CLI.new` acepta `shell: GUI::Shell`. En `gui`, cuando NO se pasa `--no-window`: el servidor se crea con `idle_timeout` = el valor de `--idle-timeout` o 20, tras imprimir la línea `URL:` se llama `@shell.launch(url)` y, si devuelve `:manual`, se imprime `Abre esta dirección en tu navegador: <url>`; se elimina el error «La ventana todavía no está disponible». Con `--no-window` NO se llama a `@shell.launch` y no hay `idle_timeout` salvo que se indique. `lib/vdl_btz.rb` — `require_relative "vdl_btz/gui/shell"`.
- `test/gui_shell_test.rb` — con `spawner`, `exists`, `which` y `opener` falsos que registran las llamadas: `window_args` literal; `candidates(:mac)` igual a la lista del contrato; `candidates(:windows, env: {...})` con directorios inventados produce las rutas esperadas; `launch` devuelve `:app_window` y el `spawner` recibe los argumentos exactos cuando `exists` acepta el primer candidato; `:browser` cuando no hay candidatos y `opener` devuelve verdadero (y `opener` recibe la URL); `:manual` cuando tampoco abre; y un caso con `CLI#run(["gui", "--idle-timeout", "1"])` y un `shell` falso: el falso recibe una URL con la forma `http://127.0.0.1:<puerto>/?t=<token>`, el servidor se apaga por inactividad y `run` devuelve 0; con `--no-window` el falso no recibe llamadas.

**Files**
- `lib/vdl_btz/gui/shell.rb` — new
- `lib/vdl_btz/os.rb` — edit
- `lib/vdl_btz/cli.rb` — edit
- `lib/vdl_btz.rb` — edit
- `test/gui_shell_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `Shell.window_args(exe, url, profile_dir)` is called THE SYSTEM SHALL return exactly `[exe, "--app=<url>", "--user-data-dir=<profile_dir>", "--no-first-run", "--window-size=980,780"]`.
2. WHEN `Shell.candidates(:mac)` is called THE SYSTEM SHALL return, in this order, `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, `/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge`, `/Applications/Brave Browser.app/Contents/MacOS/Brave Browser` and `/Applications/Chromium.app/Contents/MacOS/Chromium`.
3. WHEN `Shell.launch` finds an existing candidate THE SYSTEM SHALL spawn it with `window_args` and return `:app_window`; WHEN none exists and the opener succeeds it SHALL return `:browser`; otherwise `:manual`.
4. WHEN `OS.open_url` builds its command THE SYSTEM SHALL use an argument array `["open", url]` on macOS, `["cmd", "/c", "start", "", url]` on Windows and `["xdg-open", url]` on Linux, never a shell string.
5. WHEN `vdl-btz gui` runs without `--no-window` THE SYSTEM SHALL start the server with `idle_timeout` 20 unless overridden, print the `URL:` line, call `Shell.launch` with that URL and, when it returns `:manual`, print `Abre esta dirección en tu navegador: <url>`.
6. WHEN `vdl-btz gui --no-window` runs THE SYSTEM SHALL NOT call `Shell.launch`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_shell_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_boot_test.rb  # expect: exit 0, 0 failures, 0 errors (the --no-window path still works end to end)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E2-T5: Open the app window with browser fallback"
git tag step-10-window-shell
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.
<!-- GENERATED:tasks END -->

---

## Epic acceptance

La épica está hecha cuando todas sus tareas están `done` **y**:

1. **WHEN** `ruby bin/vdl-btz gui --no-window` is running and a client with the valid token posts a job, saves a config and opens the page THE SYSTEM SHALL answer with the documented status codes and serve `GET /?t=<token>` as HTML that references only `/assets/` files.
2. **WHEN** `vdl-btz gui` starts without `--no-window` and no window can be opened THE SYSTEM SHALL print `Abre esta dirección en tu navegador: <url>` and exit 0 by itself once the idle timeout expires.

```bash
rake test  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_api_jobs_test.rb  # expect: exit 0 (includes the end-to-end subprocess case)
ruby -Ilib -Itest test/gui_assets_test.rb  # expect: exit 0 (page, css, fonts, allowlist, static app.js checks)
ruby -Ilib -Itest test/gui_shell_test.rb  # expect: exit 0 (window fallback chain and CLI wiring)
```

Ejecuta todo desde la raíz del proyecto.

## Pitfalls

- **Rutas de los assets** — lee siempre desde `ASSETS_DIR = File.expand_path("assets", __dir__)`; dentro del binario de Tebako el directorio actual no es el del proyecto.
- **Lista blanca, no `File.join` con la ruta del cliente** — compara el nombre pedido con la lista fija; `..` o `//` deben dar 404 sin tocar el disco.
- **`__VDL_TOKEN__`** — se sustituye solo al servir `/`; no lo sustituyas al escribir el archivo ni lo imprimas en la consola.
- **`mix-blend-mode` con variable** — `mix-blend-mode: var(--grain-blend)` es válido; el grano debe tener `pointer-events: none` o bloquea los clics.
- **El cierre de la ventana** — el servidor se apaga solo porque `app.js` envía `POST /api/ping` cada 2 s; si lo quitas, el proceso queda vivo tras cerrar la ventana.
- **Orden de las comprobaciones de `POST /api/jobs`** — `bad_json` → `no_urls` → `invalid_url` → `invalid_quality` → `setup_required`; cambiarlo rompe los mensajes que espera la pantalla.

## Before moving on

- [ ] Every task in this epic is `done` in `tasks.json` — no task left `in_progress`.
- [ ] Every `verify` command of every task in this epic passed, not just the first one.
- [ ] No `verify` command was edited, and none was skipped because a file it names did not exist.
- [ ] Every task in this epic has its `checkpoint` tag in version control (`git tag -l 'step-*'` lists them).
- [ ] `rake test` passes clean, run from the project root.
- [ ] Every "Produced" contract above exists with the stated signature.
- [ ] The three font files are byte-identical to the ones copied from `workspace/` (their SHA-256 digests match the table).
- [ ] No file outside the subtree was modified.
- [ ] `.env.example` — this project has no environment variables to add, and no `.env.example`.
- [ ] One commit per task, each prefixed with its task id, each followed by its checkpoint tag.
