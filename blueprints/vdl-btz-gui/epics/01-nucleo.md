# Epic 01: Núcleo seguro y servidor local

> Existe un servidor HTTP local protegido, una cola de descargas cancelable y un instalador con verificación de integridad, todo probado y sin interfaz.

| | |
|---|---|
| **Epic id** | `01-nucleo` |
| **Tasks** | `E1-T1` … `E1-T5` |
| **Depends on** | nothing — start here |
| **Unlocks** | 02-pantalla, 03-empaquetado |
| **Parallel with** | nothing (comparte archivos con la épica 02) |

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
bin/vdl-btz                      # existe, solo lectura (punto de entrada del CLI)
lib/
  vdl_btz.rb                     # edit (T1, T5): require_relative de los módulos nuevos
  vdl_btz/
    cli.rb                       # edit (T1, T2): comando `gui`
    downloader.rb                # edit (T3): cancel!, Result#canceled
    installer.rb                 # edit (T4): SHA-256 y on_progress
    gui/
      server.rb                  # NEW (T1), edit (T2): servidor HTTP local
      jobs.rb                    # NEW (T5): cola de trabajos
    config.rb paths.rb os.rb platform.rb hints.rb ui.rb version.rb   # existen, solo lectura
test/
  test_helper.rb                 # existe: fija VDL_BTZ_HOME temporal y NO_COLOR
  gui_boot_test.rb               # NEW (T1)
  gui_server_test.rb             # NEW (T2)
  downloader_test.rb             # edit (T3)
  installer_test.rb              # NEW (T4)
  gui_jobs_test.rb               # NEW (T5)
```

Todo lo que no aparezca arriba queda fuera de esta épica. Si una tarea parece exigir editar otro archivo, detente e informa: el límite de la épica está mal.

## Data model touched here

No hay base de datos. Los únicos datos son:

| Entidad | Campos | Notas |
|---|---|---|
| `Job` (solo memoria) | `id, url, platform, status, title, percent, speed, eta, file, error, hint, audio, quality` | nace en `queued`; `status` ∈ `queued/running/done/error/canceled`; se pierde al cerrar la app (no se persiste, a propósito) |
| `config.yml` (existente) | `output, quality, cookies` | NO se toca en esta épica |

## Contracts

**Consumed** — ya existen, no los reescribas:

| De | Interfaz | Garantía |
|---|---|---|
| `lib/vdl_btz/downloader.rb` | `Downloader.new(ytdlp:, ffmpeg:, output:, quality:, audio:, cookies:, playlist:)`; `#download(url){|event, data|}` | eventos `:title` (texto), `:progress` (`[porcentaje, velocidad, eta]`), `:done` (ruta); devuelve `Result(url, ok, file, error)` |
| `lib/vdl_btz/installer.rb` | `Installer.new(bin_dir:)`, `#ytdlp_path`, `#ffmpeg_path`, `#ensure_ytdlp!`, `#ensure_ffmpeg`, `#install_ytdlp`, método privado `download(url, dest, label:)` | rutas o `nil`; los métodos `ensure_*`/`install_*` imprimen con `UI` |
| `lib/vdl_btz/platform.rb`, `hints.rb`, `config.rb` | `Platform.valid_url?(url)`, `Platform.detect(url)`, `Hints.for(mensaje)`, `Config::QUALITIES` | `Platform.detect` devuelve `youtube/tiktok/instagram/facebook/otros` o `nil` |
| `lib/vdl_btz/cli.rb` | `CLI#run(argv)` devuelve el código de salida; `vdl-btz` sin argumentos imprime la ayuda | NO cambia el comportamiento de los comandos existentes |

**Produced** — las épicas siguientes dependen exactamente de estas firmas:

