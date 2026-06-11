#!/bin/bash
# ─────────────────────────────────────────────
# OllamaPet — Build .app for macOS
# Run this ONCE from inside the pet folder:
#   chmod +x build-app.sh && ./build-app.sh
# ─────────────────────────────────────────────

set -e
echo "📦 Installing electron-packager..."
npm install --save-dev electron-packager

echo "🔨 Building OllamaPet.app..."
# Detect chip: arm64 = Apple Silicon (M1/M2/M3), x64 = Intel
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ELECTRON_ARCH="arm64"
else
  ELECTRON_ARCH="x64"
fi

npx electron-packager . OllamaPet \
  --platform=darwin \
  --arch=$ELECTRON_ARCH \
  --out=dist \
  --overwrite \
  --app-bundle-id=com.prathap.ollamapet \
  --app-version=1.0.0 \
  --ignore=dist \
  --ignore=.git \
  --ignore=build-app.sh

echo ""
echo "✅ Done! Your app is at:"
echo "   $(pwd)/dist/OllamaPet-darwin-$ELECTRON_ARCH/OllamaPet.app"
echo ""
echo "➡️  Next steps:"
echo "   1. Copy OllamaPet.app to your /Applications folder"
echo "   2. Double-click it once to launch"
echo "   3. It will auto-start every time you log in from now on"
echo "   4. macOS may say 'unidentified developer' — right-click → Open to bypass"
echo ""
echo "To STOP auto-start: System Settings → General → Login Items → remove OllamaPet"
echo "To DELETE: drag OllamaPet.app to Trash"
