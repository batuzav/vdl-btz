# Epic 03: Empaquetado y entrega

> Existen los instaladores por sistema (.app/.dmg, .exe, AppImage), la documentación de descarga y la prueba técnica opcional de webview.

| | |
|---|---|
| **Epic id** | `03-empaquetado` |
| **Tasks** | `E3-T1` … `E3-T5` |
| **Depends on** | 02-pantalla |
| **Unlocks** | nothing — final epic |
| **Parallel with** | nothing (T1–T3 comparten `build.yml`) |

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

Herramientas de empaquetado (se ejecutan en GitHub Actions; en local solo se prueban con binarios falsos): `codesign`, `plutil`, `hdiutil` (macOS, vienen con el sistema), `appimagetool` (Linux, etiqueta móvil `continuous`), Inno Setup (preinstalado en `windows-latest`) y Tebako (versión fijada en el workflow).

## Directory subtree

Solo lo que toca esta épica:

```
.github/workflows/
  build.yml                      # edit (T1, T2, T3): pasos de empaquetado y entrada de Windows
  webview-spike.yml              # NEW (T5)
packaging/
  macos/make_app.sh              # NEW (T1)
  linux/make_appimage.sh         # NEW (T2)
  linux/vdl-btz.desktop          # NEW (T2)
  linux/vdl-btz.svg              # NEW (T2)
  windows/vdl-btz.iss            # NEW (T3)
  windows/vdl-btz-launcher.vbs   # NEW (T3)
docs/webview-spike.md            # NEW (T5)
.gitignore                       # edit (T1): añade /dist/
README.md                        # edit (T4)
test/
  packaging_test.rb              # NEW (T1), edit (T2, T3)
  readme_test.rb                 # NEW (T4)
```

Todo lo que no aparezca arriba queda fuera de esta épica (no toques `lib/` ni `bin/`).

## Data model touched here

NOT APPLICABLE — esta épica no maneja datos de la aplicación; solo produce archivos de distribución.

## Contracts

**Consumed** — ya existen:

| De | Interfaz | Garantía |
|---|---|---|
| `bin/vdl-btz` + `vdl-btz gui` | comando `gui` (épicas 01–02) | abre la aplicación; sin argumentos el binario imprime la ayuda |
| `.github/workflows/build.yml` (estado actual) | jobs `test` (`ubuntu-latest`, `macos-latest`, `windows-latest`; `bundle exec rake test`), `binary` (matriz `include`: `{ os: macos-15, target: macos-arm64 }`, `{ os: macos-15-intel, target: macos-x64 }`, `{ os: ubuntu-24.04, target: linux-x64 }`) y `release` (solo con etiquetas `v*`) | pasos del job `binary` en orden: `actions/checkout@v4` → `ruby/setup-ruby@v1` (3.3) → `Dependencias de Tebako (macOS)` → `Dependencias de Tebako (Linux)` → `Preparar carpeta de empaquetado` (`mkdir stage && cp -R bin lib stage/`) → `Preparar entorno de Tebako` (`tebako setup --Ruby=3.3.7`) → `Empaquetar con Tebako` (`--output=vdl-btz-${{ matrix.target }} --mode=fat`) → `Prueba rápida del binario` → `actions/upload-artifact@v4` (`name`/`path` = `vdl-btz-${{ matrix.target }}`) |
| `vdl_btz/version.rb` | `VdlBtz::VERSION` | cadena de versión del programa |

**Produced:**

| Export | Firma | Usado por |
|---|---|---|
| `packaging/macos/make_app.sh` | `make_app.sh <binario> <arch> <version> <outdir>` | `build.yml` |
| `packaging/linux/make_appimage.sh` | `make_appimage.sh <binario> <arch> <outdir> [--appdir-only]` | `build.yml` |
| `packaging/windows/vdl-btz.iss` | Inno Setup con `/DAppVersion=<versión>` | `build.yml` |
| artefactos | `vdl-btz-<target>-app` (`.dmg`), `vdl-btz-linux-x64-appimage`, `vdl-btz-windows-x64-setup` | job `release` (`files: dist/*` con `merge-multiple`) |

**Contrato de empaquetado:**