| Export | Firma | Usado por |
|---|---|---|
| `lib/vdl_btz/gui/server.rb` → `VdlBtz::GUI::Server` | `new(token:, handler: nil, port: 0, idle_timeout: nil)`, `#start → Integer`, `#stop`, `#join` | `02-pantalla` |
| `lib/vdl_btz/downloader.rb` → `Downloader#cancel!`, `#pid`, `Result#canceled` | `cancel! → nil` | `02-pantalla` (vía la cola) |
| `lib/vdl_btz/installer.rb` → `Installer.verify_sha256!`, `Installer#on_progress=` | `verify_sha256!(path, sums_text, asset) → true` / lanza `VdlBtz::Error`; `on_progress` invocable `(label, percent)` | `02-pantalla` |
| `lib/vdl_btz/gui/jobs.rb` → `VdlBtz::GUI::JobQueue` | `new(workers: 2, runner:)`, `#add(urls, audio:, quality:) → [Job]`, `#list → [Hash]`, `#cancel(id) → bool`, `#shutdown`, `JobQueue.downloader_runner(installer:, config:)` | `02-pantalla` |

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

**Registro `Job`** (solo en memoria): `id` (8 hex), `url`, `platform` (`youtube`/`tiktok`/`instagram`/`facebook`/`otros`), `status` (`queued`/`running`/`done`/`error`/`canceled`), `title`, `percent` (0–100), `speed`, `eta`, `file`, `error`, `hint`, `audio`, `quality`.

## Conventions that bite in this area

- Cada archivo Ruby empieza con `# frozen_string_literal: true` y vive dentro de `module VdlBtz`; los errores controlados son `VdlBtz::Error` (el CLI los muestra sin traza) y todo texto para el usuario va en español.
- Solo biblioteca estándar. Si crees que necesitas una gema, detente e informa: cada gema nueva rompe el empaquetado (el binario se arma desde una carpeta sin `Gemfile`).
- Las rutas se construyen con `File.join`/`File.expand_path` y nunca se asume `/` como raíz: las pruebas corren también en Windows (ahí `File.expand_path("/tmp/x")` devuelve `D:/tmp/x`).
- Las pruebas usan la `VDL_BTZ_HOME` temporal que ya fija `test/test_helper.rb` (desde la tarea E2-T2 también `HOME`); nunca escribas, crees ni borres nada fuera de directorios temporales y nunca uses `rm_rf` sobre una ruta que no hayas comprobado que está bajo `Dir.tmpdir`.
- `Process.spawn`/`Open3` siempre con array de argumentos, nunca con una cadena de shell.
- No hay `.claude/commands/`; las reglas de área están en `.claude/rules/` y las instrucciones completas en `CLAUDE.md` (ambos en la raíz del proyecto).
- El servidor escucha SOLO en `127.0.0.1` y nunca imprime el token en ningún sitio salvo la línea `URL:` del arranque.
- Las comprobaciones de seguridad (`Host`, tamaño, token) van ANTES del enrutado: ninguna ruta futura debe poder saltárselas.
- No mantengas un `Mutex` mientras corre el `runner` de un trabajo.
- El texto de las rutas de error es en español; los códigos (`unauthorized`, `bad_host`, …) son en inglés y estables.

Reglas completas: `CLAUDE.md`. Reglas de área: `.claude/rules/ruby-gui.md` y `.claude/rules/tests.md`. Ambos están en la raíz del proyecto (los copió el constructor desde `workspace/` antes de la primera tarea).

---

## Tasks

Listed in the same order as `tasks.json`. That order is the build order — work top to bottom and do not re-rank by priority or by what looks quick.

### `E1-T1` — Add local server and gui --no-window command

**Depends on:** nothing · **Priority:** p0 — metadata for scope cuts, not a running order

