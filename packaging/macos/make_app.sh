#!/bin/sh
# Empaqueta el binario de Tebako como vdl-btz.app y vdl-btz-<arch>.dmg (solo macOS).
# Uso: make_app.sh <binario> <arch> <version> <outdir>
set -eu

# Los argumentos se comprueban antes que cualquier otra cosa: el resultado no depende del sistema.
if [ "$#" -ne 4 ]; then
  echo "Uso: make_app.sh <binario> <arch> <version> <outdir>" >&2
  exit 64
fi
bin=$1
arch=$2
version=$3
out=$4
app="$out/vdl-btz.app"

rm -rf "$app"
# El binario de Tebako lleva datos pegados al final: codesign lo rechaza como código en MacOS/, así que va en Resources/.
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/Resources/vdl-btz"
chmod 755 "$app/Contents/Resources/vdl-btz"

# El lanzador abre la aplicación (comando gui) sin mostrar Terminal.
printf '#!/bin/sh\nexec "$(dirname "$0")/../Resources/vdl-btz" gui\n' > "$app/Contents/MacOS/vdl-btz-launcher"
chmod 755 "$app/Contents/MacOS/vdl-btz-launcher"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>vdl-btz</string>
  <key>CFBundleDisplayName</key><string>vdl-btz</string>
  <key>CFBundleIdentifier</key><string>com.batuzav.vdl-btz</string>
  <key>CFBundleExecutable</key><string>vdl-btz-launcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Firma ad-hoc (gratuita): deja la app con firma válida; no evita el aviso de Gatekeeper al descargarla.
codesign --force --deep -s - "$app"
hdiutil create -volname vdl-btz -srcfolder "$app" -ov -format UDZO "$out/vdl-btz-$arch.dmg"
