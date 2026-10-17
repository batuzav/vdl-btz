---
paths:
  - "test/**"
---

# Pruebas

- Minitest con `rake test`; una prueba suelta con `ruby -Ilib -Itest test/<nombre>_test.rb`. Todas empiezan con `require "test_helper"`.
- Independientes del sistema operativo: las rutas esperadas se calculan con `File.expand_path`/`File.join` (en Windows `File.expand_path("/tmp/x")` da `D:/tmp/x`); lo que solo existe en POSIX (`sh`, `Process.kill("TERM")`) o en macOS (`plutil`, `codesign`, `hdiutil`) se omite con `skip` en los demás.
- `test/test_helper.rb` fija `VDL_BTZ_HOME` temporal y `NO_COLOR` (y, desde el paso 7, `HOME` igual al directorio temporal para que `Dir.home` no apunte a la carpeta personal real). **Nunca crees ni borres nada fuera de directorios temporales** (`Dir.mktmpdir`); nunca uses `rm_rf` sobre una ruta derivada de la configuración sin comprobar que está bajo `Dir.tmpdir`.
- Nada de red ni de servicios externos: instaladores, descargadores y navegadores se sustituyen por dobles simples (objetos con los mismos métodos públicos, scripts `#!/bin/sh` de mentira).
- Los servidores de prueba se arrancan con puerto 0 y token conocido; todo subproceso que lance un test se termina en un `ensure`.
- Asegura propiedades, no recuentos: nada de «espera N pruebas»; no dependas del orden de ejecución.
- Un caso con espera usa un tiempo máximo explícito (segundos) y falla con un mensaje claro; no uses `sleep` largos.
- Las pruebas del contrato de `app.js` son estáticas (ids, rutas, construcciones prohibidas); la sintaxis con `node --check` solo si `node` está instalado, si no `skip`.
