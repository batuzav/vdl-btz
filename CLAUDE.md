# vdl-btz

Herramienta en Ruby para descargar videos de TikTok, YouTube, Instagram y Facebook: un CLI (`vdl-btz`) y una aplicación de escritorio local (`vdl-btz gui`) con diseño de periódico.

## Commands

| Task | Command |
|---|---|
| Install dev gems | `bundle install` |
| Run the CLI | `ruby bin/vdl-btz <args>` |
| GUI server, no window | `ruby bin/vdl-btz gui --no-window` |
| GUI with window | `ruby bin/vdl-btz gui` |
| All tests | `rake test` |
| One test file | `ruby -Ilib -Itest test/<name>_test.rb` |
| Build the gem | `gem build vdl-btz.gemspec` |
| Sync the blueprint | `ruby blueprints/source/sync.rb vdl-btz-gui` (`--check` only verifies) |
| Lint / typecheck | none defined in this project |

**Gate:** `rake test` must exit 0 before any task is marked done.

Ruby version of the packaged binary: `.github/workflows/build.yml`. Dev gem versions: `vdl-btz.gemspec`. Never guess a version.

## Stack

Ruby, solo biblioteca estándar (sin gemas de ejecución) · Minitest + rake · servidor HTTP local propio (`socket`) · HTML/CSS/JS planos · Tebako para empaquetar · GitHub Actions. Sin base de datos: `~/.vdl-btz/config.yml` y estado en memoria. yt-dlp, ffmpeg y Deno (el entorno de JavaScript que YouTube necesita) se descargan en el primer uso a `~/.vdl-btz/bin`.

## Architecture

**Request path.** ventana (Chrome/Edge/Brave/Chromium en modo aplicación, o navegador) → `lib/vdl_btz/gui/server.rb` (token, `Host`, límites, cabeceras) → `gui/api.rb` (rutas JSON) → `gui/jobs.rb` (cola, 2 trabajadores) → `downloader.rb` → yt-dlp. La página sale de `gui/assets/` (`index.html`, `app.css`, `app.js`, `fonts/`). `cli.rb` es el único sitio que cablea servidor + API + cola + instalador + `Shell`.

**Boundaries.** Cruzarlas mal rompe el build:

| Layer | May use | Must never |
|---|---|---|
| `gui/server.rb` | stdlib, un `handler` inyectado | conocer `Downloader`, `Config` o yt-dlp |
| `gui/api.rb` | `JobQueue`, `Config`, `Installer`, `OS`, `Platform` | abrir sockets |
| `gui/jobs.rb` | `Platform`, `Hints`, un `runner` inyectado | conocer HTTP |
| `gui/shell.rb` | `OS`, `Paths`, parámetros inyectables | abrir nada en las pruebas |
| `gui/assets/app.js` | `fetch` a `/api/*` | `innerHTML`, `eval(`, `document.write`, scripts o estilos en línea |

**Where things live.**

| Concern | Single source of truth |
|---|---|
| Errores de la API | códigos estables en inglés; texto en español (`gui/server.rb`, `gui/api.rb`) |
| Configuración del usuario | `lib/vdl_btz/config.rb` (`Config#set` valida y persiste) |
| Rutas de la herramienta | `lib/vdl_btz/paths.rb` (`VDL_BTZ_HOME` las redirige) |
| Assets servidos | lista blanca fija en `gui/server.rb` + `ASSETS_DIR` |
| Tokens de diseño | `gui/assets/app.css` (variables `:root`) |
| Empaquetado | `packaging/**` y `.github/workflows/build.yml` |

## Code rules

1. Cada archivo Ruby: `# frozen_string_literal: true`, dentro de `module VdlBtz`; errores controlados con `VdlBtz::Error`; textos al usuario en español.
2. **Solo biblioteca estándar.** Una gema nueva rompe el empaquetado (el binario se arma desde `bin/` y `lib/` sin `Gemfile`): detente e informa.
3. `Process.spawn`/`Open3` siempre con array de argumentos, nunca con una cadena de shell.
4. Las rutas con `File.join`/`File.expand_path`; las pruebas también corren en Windows.
5. Las pruebas usan la `VDL_BTZ_HOME` temporal de `test/test_helper.rb` (y `HOME` aislado desde el paso 7); nunca crees ni borres nada fuera de directorios temporales ni uses `rm_rf` sobre rutas sin comprobar que están bajo `Dir.tmpdir`.
6. Validar en el borde: cada ruta de la API valida tipo y tamaño antes de tocar la lógica.
7. Una responsabilidad por archivo; si un archivo pasa de unas 250 líneas, divídelo.
8. Un paso = un commit + su etiqueta `step-NN-slug`; el commit de cada paso lleva el prefijo del paso.

