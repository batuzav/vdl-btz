---
paths:
  - "packaging/**"
  - ".github/workflows/**"
---

# Empaquetado y CI

- Los scripts de `packaging/` son `sh` POSIX con `set -eu`; comprueban el número de argumentos ANTES de cualquier otra cosa y salen con estado 64 (con una línea de uso) si faltan.
- No uses `cp -n` en los scripts: en macOS/BSD sale con 1 cuando omite un archivo. Trabaja sobre un directorio de salida recién creado.
- No cambies ni reordenes los pasos existentes del job `binary` salvo lo que indique la tarea; las entradas `macos-15`, `macos-15-intel` y `ubuntu-24.04` de la matriz no se tocan.
- Cada paso nuevo va protegido por `runner.os` (`if: runner.os == 'macOS'`, `'Linux'` o `'Windows'`); los pasos genéricos existentes llevan `if: runner.os != 'Windows'`.
- Windows es experimental: el job lleva `continue-on-error: ${{ matrix.experimental == true }}`; no lo quites ni conviertas las otras entradas en experimentales.
- Cada artefacto nuevo tiene un `name` distinto (`vdl-btz-<target>-app`, `vdl-btz-linux-x64-appimage`, `vdl-btz-windows-x64-setup`); el job `release` descarga con `merge-multiple`.
- Las salidas van a `dist/` (ignorado por git); nunca confirmes binarios.
- Sin firma de pago ni notarización: no añadas secretos, certificados ni pasos que los necesiten; la firma de macOS es *ad-hoc* (`codesign -s -`).
- En un workflow la clave `on` se lee como `true` en YAML 1.1; las pruebas deben aceptar ambas formas.
