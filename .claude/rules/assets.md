---
paths:
  - "lib/vdl_btz/gui/assets/**"
---

# Página, estilos y JavaScript

- **CSP:** `default-src 'self'; img-src 'self' data:; frame-ancestors 'none'`. Prohibido `<script>` con código en línea y atributos `style=`; el token llega en `<meta name="vdl-token">`.
- **XSS:** los títulos y errores vienen de sitios remotos. Escribe SIEMPRE con `textContent`/`createElement`/`setAttribute`. Prohibidos `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `eval(` y `document.write` (una prueba lo comprueba).
- **Contrato DOM:** los ids son exactos (`masthead`, `dateline`, `theme-toggle`, `setup`, `setup-label`, `setup-progress`, `form-add`, `urls`, `mode-video`, `mode-audio`, `quality`, `btn-add`, `msg`, `jobs`, `empty`, `cfg-output`, `cfg-quality`, `cfg-cookies`, `btn-save-config`, `btn-update-engine`, `legal`); cada `getElementById("...")` de `app.js` debe existir en `index.html`.
- **Diseño monocromo:** sin color de acento, sin esquinas redondeadas, sin sombras; tokens `--paper`, `--paper-2`, `--ink`, `--ink-soft`, `--rule`, `--grain-opacity`, `--grain-blend` definidos una sola vez en `app.css` (claro, y oscuro por `prefers-color-scheme` y `data-theme`). Los componentes usan nombres de token, nunca `#hex` sueltos.
- **Tipos:** `Hanken Grotesk` y `Space Mono` autoalojadas en `assets/fonts/` con `font-display: swap`; no cargues nada de un CDN y no modifiques los `.woff2`.
- **Estado:** nunca solo por color; etiquetas en mayúsculas `EN COLA`, `DESCARGANDO`, `LISTO`, `ERROR`, `CANCELADO`; un error añade filete doble.
- **Accesibilidad:** `label` para cada campo, `#msg` con `role="status"` y `aria-live="polite"`, foco visible de 2 px, botones de al menos 44 px, enlace «Saltar al contenido», sin animaciones.
- Sin dependencias ni `import`; funciones pequeñas; `localStorage` solo dentro de `try/catch`.