Empieza por el servidor: un bucle `accept` con un hilo por conexión es suficiente (la app tiene un solo usuario local). Parsea a mano la petición HTTP/1.1; no añadas gemas. El token se genera en el comando, no en el servidor, para que el servidor sea fácil de probar con un token conocido. Mantén `Connection: close` para no tener que gestionar keep-alive.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/gui/server.rb` — clase `VdlBtz::GUI::Server` (solo stdlib: `socket`, `json`, `securerandom`, `openssl`). `initialize(token:, handler: nil, port: 0)`; `start` abre `TCPServer.new("127.0.0.1", port)`, acepta conexiones en un hilo de fondo (un hilo por conexión) y devuelve el puerto entero; `stop` cierra el socket; `join` espera hasta que el servidor se detenga. Entiende HTTP/1.1: línea de petición `METHOD SP target SP HTTP/1.x`, cabeceras (claves en minúsculas) hasta la línea en blanco y cuerpo según `Content-Length` (vacío si falta). Responde `HTTP/1.1 <código> <motivo>` con `Content-Type: application/json; charset=utf-8`, `Content-Length` y `Connection: close`.
- Rutas propias del servidor: `GET /api/health` → `200` con `{"ok":true,"data":{"version":"<VdlBtz::VERSION>"}}`; `POST /api/shutdown` → `200` con `{"ok":true,"data":{}}` y después `stop`. Toda ruta que empiece por `/api/` exige la cabecera `X-VDL-Token` igual al token (comparar con `OpenSSL.fixed_length_secure_compare` tras comprobar que las longitudes coinciden); si falta o difiere → `401` con `{"ok":false,"error":{"code":"unauthorized","message":"Token inválido"}}`. Cualquier otra ruta → `404` con código `not_found`.
- `lib/vdl_btz.rb` — añadir `require_relative "vdl_btz/gui/server"` justo antes de `require_relative "vdl_btz/cli"`.
- `lib/vdl_btz/cli.rb` — añadir `when "gui" then gui(argv.drop(1))` al despacho de comandos y un método público `gui(argv)`: con `OptionParser` acepta `--no-window` (obligatorio en este paso) y `--port N` (por defecto 0); si falta `--no-window` lanza `VdlBtz::Error, "La ventana todavía no está disponible; usa --no-window"`. Genera el token con `SecureRandom.hex(16)`, inicia el servidor, imprime exactamente `URL: http://127.0.0.1:<puerto>/?t=<token>` como PRIMERA línea de stdout (con `$stdout.flush`), llama a `server.join` y devuelve `0`. Añadir al texto de `help` la línea `  vdl-btz gui [--no-window]           Abre la aplicación de escritorio`.
- `test/gui_boot_test.rb` — lanza el comando real con `Open3.popen3(RbConfig.ruby, "bin/vdl-btz", "gui", "--no-window")`, lee la primera línea de stdout (máximo 10 s), la valida con la expresión `\AURL: http://127\.0\.0\.1:(\d+)/\?t=([0-9a-f]{32})\n\z`, y con `Net::HTTP` comprueba: health con token → 200 y `data.version == VdlBtz::VERSION`; health sin token y con token erróneo → 401 `unauthorized`; ruta inexistente con token → 404; `POST /api/shutdown` con token → 200 y el proceso termina con estado 0 en menos de 5 s. Termina siempre el proceso hijo en un `ensure`.

