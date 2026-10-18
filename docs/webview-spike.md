# Prueba técnica: ventana nativa con webview

## Objetivo
Comprobar si una **ventana nativa** hecha con la gema `webview_ruby2` es viable dentro de un binario de Tebako. Hoy la app abre una ventana de Chrome, Edge, Brave o Chromium en modo aplicación (`app-window`) y, si no hay ninguno, el navegador por defecto. Una ventana nativa sería más pulida, pero la gema se compila al instalarse, declara que Windows no está soportado y no se sabe si funciona empaquetada con Tebako.

Este experimento **no forma parte del flujo de lanzamiento** y no cambia el código de la aplicación.

## Método
1. En GitHub, pestaña **Actions** → **Webview spike** → **Run workflow**.
2. El workflow instala la gema y comprueba que se pueda cargar (`require "webview_ruby"`) en macOS, Ubuntu y Windows.
3. Cada trabajo escribe `PASS` o `FAIL` en su resumen. Anota aquí el resultado.

Este es el **nivel 1** (¿compila y carga?). Empaquetarla con Tebako (nivel 2) queda como trabajo posterior si algún sistema da `PASS`.

## Resultados

| Sistema | Resultado | Notas |
|---|---|---|
| macOS | PENDIENTE | |
| Linux | PENDIENTE | necesita `libwebkit2gtk-4.1-dev` (el workflow lo instala) |
| Windows | PENDIENTE | la propia gema avisa de que Windows no está soportado de serie |

## Regla de decisión
Si un sistema da PASS, el siguiente nivel es empaquetar la gema con Tebako en ese sistema; si falla, se mantiene la ventana de Chrome/Edge (`app-window`) como versión de producción.
