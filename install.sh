#!/bin/bash
set -e

echo "=== Installing Ollama Pet ==="

APP_NAME="OllamaPet"
TEMP_BUILD_DIR="/tmp/OllamaPetBuild"
TEMP_BUNDLE="${TEMP_BUILD_DIR}/${APP_NAME}.app"

# 1. Build into clean temporary build location
echo "Step 1: Building native app in temporary location..."
mkdir -p "${TEMP_BUILD_DIR}"
./build-native.sh "${TEMP_BUILD_DIR}"

# 2. Validate App Bundle
echo "Step 2: Validating App Bundle structure..."
if [ ! -d "${TEMP_BUNDLE}" ] || [ ! -d "${TEMP_BUNDLE}/Contents/MacOS" ] || [ ! -f "${TEMP_BUNDLE}/Contents/MacOS/${APP_NAME}" ]; then
    echo "❌ Error: App bundle is malformed or executable is missing."
    exit 1
fi

# 3. Validate Executable
echo "Step 3: Validating Executable..."
chmod +x "${TEMP_BUNDLE}/Contents/MacOS/${APP_NAME}"
file "${TEMP_BUNDLE}/Contents/MacOS/${APP_NAME}" | grep -q "Mach-O 64-bit executable arm64" || {
    echo "❌ Error: Executable is not an arm64 Mach-O binary."
    exit 1
}

# 4. Validate Info.plist
echo "Step 4: Validating Info.plist..."
plutil -lint "${TEMP_BUNDLE}/Contents/Info.plist"

# 5. Validate Code Signature
echo "Step 5: Validating Code Signature..."
codesign --verify --deep --strict --verbose=4 "${TEMP_BUNDLE}"

# 6. Check existing installation and safely remove old version
echo "Step 6: Checking installation targets..."
DEST="/Applications/OllamaPet.app"
USER_DEST="$HOME/Applications/OllamaPet.app"

is_ollama_pet() {
    local target="$1"
    if [ -d "$target" ] && [ -f "$target/Contents/Info.plist" ]; then
        local bundle_id
        bundle_id=$(plutil -extract CFBundleIdentifier raw "$target/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$target/Contents/Info.plist" 2>/dev/null || echo "")
        if [[ "$bundle_id" == *"ollamapet"* ]]; then
            return 0
        fi
    fi
    return 1
}

# Stop any running instances before replacement
killall OllamaPet 2>/dev/null || true
sleep 0.5

TARGET_DIR=""
FINAL_PATH=""

if [ -w "/Applications" ]; then
    TARGET_DIR="/Applications"
    FINAL_PATH="$DEST"
else
    mkdir -p "$HOME/Applications"
    TARGET_DIR="$HOME/Applications"
    FINAL_PATH="$USER_DEST"
fi

if [ -d "$DEST" ]; then
    if is_ollama_pet "$DEST"; then
        echo "Removing previous version from $DEST..."
        rm -rf "$DEST"
    else
        echo "❌ Caution: $DEST exists but does not appear to be Ollama Pet (bundle ID mismatch). Aborting."
        exit 1
    fi
fi

if [ -d "$USER_DEST" ] && [ "$FINAL_PATH" != "$USER_DEST" ]; then
    if is_ollama_pet "$USER_DEST"; then
        echo "Removing duplicate from $USER_DEST..."
        rm -rf "$USER_DEST"
    fi
fi

# 7. Install new version
echo "Step 7: Installing to ${FINAL_PATH}..."
cp -R "${TEMP_BUNDLE}" "${TARGET_DIR}/"

# Clear quarantine to prevent Gatekeeper blockage
xattr -dr com.apple.quarantine "${FINAL_PATH}" 2>/dev/null || true
codesign --force --deep --sign - "${FINAL_PATH}"
codesign --verify --deep --strict --verbose=4 "${FINAL_PATH}"

# 8. Remove temporary & duplicate repository build artifacts
echo "Step 8: Cleaning up build artifacts to prevent Spotlight duplicates..."
rm -rf "${TEMP_BUILD_DIR}"
rm -rf "dist-native/OllamaPet.app" 2>/dev/null || true
rm -rf "dist/OllamaPet.app" 2>/dev/null || true

# 9. Launch installed app and verify process
echo "Step 9: Launching installed application..."
open "${FINAL_PATH}"

# Verification
sleep 2.0
RUNNING_PID=$(pgrep -f "/Contents/MacOS/${APP_NAME}" 2>/dev/null | head -n 1 || true)
if [ -z "$RUNNING_PID" ]; then
    RUNNING_PID=$(pgrep -x "${APP_NAME}" 2>/dev/null | head -n 1 || true)
fi

if [ -n "$RUNNING_PID" ]; then
    echo "=========================================="
    echo "✓ Ollama Pet successfully installed & launched!"
    echo "✓ Path: ${FINAL_PATH}"
    echo "✓ Running PID: ${RUNNING_PID}"
    echo "=========================================="
else
    echo "⚠️ Warning: Ollama Pet was launched but does not appear in running processes."
    echo "Recent log output:"
    log show --predicate 'process == "OllamaPet"' --info --last 1m 2>/dev/null | tail -n 20 || true
fi