| Sistema | Entrada | Salida (artefacto) | Lanzador |
|---|---|---|---|
| macOS | binario `vdl-btz-macos-arm64` / `vdl-btz-macos-x64` | `vdl-btz.app` → `dist/vdl-btz-<arch>.dmg` (artefacto `vdl-btz-<target>-app`) | `Contents/MacOS/vdl-btz-launcher`: `exec "$(dirname "$0")/vdl-btz" gui` |
| Linux | binario `vdl-btz-linux-x64` | `vdl-btz.AppDir` → `dist/vdl-btz-x86_64.AppImage` (artefacto `vdl-btz-linux-x64-appimage`) | `AppRun`: `exec "$HERE/usr/bin/vdl-btz" gui` |
| Windows | `vdl-btz-windows-x64.exe` (experimental) | `dist/vdl-btz-windows-x64-setup.exe` (Inno Setup) | acceso directo a `wscript.exe "{app}\vdl-btz-launcher.vbs"` (consola oculta) |

Identificador del paquete macOS: `com.batuzav.vdl-btz`; mínimo `15.0`. Firma *ad-hoc* gratuita (`codesign -s -`); sin notarización. El binario de Tebako se genera con `--Ruby=3.3.7 --mode=fat` y se empaqueta desde una carpeta que contiene solo `bin/` y `lib/` (sin `Gemfile`).

## Conventions that bite in this area

- Los scripts de empaquetado son `sh` POSIX con `set -eu`, comprueban el número de argumentos antes de cualquier otra cosa (estado 64 si faltan) y no usan características de `bash`.
- **`cp -n` sale con 1 en macOS cuando omite un archivo**; en estos scripts usa `cp` sin `-n` sobre un directorio de salida recién creado.
- No cambies ni reordenes los pasos existentes del job `binary` salvo lo que indica cada tarea; las entradas de la matriz de macOS y Linux no se tocan.
- Las pruebas de empaquetado usan un binario FALSO (`#!/bin/sh` + `echo stub`); nunca descargan ni ejecutan Tebako.
- Las pruebas que ejecutan `sh`, `plutil`, `codesign` o `hdiutil` se omiten con `skip` donde esas herramientas no existen (Windows; fuera de macOS en el caso de las de macOS).
- Las apps van SIN firma de pago ni notarización: no añadas secretos, certificados ni pasos que los necesiten.

Reglas completas: `CLAUDE.md`. Reglas de área: `.claude/rules/packaging.md` y `.claude/rules/tests.md`, en la raíz del proyecto.

---

## Tasks

Listed in the same order as `tasks.json`. That order is the build order — work top to bottom and do not re-rank by priority or by what looks quick.

### `E3-T1` — Package the macOS app bundle and dmg

**Depends on:** `E2-T5` · **Priority:** p1 — metadata for scope cuts, not a running order

El empaquetado reutiliza el binario de Tebako ya generado; el `.app` solo añade un lanzador. La firma *ad-hoc* no evita el aviso de Gatekeeper al descargar (eso exige cuenta de pago), pero deja la app con firma válida; el README explica cómo abrirla. No generes icono `.icns` en este cambio.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `packaging/macos/make_app.sh` — script POSIX `sh` con `set -eu`, uso `make_app.sh <binario> <arch> <version> <outdir>` (sale con estado 64 e imprime el uso si faltan argumentos). Crea `<outdir>/vdl-btz.app/Contents/MacOS/` y `Contents/`; copia `<binario>` a `Contents/MacOS/vdl-btz` (permiso 755); escribe `Contents/MacOS/vdl-btz-launcher` (permiso 755) con exactamente `#!/bin/sh` y la línea `exec "$(dirname "$0")/vdl-btz" gui`; escribe `Contents/Info.plist` (plist XML) con `CFBundleName` `vdl-btz`, `CFBundleDisplayName` `vdl-btz`, `CFBundleIdentifier` `com.batuzav.vdl-btz`, `CFBundleExecutable` `vdl-btz-launcher`, `CFBundlePackageType` `APPL`, `CFBundleShortVersionString` y `CFBundleVersion` = `<version>`, `LSMinimumSystemVersion` `15.0`, `NSHighResolutionCapable` `true`. Después ejecuta `codesign --force --deep -s - <app>` (firma *ad-hoc*, gratuita) y `hdiutil create -volname vdl-btz -srcfolder <app> -ov -format UDZO <outdir>/vdl-btz-<arch>.dmg`. El script se ejecuta solo en macOS.
- `.github/workflows/build.yml` — en el job `binary`, después del paso de la prueba rápida y antes de `upload-artifact`, añadir el paso `Empaquetar app de macOS` con `if: runner.os == 'macOS'` que ejecute `sh packaging/macos/make_app.sh vdl-btz-${{ matrix.target }} ${{ matrix.target }} "$(ruby -Ilib -e 'require "vdl_btz"; print VdlBtz::VERSION')" dist`; y un `actions/upload-artifact` con `if: runner.os == 'macOS'`, `name: vdl-btz-${{ matrix.target }}-app` y `path: dist/*.dmg`. No cambiar los pasos ni la matriz existentes.
- `.gitignore` — añadir la línea `/dist/` (las salidas de empaquetado no se versionan).
- `test/packaging_test.rb` — usa un binario falso (`#!/bin/sh` + `echo stub`) en un directorio temporal. Casos solo de macOS (`skip` si `RbConfig::CONFIG["host_os"]` no contiene `darwin`): el script crea la estructura, `plutil -lint` del `Info.plist` termina en 0 y `plutil -extract CFBundleIdentifier raw` devuelve `com.batuzav.vdl-btz`, `codesign --verify --deep --strict` termina en 0, `hdiutil verify` del `.dmg` termina en 0. Casos en macOS y Linux (se omiten con `skip` en Windows, donde no hay `sh` fiable): ejecutar `sh packaging/macos/make_app.sh` sin argumentos termina con estado 64 (el script comprueba el número de argumentos ANTES de cualquier otra cosa, así que el resultado no depende del sistema). Caso en todos los sistemas: el workflow se parsea con `YAML.load_file` y contiene un paso cuyo `run` menciona `packaging/macos/make_app.sh` con `if` igual a `runner.os == 'macOS'`.

