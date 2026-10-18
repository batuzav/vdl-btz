#!/bin/sh
# Empaqueta el binario de Tebako como AppImage de Linux.
# Uso: make_appimage.sh <binario> <arch> <outdir> [--appdir-only]
#   --appdir-only  solo construye <outdir>/vdl-btz.AppDir (sin appimagetool)
set -eu

# Los argumentos se comprueban antes que cualquier otra cosa: el resultado no depende del sistema.
if [ "$#" -lt 3 ]; then
  echo "Uso: make_appimage.sh <binario> <arch> <outdir> [--appdir-only]" >&2
  exit 64
fi
bin=$1
arch=$2
out=$3
only_appdir=${4:-}
here=$(cd "$(dirname "$0")" && pwd)
appdir="$out/vdl-btz.AppDir"

rm -rf "$appdir"
mkdir -p "$appdir/usr/bin"
cp "$bin" "$appdir/usr/bin/vdl-btz"
chmod 755 "$appdir/usr/bin/vdl-btz"
cp "$here/vdl-btz.desktop" "$here/vdl-btz.svg" "$appdir/"

# AppRun abre la aplicación (comando gui) desde dentro del AppImage.
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/vdl-btz" gui
EOF
chmod 755 "$appdir/AppRun"

[ "$only_appdir" = "--appdir-only" ] && exit 0

if ! command -v appimagetool >/dev/null 2>&1; then
  echo "appimagetool no encontrado" >&2
  exit 2
fi
# --appimage-extract-and-run evita depender de FUSE (por ejemplo en el servidor de CI).
ARCH="$arch" appimagetool --appimage-extract-and-run "$appdir" "$out/vdl-btz-$arch.AppImage"