**Files**
- `lib/vdl_btz/gui/server.rb` — new
- `lib/vdl_btz.rb` — edit
- `lib/vdl_btz/cli.rb` — edit
- `test/gui_boot_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `ruby bin/vdl-btz gui --no-window` starts THE SYSTEM SHALL print as the first line of stdout exactly `URL: http://127.0.0.1:<port>/?t=<token>` where `<port>` is a non-zero integer and `<token>` is 32 lowercase hexadecimal characters.
2. WHEN `GET /api/health` is requested with header `X-VDL-Token` equal to that token THE SYSTEM SHALL respond `200` with `{"ok":true,"data":{"version":...}}` where `data.version` equals `VdlBtz::VERSION`.
3. WHEN any `/api/` path is requested without the `X-VDL-Token` header, or with a different value, THE SYSTEM SHALL respond `401` with `{"ok":false,"error":{"code":"unauthorized",...}}`.
4. WHEN an unknown path is requested with a valid token THE SYSTEM SHALL respond `404` with error code `not_found`.
5. WHEN `POST /api/shutdown` is requested with the valid token THE SYSTEM SHALL respond `200` and the `gui` process SHALL exit with status 0 within 5 seconds.
6. WHEN `ruby bin/vdl-btz version` runs THE SYSTEM SHALL still print `vdl-btz <VdlBtz::VERSION>`, and WHEN `ruby bin/vdl-btz` runs with no arguments THE SYSTEM SHALL still print the help text containing `vdl-btz URL` and exit 0.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_boot_test.rb  # expect: exit 0, 0 failures, 0 errors (this runs the real entry point `bin/vdl-btz gui`)
ruby bin/vdl-btz version | grep -q '^vdl-btz [0-9]'  # expect: exit 0 (frozen CLI still works)
ruby bin/vdl-btz | grep -q 'vdl-btz URL'  # expect: exit 0 (no arguments still prints the help)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E1-T1: Add local server and gui --no-window command"
git tag step-01-gui-server-boot
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E1-T2` — Harden server with host check, limits and idle timeout

**Depends on:** `E1-T1` · **Priority:** p0 — metadata for scope cuts, not a running order

Las comprobaciones de seguridad van antes del enrutado para que ninguna ruta futura pueda saltárselas. El temporizador de inactividad es lo que apaga el servidor cuando el usuario cierra la ventana (la página enviará `POST /api/ping` cada 2 s en un paso posterior). Usa `Process.clock_gettime(Process::CLOCK_MONOTONIC)` para medir el tiempo.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/gui/server.rb` — añadir, en este orden, antes de despachar cualquier ruta: (1) línea de petición mal formada → `400` código `bad_request`; (2) cabecera `Host` distinta de `127.0.0.1:<puerto>` y de `localhost:<puerto>` → `403` código `bad_host` (defensa contra *DNS rebinding*); (3) `Content-Length` mayor que 65536 → `413` código `too_large` y se cierra la conexión sin leer el cuerpo; (4) si la ruta empieza por `/api/`, token válido o `401 unauthorized`; (5) con token válido, ruta conocida con método no admitido (por ejemplo `POST /api/health`) → `405` código `method_not_allowed` y ruta desconocida → `404 not_found`.
- Todas las respuestas (también los errores) llevan `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` y `Content-Security-Policy: default-src 'self'; img-src 'self' data:; frame-ancestors 'none'`.
- Ruta propia nueva: `POST /api/ping` → `200` con `{"ok":true,"data":{}}` (requiere token) y reinicia el temporizador de inactividad. `Server.new` acepta `idle_timeout:` (segundos, `nil` = sin límite): si pasa ese tiempo desde el arranque o desde el último `POST /api/ping` autenticado, el servidor llama a `stop`. Usa un hilo vigilante que compruebe cada 0.25 s.
- `lib/vdl_btz/cli.rb` — el comando `gui` acepta `--idle-timeout S` (entero, por defecto sin límite) y lo pasa a `Server.new`.
- `test/gui_server_test.rb` — arranca `Server` en proceso con un token conocido (puerto 0) y comprueba con `Net::HTTP`/`TCPSocket` cada criterio: `Host` ajeno → 403, `Content-Length: 70000` → 413, línea de petición `GARBAGE` → 400, `POST /api/health` con token válido → 405, las cuatro cabeceras presentes en una respuesta 200 y en una 404, `idle_timeout: 1` detiene el servidor (`join` vuelve en menos de 4 s) y un `POST /api/ping` cada 0.4 s lo mantiene vivo durante 2 s. Añade un caso con subproceso: `bin/vdl-btz gui --no-window --idle-timeout 2` termina con estado 0 en menos de 6 s.

**Files**
- `lib/vdl_btz/gui/server.rb` — edit
- `lib/vdl_btz/cli.rb` — edit
- `test/gui_server_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN a request carries a `Host` header other than `127.0.0.1:<port>` or `localhost:<port>` THE SYSTEM SHALL respond `403` with error code `bad_host` before any route runs.
2. WHEN a request announces `Content-Length` greater than 65536 THE SYSTEM SHALL respond `413` with error code `too_large` and close the connection.
3. WHEN the request line is malformed THE SYSTEM SHALL respond `400` with error code `bad_request`, and WHEN a known path is requested with a valid token and an unsupported method (for example `POST /api/health`) THE SYSTEM SHALL respond `405` with error code `method_not_allowed`.
4. WHEN any response is sent, including errors, THE SYSTEM SHALL include the headers `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` and `Content-Security-Policy: default-src 'self'; img-src 'self' data:; frame-ancestors 'none'`.
5. WHEN the server was created with `idle_timeout: 1` and no authenticated `POST /api/ping` arrives for 1 second THE SYSTEM SHALL stop, and WHEN a ping arrives before the second elapses THE SYSTEM SHALL keep running.
6. WHEN `ruby bin/vdl-btz gui --no-window --idle-timeout 2` runs and nothing pings it THE SYSTEM SHALL exit with status 0 within 6 seconds.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_server_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_boot_test.rb  # expect: exit 0, 0 failures, 0 errors (step 1 gate still passes)
ruby bin/vdl-btz gui --no-window --idle-timeout 2 | head -1 | grep -q '^URL: http://127.0.0.1:[0-9]*/?t=[0-9a-f]\{32\}$'  # expect: exit 0, and the server exits by itself after about 2 s
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E1-T2: Harden server with host check, limits and idle timeout"
git tag step-02-gui-server-hardening
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E1-T3` — Add cancel support to Downloader