**Files**
- `packaging/macos/make_app.sh` — new
- `.github/workflows/build.yml` — edit
- `.gitignore` — edit
- `test/packaging_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `sh packaging/macos/make_app.sh <binary> <arch> <version> <outdir>` runs on macOS THE SYSTEM SHALL create `<outdir>/vdl-btz.app/Contents/MacOS/vdl-btz`, an executable `Contents/MacOS/vdl-btz-launcher` and `Contents/Info.plist`.
2. WHEN the launcher file is read THE SYSTEM SHALL contain the line `exec "$(dirname "$0")/vdl-btz" gui`.
3. WHEN `plutil -lint` runs on the generated `Info.plist` THE SYSTEM SHALL exit 0, with `CFBundleIdentifier` equal to `com.batuzav.vdl-btz`, `CFBundleExecutable` equal to `vdl-btz-launcher`, `CFBundleShortVersionString` equal to `<version>` and `LSMinimumSystemVersion` equal to `15.0`.
4. WHEN `codesign --verify --deep --strict` runs on the generated app THE SYSTEM SHALL exit 0, and WHEN `hdiutil verify` runs on `<outdir>/vdl-btz-<arch>.dmg` THE SYSTEM SHALL exit 0.
5. WHEN the script is run with missing arguments THE SYSTEM SHALL exit with status 64 and print a usage line.
6. WHEN `.github/workflows/build.yml` is parsed as YAML THE SYSTEM SHALL be valid and its `binary` job SHALL contain a step running `packaging/macos/make_app.sh` guarded by `runner.os == 'macOS'`, followed by an artifact upload of `dist/*.dmg`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/packaging_test.rb  # expect: exit 0, 0 failures, 0 errors (macOS-only cases are skipped elsewhere)
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml")'  # expect: exit 0
sh packaging/macos/make_app.sh; test $? -eq 64  # expect: exit code 64 (usage) -> this line exits 0
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E3-T1: Package the macOS app bundle and dmg"
git tag step-11-macos-package
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E3-T2` — Package the Linux AppImage

**Depends on:** `E3-T1` · **Priority:** p1 — metadata for scope cuts, not a running order

`--appimage-extract-and-run` evita depender de FUSE en el servidor de CI. `appimagetool` se descarga de la etiqueta móvil `continuous` (no hay versión fija verificable; queda anotado como riesgo). La app abre una ventana de Chrome/Chromium/Edge si existe; si no, el navegador por defecto.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `packaging/linux/vdl-btz.desktop` — archivo de entrada de escritorio con exactamente las claves `[Desktop Entry]`, `Type=Application`, `Name=vdl-btz`, `Comment=Descarga videos de TikTok, YouTube, Instagram y Facebook`, `Exec=vdl-btz gui`, `Icon=vdl-btz`, `Terminal=false`, `Categories=Network;Utility;`.
- `packaging/linux/vdl-btz.svg` — icono SVG bien formado (`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" ...>`): un cuadrado de papel `#ece9e1` con borde de 2 px `#000000` y las letras `vdl` en negro (`<text>` en la fuente `monospace`, `font-weight` 700, centradas). Sin dependencias externas.
- `packaging/linux/make_appimage.sh` — script POSIX `sh` con `set -eu`, uso `make_appimage.sh <binario> <arch> <outdir> [--appdir-only]` (sin argumentos obligatorios → estado 64 y uso). Construye `<outdir>/vdl-btz.AppDir` con: `usr/bin/vdl-btz` (el binario, 755), `AppRun` (755, contenido `#!/bin/sh`, `HERE="$(dirname "$(readlink -f "$0")")"` y `exec "$HERE/usr/bin/vdl-btz" gui`), `vdl-btz.desktop` y `vdl-btz.svg` copiados desde `packaging/linux/`. Con `--appdir-only` termina ahí con estado 0. Sin esa opción busca `appimagetool` en el `PATH`; si no existe imprime `appimagetool no encontrado` y sale con estado 2; si existe ejecuta `ARCH=<arch> appimagetool --appimage-extract-and-run <AppDir> <outdir>/vdl-btz-<arch>.AppImage` (`<arch>` = `x86_64`).
- `.github/workflows/build.yml` — en el job `binary`, antes de `upload-artifact`: un paso `Descargar appimagetool` con `if: runner.os == 'Linux'` que ejecute `curl -fsSL -o appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage && chmod +x appimagetool && sudo mv appimagetool /usr/local/bin/`; un paso `Empaquetar AppImage` con `if: runner.os == 'Linux'` que ejecute `sh packaging/linux/make_appimage.sh vdl-btz-${{ matrix.target }} x86_64 dist`; y un `upload-artifact` con `if: runner.os == 'Linux'`, `name: vdl-btz-${{ matrix.target }}-appimage`, `path: dist/*.AppImage`.
- `test/packaging_test.rb` — añadir casos con binario falso (en macOS y Linux; en Windows se omiten con `skip` los que ejecutan `sh` y solo se comprueban con `File.read` los archivos de `packaging/linux/`): `make_appimage.sh <falso> x86_64 <tmp> --appdir-only` termina en 0 y existen `AppRun` ejecutable con la línea `exec "$HERE/usr/bin/vdl-btz" gui`, `usr/bin/vdl-btz`, `vdl-btz.desktop`, `vdl-btz.svg`; el `.desktop` contiene las claves indicadas; el SVG empieza por `<svg` y contiene `xmlns="http://www.w3.org/2000/svg"`; sin `--appdir-only` y con `PATH` que no contiene `appimagetool` (`env PATH=/usr/bin:/bin`) el script termina con estado 2; el workflow tiene un paso con `if` igual a `runner.os == 'Linux'` que menciona `make_appimage.sh`.

**Files**
- `packaging/linux/make_appimage.sh` — new
- `packaging/linux/vdl-btz.desktop` — new
- `packaging/linux/vdl-btz.svg` — new
- `.github/workflows/build.yml` — edit
- `test/packaging_test.rb` — edit

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `sh packaging/linux/make_appimage.sh <binary> x86_64 <outdir> --appdir-only` runs THE SYSTEM SHALL exit 0 and create `<outdir>/vdl-btz.AppDir` containing `usr/bin/vdl-btz`, an executable `AppRun`, `vdl-btz.desktop` and `vdl-btz.svg`.
2. WHEN `AppRun` is read THE SYSTEM SHALL contain the line `exec "$HERE/usr/bin/vdl-btz" gui`.
3. WHEN `vdl-btz.desktop` is read THE SYSTEM SHALL contain the lines `Type=Application`, `Name=vdl-btz`, `Exec=vdl-btz gui`, `Icon=vdl-btz`, `Terminal=false` and `Categories=Network;Utility;`.
4. WHEN `vdl-btz.svg` is read THE SYSTEM SHALL start with `<svg` and contain `xmlns="http://www.w3.org/2000/svg"`.
5. WHEN the script runs without `--appdir-only` and `appimagetool` is not on `PATH` THE SYSTEM SHALL print `appimagetool no encontrado` and exit with status 2.
6. WHEN `.github/workflows/build.yml` is parsed as YAML THE SYSTEM SHALL be valid and contain a step guarded by `runner.os == 'Linux'` that runs `packaging/linux/make_appimage.sh`, followed by an artifact upload of `dist/*.AppImage`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/packaging_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml")'  # expect: exit 0
sh packaging/linux/make_appimage.sh; test $? -eq 64  # expect: exit code 64 (usage) -> this line exits 0
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E3-T2: Package the Linux AppImage"
git tag step-12-linux-package
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E3-T3` — Build the Windows binary, hidden launcher and installer

**Depends on:** `E3-T2` · **Priority:** p1 — metadata for scope cuts, not a running order

Este paso solo puede verificarse de forma estática en macOS/Linux; la ejecución real en Windows ocurre en GitHub Actions y es experimental (`continue-on-error`) porque Tebako en Windows con el modo `fat` no está probado. Un `.exe` de consola abriría una ventana negra: por eso el instalador crea el acceso directo hacia `wscript.exe` con el lanzador oculto. Usa `PrivilegesRequired=lowest` para que no pida administrador.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `packaging/windows/vdl-btz-launcher.vbs` — script de Windows Script Host que lanza la app sin ventana de consola: `Set sh = CreateObject("WScript.Shell")`, `dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)` y `sh.Run """" & dir & "\vdl-btz.exe"" gui", 0, False` (estilo de ventana 0 = oculta, sin esperar).
- `packaging/windows/vdl-btz.iss` — script de Inno Setup con `[Setup]`: `AppName=vdl-btz`, `AppVersion={#AppVersion}` (se pasa con `/DAppVersion=...`), `DefaultDirName={autopf}\vdl-btz`, `PrivilegesRequired=lowest` (instala sin ser administrador), `OutputDir=..\..\dist`, `OutputBaseFilename=vdl-btz-windows-x64-setup`, `ArchitecturesAllowed=x64compatible`, `Compression=lzma2`; `[Files]`: `Source: "..\..\vdl-btz-windows-x64.exe"; DestName: "vdl-btz.exe"; DestDir: "{app}"` y `Source: "vdl-btz-launcher.vbs"; DestDir: "{app}"`; `[Icons]`: entrada del menú Inicio `Name: "{autoprograms}\vdl-btz"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\vdl-btz-launcher.vbs"""` y la misma como icono opcional de escritorio (`Tasks: desktopicon`, con `[Tasks]` `Name: "desktopicon"; Description: "Crear un icono en el escritorio"`).
- `.github/workflows/build.yml` — (a) añadir a `jobs.binary.strategy.matrix.include` la entrada `{ os: windows-latest, target: windows-x64, experimental: true }` (las entradas `macos-15`, `macos-15-intel` y `ubuntu-24.04` no cambian) y a nivel de job `continue-on-error: ${{ matrix.experimental == true }}`; (b) al paso existente `Preparar carpeta de empaquetado` añadirle `shell: bash` (usa `mkdir` y `cp -R`); (c) a los pasos genéricos existentes `Preparar entorno de Tebako`, `Empaquetar con Tebako`, `Prueba rápida del binario` y al `actions/upload-artifact` genérico (el que sube `vdl-btz-${{ matrix.target }}`) añadirles `if: runner.os != 'Windows'` (en Windows el binario se llama distinto y se empaqueta con pasos propios); (d) añadir estos pasos con `if: runner.os == 'Windows'` y `shell: cmd` o `shell: bash` según se indica, justo antes del paso final de subida: `Preparar MSYS2 para Tebako` (`shell: cmd`) con `gem install tebako -v 0.15.9`, `ridk enable ucrt64`, `pacman -S --noconfirm git tar bison flex pactoys` y `bash -c "pacboy sync --noconfirm toolchain:p make:p cmake:p boost:p diffutils:p libevent:p double-conversion:p fmt:p glog:p dlfcn:p gtest:p autotools:p ncurses:p libyaml:p"` (cada uno en su línea); `Empaquetar binario de Windows` (`shell: bash`) con `tebako setup --Ruby=3.3.7` y `tebako press --root=stage --entry-point=bin/vdl-btz --output=vdl-btz-windows-x64.exe --Ruby=3.3.7 --mode=fat`; `Prueba rápida del binario de Windows` (`shell: bash`) con `./vdl-btz-windows-x64.exe version`; `Crear instalador` (`shell: cmd`) con `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=<versión> packaging\windows\vdl-btz.iss` donde `<versión>` sale de `ruby -Ilib -e "require 'vdl_btz'; print VdlBtz::VERSION"` (guárdala antes en una variable de entorno con un paso `shell: bash` que escriba `VDL_VERSION=...` en `$GITHUB_ENV`); y `actions/upload-artifact` con `name: vdl-btz-windows-x64-setup` y `path: dist/vdl-btz-windows-x64-setup.exe`. Inno Setup ya viene preinstalado en la imagen `windows-latest`.
- `test/packaging_test.rb` — añadir comprobaciones de contenido (`File.read`): el `.vbs` contiene `Run`, `vdl-btz.exe"" gui` y `, 0, False`; el `.iss` contiene `AppName=vdl-btz`, `PrivilegesRequired=lowest`, `OutputBaseFilename=vdl-btz-windows-x64-setup`, `{sys}\wscript.exe` y `vdl-btz-launcher.vbs`; el workflow, parseado con `YAML.load_file`, tiene los pasos genéricos con `if` igual a `runner.os != 'Windows'` y el paso `Preparar carpeta de empaquetado` con `shell` igual a `bash`, y tiene en `jobs.binary.strategy.matrix.include` entradas con `os` igual a `macos-15`, `macos-15-intel`, `ubuntu-24.04` y `windows-latest` (esta última con `experimental` verdadero) y `jobs.binary.continue-on-error` presente.

**Files**
- `packaging/windows/vdl-btz.iss` — new
- `packaging/windows/vdl-btz-launcher.vbs` — new
- `.github/workflows/build.yml` — edit
- `test/packaging_test.rb` — edit

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `vdl-btz-launcher.vbs` is read THE SYSTEM SHALL run `vdl-btz.exe` with the argument `gui` using window style 0 and without waiting (`, 0, False`).
2. WHEN `vdl-btz.iss` is read THE SYSTEM SHALL declare `AppName=vdl-btz`, `PrivilegesRequired=lowest` and `OutputBaseFilename=vdl-btz-windows-x64-setup`, install `vdl-btz.exe` and `vdl-btz-launcher.vbs`, and create a Start Menu icon whose `Filename` is `{sys}\wscript.exe` with the launcher as parameter.
3. WHEN `.github/workflows/build.yml` is parsed as YAML THE SYSTEM SHALL be valid and its `jobs.binary.strategy.matrix.include` SHALL contain entries with `os` equal to `macos-15`, `macos-15-intel`, `ubuntu-24.04` and `windows-latest`, the last with `experimental` true.
4. WHEN the `binary` job definition is read THE SYSTEM SHALL carry `continue-on-error` driven by `matrix.experimental`, so a Windows failure does not fail the macOS and Linux builds.
5. WHEN the Windows-guarded steps are read THE SYSTEM SHALL include `ridk enable ucrt64`, `tebako press` with `--output=vdl-btz-windows-x64.exe`, an `ISCC.exe` call on `packaging\windows\vdl-btz.iss` and an artifact upload of `dist/vdl-btz-windows-x64-setup.exe`.
6. WHEN the generic steps `Preparar entorno de Tebako`, `Empaquetar con Tebako` and `Prueba rápida del binario` are read THE SYSTEM SHALL carry `if: runner.os != 'Windows'`, and the step `Preparar carpeta de empaquetado` SHALL declare `shell: bash`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/packaging_test.rb  # expect: exit 0, 0 failures, 0 errors
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml")'  # expect: exit 0
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E3-T3: Build the Windows binary, hidden launcher and installer"
git tag step-13-windows-package
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E3-T4` — Document the desktop app, downloads and OS warnings

**Depends on:** `E3-T3` · **Priority:** p1 — metadata for scope cuts, not a running order

El README ya tiene instrucciones de instalación con gema y un aviso legal; añade las nuevas secciones y reutiliza el estilo existente (español, tablas, bloques de código). Describe el bloqueo de Gatekeeper/SmartScreen con honestidad: es una limitación asumida del proyecto gratuito.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `README.md` — añadir, sin borrar el contenido existente del CLI, estas secciones (encabezados exactos de nivel 2): `## App de escritorio` (qué es, que se abre con doble clic, que abre una ventana de Chrome/Edge/Brave/Chromium si existe y si no el navegador, que todo es local y no se publica nada en internet, y que los comandos del CLI como `vdl-btz help` siguen funcionando igual), `## Descargas` (enlace a `https://github.com/batuzav/vdl-btz/releases` y los nombres de archivo `vdl-btz-macos-arm64`, `vdl-btz-macos-x64`, `vdl-btz-linux-x64` y `vdl-btz-windows-x64-setup.exe`, con cuál elegir según el equipo), `## Requisitos de sistema` (macOS 15 o superior, Ubuntu 24.04 o superior, Windows 10/11 de 64 bits; y que el binario necesita internet la primera vez para instalar yt-dlp y ffmpeg), `## Si el sistema bloquea la app` (macOS: clic derecho → Abrir, o `xattr -d com.apple.quarantine <archivo>`; Windows: aviso de `SmartScreen` → «Más información» → «Ejecutar de todas formas»; explicación de que las apps no están firmadas porque el proyecto no paga certificados) y `## Aviso legal` (uso personal, respetar derechos de autor y términos de cada plataforma).
- `test/readme_test.rb` — lee `README.md` y comprueba: existen los cinco encabezados; la sección Descargas contiene los cuatro nombres de archivo y la URL de releases; la sección «Si el sistema bloquea la app» contiene `xattr -d com.apple.quarantine` y `SmartScreen`; la sección Requisitos contiene `macOS 15` y `Ubuntu 24.04`; la sección «App de escritorio» contiene `vdl-btz help`; y todo enlace relativo en forma `](ruta)` (sin `http`, sin `#`) apunta a un archivo que existe.

**Files**
- `README.md` — edit
- `test/readme_test.rb` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `README.md` is read THE SYSTEM SHALL contain the level-2 headings `## App de escritorio`, `## Descargas`, `## Requisitos de sistema`, `## Si el sistema bloquea la app` and `## Aviso legal`.
2. WHEN the `## Descargas` section is read THE SYSTEM SHALL name `vdl-btz-macos-arm64`, `vdl-btz-macos-x64`, `vdl-btz-linux-x64` and `vdl-btz-windows-x64-setup.exe` and contain `https://github.com/batuzav/vdl-btz/releases`.
3. WHEN the `## Si el sistema bloquea la app` section is read THE SYSTEM SHALL contain `xattr -d com.apple.quarantine` and `SmartScreen`.
4. WHEN the `## Requisitos de sistema` section is read THE SYSTEM SHALL contain `macOS 15` and `Ubuntu 24.04`.
5. WHEN the `## App de escritorio` section is read THE SYSTEM SHALL contain `vdl-btz help`, stating that CLI commands are unchanged.
6. WHEN every relative Markdown link in `README.md` is resolved THE SYSTEM SHALL find an existing file for each.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -Ilib -Itest test/readme_test.rb  # expect: exit 0, 0 failures, 0 errors
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E3-T4: Document the desktop app, downloads and OS warnings"
git tag step-14-readme-desktop
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

### `E3-T5` — Add the optional webview technical spike

**Depends on:** `E3-T4` · **Priority:** p2 — metadata for scope cuts, not a running order

Es un experimento aislado: no toca el código de la app ni el workflow `build.yml`. Solo comprueba que la gema compila y carga en cada sistema (nivel 1); empaquetarla con Tebako (nivel 2) queda como trabajo posterior si algún sistema da PASS.

**Specification** — what to build, exactly (the same text as this step's **Do** list in the blueprint)

- `.github/workflows/webview-spike.yml` — workflow con `name: Webview spike`, disparador SOLO `workflow_dispatch`, un job `spike` con `runs-on: ${{ matrix.os }}`, `continue-on-error: true` y matriz `os: [macos-15, ubuntu-24.04, windows-latest]` (`fail-fast: false`). Pasos: `actions/checkout@v4`; `ruby/setup-ruby@v1` con `ruby-version: "3.3"`; en Linux (`if: runner.os == 'Linux'`) `sudo apt-get update && sudo apt-get install -y libwebkit2gtk-4.1-dev`; `gem install webview_ruby2 -v 0.2.6`; y un paso final con `shell: bash` que ejecute `ruby -e 'require "webview_ruby"; puts "WEBVIEW_LOAD_OK"'` y escriba en `$GITHUB_STEP_SUMMARY` la línea `${{ matrix.os }}: PASS` si salió bien o `${{ matrix.os }}: FAIL` si no (sin hacer fallar el trabajo).
- `docs/webview-spike.md` — documento en español con el objetivo (comprobar si una ventana nativa con `webview_ruby2` es viable dentro de un binario de Tebako), el método (ejecutar el workflow desde la pestaña Actions) y una tabla con las filas `macOS`, `Linux`, `Windows` y las columnas `Sistema`, `Resultado` (valor inicial `PENDIENTE` en las tres) y `Notas`; más la regla de decisión: «Si un sistema da PASS, el siguiente nivel es empaquetar la gema con Tebako en ese sistema; si falla, se mantiene la ventana de Chrome/Edge (app-window) como versión de producción». Indica que este spike NO forma parte del flujo de lanzamiento.

**Files**
- `.github/workflows/webview-spike.yml` — new
- `docs/webview-spike.md` — new

**Acceptance**

Copied verbatim from this task's `acceptance` array in `tasks.json`. Each one is decidable by a command below, on this machine, during the build.

1. WHEN `.github/workflows/webview-spike.yml` is parsed as YAML THE SYSTEM SHALL be valid, be triggered only by `workflow_dispatch` and define a matrix over `macos-15`, `ubuntu-24.04` and `windows-latest`.
2. WHEN the workflow text is read THE SYSTEM SHALL contain `gem install webview_ruby2 -v 0.2.6` and `require "webview_ruby"` and `WEBVIEW_LOAD_OK`.
3. WHEN `docs/webview-spike.md` is read THE SYSTEM SHALL contain a table with the rows `macOS`, `Linux` and `Windows`, a `Resultado` column whose initial value is `PENDIENTE`, and the decision rule mentioning `app-window`.

**Verify** — every command, in order, run from the project root. Each one exits 0 when this task is correct; the last one exiting 0 is what makes the task done.

```bash
ruby -ryaml -e 'w = YAML.load_file(".github/workflows/webview-spike.yml"); t = w["on"] || w[true]; abort("bad trigger") unless t.keys == ["workflow_dispatch"]'  # expect: exit 0
grep -q 'gem install webview_ruby2 -v 0.2.6' .github/workflows/webview-spike.yml  # expect: exit 0
grep -q 'WEBVIEW_LOAD_OK' .github/workflows/webview-spike.yml  # expect: exit 0
grep -q 'PENDIENTE' docs/webview-spike.md  # expect: exit 0
grep -q 'app-window' docs/webview-spike.md  # expect: exit 0
rake test  # expect: exit 0, 0 failures, 0 errors
```

**Checkpoint**

```bash
git add -A && git commit -m "E3-T5: Add the optional webview technical spike"
git tag step-15-webview-spike
```

Run both after the last `Verify` command exits 0, before starting the next task. The tag is this task's rollback target; if the next task goes wrong, `git reset --hard` to *this* tag rather than debugging forward.

---

## Epic acceptance

La épica está hecha cuando todas sus tareas están `done` **y**:

1. **WHEN** `.github/workflows/build.yml` and `.github/workflows/webview-spike.yml` are parsed as YAML THE SYSTEM SHALL be valid, and `build.yml` SHALL package a macOS `.dmg`, a Linux `.AppImage` and an experimental Windows installer without changing the existing `macos-15`, `macos-15-intel` and `ubuntu-24.04` matrix entries.
2. **WHEN** `rake test` runs THE SYSTEM SHALL exit 0 on macOS, Linux and Windows, with the packaging cases that need `sh`, `plutil`, `codesign` or `hdiutil` skipped where those tools do not exist.

```bash
rake test  # expect: exit 0, 0 failures, 0 errors
ruby -ryaml -e 'YAML.load_file(".github/workflows/build.yml"); YAML.load_file(".github/workflows/webview-spike.yml")'  # expect: exit 0
ruby -Ilib -Itest test/readme_test.rb  # expect: exit 0
```

Ejecuta todo desde la raíz del proyecto. La ejecución real en GitHub (artefactos `.dmg`, `.AppImage`, instalador de Windows) es la lista de lanzamiento del plano, no una compuerta de esta épica.

## Pitfalls

- **YAML 1.1** — en un workflow, la clave `on` se parsea como `true` en Ruby (`YAML.load_file(...)["on"]` es `nil` y `[true]` es el valor); las pruebas deben aceptar ambas.
- **`if: runner.os == 'macOS'`** — escríbelo exactamente así; las pruebas buscan esa cadena en el paso.
- **Comillas dentro del YAML** — las expresiones `${{ matrix.target }}` van tal cual dentro de `run: |`; no las envuelvas en comillas simples.
- **El job `release` descarga con `merge-multiple`** — nombres de artefacto repetidos pisarían archivos: cada artefacto nuevo tiene un `name` distinto (`vdl-btz-<target>-app`, `vdl-btz-linux-x64-appimage`, `vdl-btz-windows-x64-setup`).
- **Windows es experimental** — el job lleva `continue-on-error: ${{ matrix.experimental == true }}`; no lo quites ni conviertas las otras entradas en experimentales.
- **`.gitignore` ya existe** — solo se añade la línea `/dist/` (no reescribas el archivo).

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
