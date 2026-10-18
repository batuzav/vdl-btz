---
name: add-api-route
description: Añade una ruta nueva a la API de la pantalla de vdl-btz (lib/vdl_btz/gui/api.rb) con su validación, su código de error y su prueba. Úsala cuando pidan "añade una ruta a la API", "nuevo endpoint de la pantalla" o cuando app.js necesite un dato que la API no da.
---

# Add API route

## When to use
Cuando la pantalla necesita una operación o un dato nuevo del servidor local y no existe una ruta `/api/...` que lo dé.

## Steps
1. Decide método y ruta (`/api/<nombre>`); toda ruta bajo `/api/` ya exige `X-VDL-Token` desde `server.rb`, no lo repitas en `api.rb`.
2. En `lib/vdl_btz/gui/api.rb` añade la rama en `call(request)`; valida el cuerpo en el borde (tipo JSON, tamaño, valores) ANTES de tocar la lógica y devuelve siempre el sobre `{"ok":true,"data":...}` o `{"ok":false,"error":{"code":...,"message":...}}`.
3. Si la ruta puede fallar, reutiliza un código estable existente o añade uno nuevo en inglés (`snake_case`) con texto en español, y anótalo en la tabla de códigos del plano.
4. Si necesita el sistema (abrir carpetas, lanzar procesos), recíbelo como parámetro inyectable (`opener:` y similares) para poder probarlo sin tocar el equipo.
5. Añade el caso en el archivo de pruebas de la API que corresponda (`test/gui_api_jobs_test.rb` o `test/gui_api_settings_test.rb`): éxito, cada error y, si escribe en disco, el estado del archivo antes y después.
6. Si `app.js` la usa, añade la cadena de la ruta al contrato estático de `test/gui_assets_test.rb`.

## Verify
```bash
ruby -Ilib -Itest test/gui_api_jobs_test.rb   # expect: exit 0
ruby -Ilib -Itest test/gui_api_settings_test.rb   # expect: exit 0
rake test   # expect: exit 0, 0 failures, 0 errors
```

## Do not
- No devuelvas HTML ni texto plano desde `/api/`; no inventes otro formato de error.
- No aceptes rutas de archivo del cliente: abre carpetas solo a partir de ids de trabajo.
- No añadas gemas ni dejes una ruta sin prueba.