**Depends on:** nothing · **Priority:** p0 — metadata for scope cuts, not a running order

El `Downloader` se instancia una vez por trabajo, así que `cancel!` solo afecta a esa descarga. No toques `build_args` ni el parseo de progreso. El `Thread` lector de stderr ya existente termina solo al cerrarse el proceso.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/downloader.rb` — (a) añadir el miembro `:canceled` al `Struct` `Result` (queda `Struct.new(:url, :ok, :file, :error, :canceled, keyword_init: true)`); (b) `attr_reader :pid`; (c) dentro de `download`, guardar `@pid = wait.pid` al abrir el proceso y ponerlo a `nil` al terminar; (d) nuevo método público `cancel!`: si hay un `@pid` activo marca `@canceled = true` y envía la señal (`"TERM"` en macOS/Linux, `"KILL"` si `OS.windows?`) con `Process.kill`, ignorando `Errno::ESRCH`; si no hay descarga activa no hace nada ni lanza error; (e) cuando `download` termina con `@canceled` verdadero devuelve `Result.new(url:, ok: false, canceled: true, error: "Cancelado")`; al empezar cada `download` se reinicia `@canceled = false`. La firma `download(url){|event, data|}` y los eventos `:title`, `:progress`, `:done` NO cambian.
- `test/downloader_test.rb` — añadir casos (se omiten con `skip` si `VdlBtz::OS.windows?`): crear en un directorio temporal un ejecutable `fake-ytdlp` con el contenido `#!/bin/sh` + `exec sleep 30` y permiso 755; `Downloader.new(ytdlp: ruta, output: tmp)`; ejecutar `download` en un `Thread`, esperar (máximo 5 s) a que `pid` no sea `nil`, llamar `cancel!`, comprobar que `join(5)` termina, que `result.ok` es falso, `result.canceled` es verdadero, y que `Process.kill(0, pid)` lanza `Errno::ESRCH`. Casos extra: `cancel!` sin descarga activa no lanza error; un `Result` normal (`Result.new(url: "u", ok: true)`) tiene `canceled` nulo.