## Design system

Periódico monocromo (de batuzav.com). Sin color de acento, sin radios, sin sombras. Los tokens se definen una vez en `app.css` y los componentes usan solo nombres de token.

| Token | Claro | Oscuro |
|---|---|---|
| `--paper` | `#ece9e1` | `#0c0b09` |
| `--paper-2` | `#e3dfd4` | `#131210` |
| `--ink` | `#000000` | `#ede8db` |
| `--ink-soft` | `#1b1b17` | `#d8d2c4` |
| `--rule` | `#000000` | `#ede8db` |

- **Tipos:** `Hanken Grotesk` (texto y titulares, 400–900) y `Space Mono` (etiquetas y estados, mayúsculas, `letter-spacing` .12em).
- **Espacio:** base 4 px (4, 8, 12, 16, 24, 32, 48, 64). Ancho máximo 1100 px; dos columnas desde 900 px.
- **Filetes:** 1–2 px `var(--rule)`; filete doble de 3 px en errores. Botones con borde de 2 px que se invierten al hover/foco; altura mínima 44 px.
- **Estado:** siempre texto en mayúsculas (`EN COLA`, `DESCARGANDO`, `LISTO`, `ERROR`, `CANCELADO`), nunca solo color.
- **Movimiento:** ninguno; respetar `prefers-reduced-motion`.

## Environment

No hay variables nuevas ni `.env`. Existentes y opcionales: `VDL_BTZ_HOME` (carpeta base, por defecto `~/.vdl-btz`) y `NO_COLOR`.

## Rules

Convenciones por área; léelas antes de editar esa zona:

| File | Applies to |
|---|---|
| `.claude/rules/ruby-gui.md` | `lib/vdl_btz/gui/**/*.rb`, `cli.rb`, `os.rb` |
| `.claude/rules/assets.md` | `lib/vdl_btz/gui/assets/**` |
| `.claude/rules/packaging.md` | `packaging/**`, `.github/workflows/**` |
| `.claude/rules/tests.md` | `test/**` |

## Non-negotiable

1. **CLI congelado:** `vdl-btz` sin argumentos imprime la ayuda; no cambian comandos, opciones, códigos de salida, el formato de `config.yml` ni `~/.vdl-btz`; `Downloader#download(url){|event, data|}` y sus eventos tampoco.
2. El servidor escucha solo en `127.0.0.1`; las comprobaciones de seguridad (`Host`, tamaño, token) van antes de cualquier ruta; el token solo se imprime en la línea `URL:`.
3. El navegador nunca recibe HTML de fuentes remotas: títulos y errores se escriben con `textContent`.
4. Estilo del código: aplica la skill `ponytail` si está instalada (el cambio más pequeño que resuelve el paso completo, sin abstracciones ni dependencias de sobra); si no está, aplica la misma regla a mano.
5. No implementes nada de la tabla de no-objetivos del plano (hosting, cuentas, historial, firma de pago, auto-actualización, webview como requisito).
6. Nunca confirmes secretos, `.env` ni salidas de compilación (`dist/`).
7. Nunca marques un paso como hecho con una compuerta en rojo ni edites un comando `verify`.
8. **El plano tiene una fuente única:** `blueprints/source/vdl-btz-gui/steps.yml`. El mapa y los pasos de §9, los criterios y `verify` de `tasks.json` y los bloques de tarea de las épicas (lo que va entre marcadores `GENERATED`) se generan con `ruby blueprints/source/sync.rb vdl-btz-gui`: se edita la fuente y se sincroniza, nunca esas zonas a mano. De `tasks.json` solo se escribe `status` (el generador lo conserva).
