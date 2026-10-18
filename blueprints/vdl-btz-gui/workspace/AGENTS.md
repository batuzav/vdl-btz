# vdl-btz — AGENTS.md

Herramienta en Ruby que descarga videos de TikTok, YouTube, Instagram y Facebook. Tiene un CLI (`vdl-btz`) y una aplicación de escritorio local (`vdl-btz gui`) con un servidor HTTP propio en `127.0.0.1`, una página de periódico en HTML/CSS/JS planos y empaquetado con Tebako. Este archivo es un puente: **`CLAUDE.md` es la fuente de verdad**.

## Commands

- Instalar: `bundle install`
- Todas las pruebas: `rake test` (debe terminar con estado 0 antes de marcar nada como hecho)
- Una prueba: `ruby -Ilib -Itest test/<nombre>_test.rb`
- CLI: `ruby bin/vdl-btz <args>` · Servidor sin ventana: `ruby bin/vdl-btz gui --no-window`

## Las tres reglas que más importan

1. **Solo biblioteca estándar de Ruby**: ninguna gema nueva (el binario se empaqueta sin `Gemfile`).
2. **El CLI está congelado**: `vdl-btz` sin argumentos imprime la ayuda; no cambian comandos, opciones, códigos de salida ni `config.yml`.
3. **Seguridad del servidor local**: solo `127.0.0.1`, token en `X-VDL-Token`, validación de `Host` antes de cualquier ruta, y nada de `innerHTML` en el navegador.

Los pasos de construcción están en `blueprints/vdl-btz-gui/` (`tasks.json` y `epics/`); cada paso termina con un commit y la etiqueta `step-NN-slug`.