**Files**
- `lib/vdl_btz/downloader.rb` — edit
- `test/downloader_test.rb` — edit

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `Downloader#cancel!` is called while `#download` is running THE SYSTEM SHALL terminate the child process and `#download` SHALL return a `Result` with `ok` false, `canceled` true and `error` `Cancelado` within 5 seconds.
2. WHEN `#download` has returned after a cancel THE SYSTEM SHALL leave no running child process (`Process.kill(0, pid)` raises `Errno::ESRCH`).
3. WHEN `#cancel!` is called while no download is running THE SYSTEM SHALL return without raising an error.
4. WHEN a `Result` is built without the `canceled` keyword THE SYSTEM SHALL report `canceled` as nil.
5. WHEN `rake test` runs THE SYSTEM SHALL exit 0 with the existing downloader tests unchanged in behaviour.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/downloader_test.rb  # expect: exit 0, 0 failures, 0 errors (the cancel cases are skipped on Windows only)
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E1-T3: Add cancel support to Downloader"
git tag step-03-downloader-cancel
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E1-T4` — Verify yt-dlp SHA-256 and report install progress

**Depends on:** nothing · **Priority:** p0 — metadata for scope cuts, not a running order

La función de comprobación es pura y estática para poder probarla sin red. No cambies el orden de descarga existente: solo se inserta la verificación entre la descarga y el `chmod`. La integridad de ffmpeg queda fuera de este cambio (se documenta como riesgo aceptado).

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/installer.rb` — (a) `Installer.new(bin_dir: Paths.bin_dir, on_progress: nil)` y `attr_accessor :on_progress`; (b) método de clase `Installer.verify_sha256!(path, sums_text, asset)`: busca en `sums_text` la línea que cumpla `/\A([0-9a-f]{64})  (.+)\z/` cuyo segundo grupo sea `asset`, calcula `Digest::SHA256.file(path).hexdigest` (`require "digest"`) y devuelve `true` si coinciden; si difieren, o si `asset` no aparece, lanza `VdlBtz::Error` con un mensaje en español que contiene `SHA-256` (por ejemplo `La verificación SHA-256 de #{asset} falló`); (c) en `install_ytdlp`, tras descargar a `tmp` y ANTES de `chmod` y de mover a `bin_dir`: descargar `YTDLP_RELEASES + "SHA2-256SUMS"` con el método `download` existente al archivo temporal `"#{target}.sums.part"`, leerlo, llamar `Installer.verify_sha256!(tmp, texto, ytdlp_asset)`; si lanza, el `ensure` existente borra `tmp` (y se amplía para borrar también `"#{target}.sums.part"`) y cualquier yt-dlp ya instalado queda intacto; (d) en `write_body`, además de `UI.progress`, llamar `on_progress.call(label, porcentaje)` si `on_progress` no es nulo (porcentaje entre 0 y 100; 0 cuando se desconoce el tamaño total).
- `test/installer_test.rb` — (1) `verify_sha256!` con un archivo temporal y un texto de sumas construido en el test con el SHA-256 real → `true`; (2) con un dígito alterado → `VdlBtz::Error` cuyo mensaje incluye `SHA-256`; (3) `asset` ausente → el mismo error; (4) una subclase de `Installer` que sobrescribe `download(url, dest, label:)` para escribir bytes de prueba (y, para la URL que termina en `SHA2-256SUMS`, un texto con la suma correcta o incorrecta): con suma correcta `install_ytdlp` deja `bin_dir/yt-dlp` (y se ejecuta con `VDL_BTZ_HOME` temporal; la comprobación de `--version` del final puede fallar con los bytes de prueba, por lo que la subclase también sobrescribe `version_of` para devolver `"test"`); con suma incorrecta lanza `VdlBtz::Error`, no existe `bin_dir/yt-dlp` y `Dir.glob(File.join(bin_dir, "*.part"))` está vacío; (5) `write_body` con un objeto de prueba que implementa `[]` (devuelve `"6"` para `content-length`) y `read_body` (cede dos fragmentos de 3 bytes) llama a `on_progress` dos veces con porcentajes 50 y 100.

**Files**
- `lib/vdl_btz/installer.rb` — edit
- `test/installer_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `Installer.verify_sha256!(path, sums, asset)` is called with a file whose SHA-256 equals the entry for `asset` in `sums` THE SYSTEM SHALL return true.
2. WHEN the digest differs from the entry THE SYSTEM SHALL raise `VdlBtz::Error` whose message contains `SHA-256`.
3. WHEN `asset` has no entry in `sums` THE SYSTEM SHALL raise `VdlBtz::Error` whose message contains `SHA-256`.
4. WHEN `install_ytdlp` downloads yt-dlp THE SYSTEM SHALL fetch `SHA2-256SUMS` from the same release URL and verify the file before `chmod` and before moving it into `bin_dir`; on a mismatch THE SYSTEM SHALL raise `VdlBtz::Error`, leave no `yt-dlp` file and no `.part` file in `bin_dir`.
5. WHEN `on_progress` is set and a download body arrives in chunks THE SYSTEM SHALL call `on_progress.call(label, percent)` once per chunk with `percent` between 0 and 100.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/installer_test.rb  # expect: exit 0, 0 failures, 0 errors
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E1-T4: Verify yt-dlp SHA-256 and report install progress"
git tag step-04-installer-integrity
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E1-T5` — Add in-memory download job queue

