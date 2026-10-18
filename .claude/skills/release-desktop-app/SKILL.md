---
name: release-desktop-app
description: Publica una versión de la app de escritorio de vdl-btz creando la etiqueta v<versión> que dispara el Release en GitHub Actions. Úsala cuando pidan "publica una versión", "saca el release de la app" o "crea la etiqueta v".
---

# Release the desktop app

## When to use
Cuando todas las compuertas están en verde y se quiere publicar `.dmg`, AppImage, instalador de Windows y binarios en la pestaña Releases.

## Steps
1. Comprueba la compuerta global: `rake test` termina con estado 0 en tu máquina y el último push a `master` tiene los tres trabajos `Tests` en verde en GitHub Actions.
2. Revisa que `lib/vdl_btz/version.rb` tiene la versión que se va a publicar y que el README la menciona de forma coherente.
3. Recorre la lista de lanzamiento del plano (`blueprints/vdl-btz-gui/blueprint.md`, sección 20.4): descarga real por plataforma, apertura del `.app` en macOS 15 o superior, instalación en Windows, AppImage en Ubuntu, análisis en VirusTotal y las tres pasadas de accesibilidad. Anota cualquier punto que no se pueda comprobar.
4. Crea la etiqueta anotada `v<versión>` (por ejemplo `git tag v0.2.0`) y **pide confirmación a la persona responsable antes de empujarla**: subir la etiqueta publica el Release y no se puede deshacer limpiamente.
5. Tras el Release, comprueba que aparecen los archivos esperados y que los enlaces del README apuntan a ellos.

## Verify
```bash
rake test   # expect: exit 0, 0 failures, 0 errors
git tag -l 'v*'   # expect: lists the new tag after step 4
```

## Do not
- No empujes la etiqueta sin confirmación explícita.
- No publiques si el job `test` de algún sistema está en rojo.
- No añadas secretos ni certificados al workflow.
