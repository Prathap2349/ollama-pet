#!/bin/bash
set -e

APP_NAME="OllamaPet"
BUILD_DIR="${1:-${BUILD_DIR:-dist-native}}"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
CACHE_DIR=".cache"

echo "=== Building Native macOS Ollama Pet ==="
echo "Target: ${APP_BUNDLE}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${BUILD_DIR}"
touch "${BUILD_DIR}/.metadata_never_index" 2>/dev/null || true
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${CACHE_DIR}"
touch "${CACHE_DIR}/.metadata_never_index" 2>/dev/null || true

echo "1. Compiling Swift Release Binary (Apple Silicon / ARM64)..."
swiftc \
  -O \
  -module-cache-path "${CACHE_DIR}" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  OllamaPetNative/Sources/OllamaPet/*.swift \
  -o "${MACOS_DIR}/${APP_NAME}"

echo "2. Setting executable permissions..."
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "3. Copying App Icon..."
if [ -f "icon.icns" ]; then
  cp "icon.icns" "${RESOURCES_DIR}/AppIcon.icns"
  echo "✓ icon.icns copied."
fi

echo "4. Creating Info.plist..."
cat << 'PLIST' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OllamaPet</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ollamapet.native</string>
    <key>CFBundleName</key>
    <string>Ollama Pet</string>
    <key>CFBundleDisplayName</key>
    <string>Ollama Pet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Ollama Pet uses the microphone for optional Push-to-Talk voice conversations with your AI companion.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Ollama Pet uses speech recognition to convert your voice to text for Ollama.</string>
    <key>NSCameraUsageDescription</key>
    <string>Ollama Pet uses the camera for optional Focus Guardian presence detection. Video is processed locally on device and never stored.</string>
</dict>
</plist>
PLIST

echo "5. Validating Info.plist..."
plutil -lint "${APP_BUNDLE}/Contents/Info.plist"

echo "6. Code Signing Bundle (Ad-hoc)..."
dot_clean "${APP_BUNDLE}" 2>/dev/null || true
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
xattr -c "${APP_BUNDLE}" 2>/dev/null || true
xattr -d com.apple.FinderInfo "${APP_BUNDLE}" 2>/dev/null || true
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "7. Validating Code Signature..."
codesign --verify --deep --strict --verbose=4 "${APP_BUNDLE}"

echo "8. Creating Distributable Release Archive..."
ROOT_DIR="$(pwd)"
RELEASE_DIR="${ROOT_DIR}/dist-release"
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"
(cd "${BUILD_DIR}" && zip -r -y -q "${RELEASE_DIR}/OllamaPet-macOS.zip" "${APP_NAME}.app")

echo "=== Successfully Built: ${APP_BUNDLE} ==="
ls -ld "${APP_BUNDLE}"
file "${MACOS_DIR}/${APP_NAME}"
echo "=== Release Archive Ready: ${RELEASE_DIR}/OllamaPet-macOS.zip ==="
ls -lh "${RELEASE_DIR}/OllamaPet-macOS.zip"