**Depends on:** `E1-T3` · **Priority:** p0 — metadata for scope cuts, not a running order

La cola no sabe nada de HTTP ni de yt-dlp: solo ejecuta el `runner` que le inyectan, por eso se prueba sin red. Protege la lista y los cambios de estado con un `Mutex` y no mantengas el candado mientras corre el `runner`. El `runner` real queda delgado a propósito (solo traduce eventos); no se prueba con descargas reales en CI.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `lib/vdl_btz/gui/jobs.rb` — clase `VdlBtz::GUI::JobQueue` (stdlib: `thread`, `securerandom`). `Job = Struct.new(:id, :url, :platform, :status, :title, :percent, :speed, :eta, :file, :error, :hint, :audio, :quality, keyword_init: true)`; `status` es uno de `"queued"`, `"running"`, `"done"`, `"error"`, `"canceled"`. `JobQueue.new(workers: 2, runner:)`: `runner` es un invocable `runner.call(job, control)` que devuelve un objeto con `ok`, `file`, `error`, `canceled` (por ejemplo `Downloader::Result`); `control` responde a `update(hash)` (cambia `title`, `percent`, `speed`, `eta` del trabajo), `canceled?` y `on_cancel { ... }` (registra el bloque que se ejecutará si se cancela el trabajo en marcha).
- Métodos: `add(urls, audio:, quality:)` valida TODAS las URLs con `Platform.valid_url?`; si alguna es inválida lanza `VdlBtz::Error` con `URL inválida: <url>` y no encola ninguna; si todas son válidas crea un `Job` por URL (`id` = `SecureRandom.hex(4)`, `platform` = `Platform.detect(url)`, `status` `"queued"`, `percent` 0) y los devuelve; `list` devuelve un `Array` de `Hash` (`job.to_h`) en orden de inserción con exactamente las claves `id, url, platform, status, title, percent, speed, eta, file, error, hint, audio, quality`; `cancel(id)` devuelve `false` si no existe, marca `"canceled"` si estaba en cola (sin ejecutarlo nunca) o ejecuta el bloque de `on_cancel` si estaba en marcha, y devuelve `true`; `shutdown` cancela lo pendiente y detiene los hilos. Hay `workers` hilos que sacan ids de una `Queue` y ejecutan el `runner`; todo acceso al estado compartido va dentro de un `Mutex`. Resultado: `ok` → `"done"` y `file`; `canceled` (o cancelación pedida) → `"canceled"`; si no → `"error"` con `error` y `hint = Hints.for(error)`. Si el `runner` lanza una excepción → `"error"` con el mensaje de la excepción.
- Método de clase `JobQueue.downloader_runner(installer:, config:)`: devuelve el `runner` real. Para cada trabajo crea un `Downloader.new(ytdlp: installer.ytdlp_path, ffmpeg: installer.ffmpeg_path, output: config["output"], quality: job.quality, audio: job.audio, cookies: config["cookies"])`, registra `control.on_cancel { downloader.cancel! }`, ejecuta `downloader.download(job.url)` traduciendo los eventos `:title` → `update(title:)` y `:progress` → `update(percent:, speed:, eta:)` (`data` es `[porcentaje, velocidad, eta]`) y devuelve el `Result`.
- `lib/vdl_btz.rb` — añadir `require_relative "vdl_btz/gui/jobs"` junto al `require` del servidor.
- `test/gui_jobs_test.rb` — con un `runner` de prueba que se bloquea en una `Queue` hasta que el test lo libera: (1) URLs válidas → un `Job` por URL con ids únicos; (2) una URL inválida entre válidas → `VdlBtz::Error` con la URL en el mensaje y `list` vacío; (3) con `workers: 2` y cuatro trabajos, el máximo de ejecuciones simultáneas observado es 2; (4) `runner` que devuelve `ok: true` → `done` con `file`, y que devuelve `ok: false, error: "This video is private"` → `error` con `hint` que contiene `cookies`; (5) `cancel` de un trabajo en cola → `canceled` sin llamar al `runner`, de uno en marcha → se ejecuta el bloque `on_cancel` y acaba `canceled`, de un id desconocido → `false`; (6) las claves de `list` son exactamente las del contrato y llegan en orden de inserción.

