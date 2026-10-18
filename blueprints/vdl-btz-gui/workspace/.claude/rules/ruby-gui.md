---
paths:
  - "lib/vdl_btz/gui/**/*.rb"
  - "lib/vdl_btz/cli.rb"
  - "lib/vdl_btz/os.rb"
---

# Servidor local, API y cola

- Enlaza solo a `"127.0.0.1"`; nunca `0.0.0.0` ni `localhost` (puede resolverse a IPv6 y la URL impresa dejaría de coincidir).
- Orden fijo de comprobaciones en el servidor: línea de petición (`400 bad_request`) → `Host` (`403 bad_host`) → tamaño (`413 too_large`) → si la ruta empieza por `/api/`, token (`401 unauthorized`) → método no admitido (`405`) o ruta desconocida (`404`) → ruta. Ninguna ruta nueva puede saltárselo.
- Todas las respuestas llevan las cuatro cabeceras de seguridad y el sobre JSON `{"ok":true,"data":...}` / `{"ok":false,"error":{"code","message"}}`; los códigos son estables y en inglés, los mensajes en español.
- `server.rb` no conoce `Downloader`, `Config` ni yt-dlp; `api.rb` no abre sockets; `jobs.rb` no conoce HTTP.
- Solo biblioteca estándar. Si necesitas una gema, detente.
- `Process.spawn`/`Open3` con arrays de argumentos; devuelve `false` ante `SystemCallError` en lugar de lanzar.
- No mantengas un `Mutex` mientras corre el `runner` de un trabajo ni imprimas el token salvo en la línea `URL:` del arranque.
- Todo lo que toca el sistema (abrir carpetas, lanzar navegadores, instalar) entra por parámetros inyectables para poder probarlo.
- `vdl-btz` sin argumentos sigue imprimiendo la ayuda; no cambies el comportamiento de los comandos existentes.
- `# frozen_string_literal: true` en cada archivo, dentro de `module VdlBtz`; errores controlados con `VdlBtz::Error` y textos en español.