**Files**
- `lib/vdl_btz/gui/jobs.rb` — new
- `lib/vdl_btz.rb` — edit
- `test/gui_jobs_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `JobQueue#add(urls, audio:, quality:)` receives only valid http(s) URLs THE SYSTEM SHALL return one job per URL, each with a unique `id` and `status` `queued` or `running`.
2. WHEN any URL is invalid according to `Platform.valid_url?` THE SYSTEM SHALL raise `VdlBtz::Error` whose message contains that URL and SHALL enqueue none of the URLs.
3. WHEN more jobs than `workers` are added THE SYSTEM SHALL run at most `workers` jobs at the same time.
4. WHEN the runner reports `ok` true THE SYSTEM SHALL set the job to `done` with its `file`, and WHEN it reports `ok` false with an `error` THE SYSTEM SHALL set the job to `error` and fill `hint` from `Hints.for(error)`.
5. WHEN `cancel(id)` is called THE SYSTEM SHALL mark a queued job `canceled` without running it, run the registered `on_cancel` block for a running job and end it `canceled`, and return false for an unknown id.
6. WHEN `list` is called THE SYSTEM SHALL return the jobs in insertion order as hashes with exactly the keys `id, url, platform, status, title, percent, speed, eta, file, error, hint, audio, quality`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/gui_jobs_test.rb  # expect: exit 0, 0 failures, 0 errors
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E1-T5: Add in-memory download job queue"
git tag step-05-job-queue
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

---

## Epic acceptance

La épica está hecha cuando todas sus tareas están `done` **y**:

1. **WHEN** `ruby bin/vdl-btz gui --no-window` runs **THE SYSTEM SHALL** serve `GET /api/health` only with the correct `X-VDL-Token`, reject a foreign `Host`, an oversized body and a missing token, and exit with status 0 by itself after its idle timeout.
2. **WHEN** `rake test` runs **THE SYSTEM SHALL** exit 0, proving that the existing CLI tests, the cancel support in `Downloader`, the SHA-256 check in `Installer` and the job queue all pass together.

```bash
rake test  # expect: exit 0, 0 failures, 0 errors
ruby -Ilib -Itest test/gui_boot_test.rb  # expect: exit 0 (real entry point `bin/vdl-btz gui`)
ruby bin/vdl-btz | grep -q 'vdl-btz URL'  # expect: exit 0 (no arguments still prints the help)
```

Ejecuta todo desde la raíz del proyecto.

## Pitfalls

- **Búfer de stdout** — el proceso `gui` debe hacer `$stdout.flush` justo después de imprimir la línea `URL:`; si no, el test que lee la primera línea se queda esperando.
- **`localhost` vs `127.0.0.1`** — enlaza el socket a la cadena `"127.0.0.1"`; `localhost` puede resolverse a IPv6 y la URL impresa dejaría de coincidir.
- **Procesos huérfanos en los tests** — todo subproceso que lance un test se mata en un `ensure`; un servidor que se queda vivo bloquea la siguiente ejecución de `rake test`.
- **Windows** — `Process.kill("TERM")` no existe allí: la señal es `"KILL"` y los casos de cancelación se omiten con `skip`; no uses `fork`.
- **`Result` con `keyword_init`** — añadir `:canceled` al `Struct` no debe romper las llamadas existentes `Result.new(url:, ok:, ...)`.

## Before moving on

- [ ] Every task in this epic is `done` in `tasks.json` — no task left `in_progress`.
- [ ] Every `verify` command of every task in this epic passed, not just the first one.
- [ ] No `verify` command was edited, and none was skipped because a file it names did not exist.
- [ ] Every task in this epic has its `checkpoint` tag in version control (`git tag -l 'step-*'` lists them).
- [ ] `rake test` passes clean, run from the project root.
- [ ] Every "Produced" contract above exists with the stated signature.
- [ ] No file outside the subtree was modified.
- [ ] `.env.example` — this project has no environment variables to add, and no `.env.example`.
- [ ] One commit per task, each prefixed with its task id, each followed by its checkpoint tag.
