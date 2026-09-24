#!/bin/bash
set -e

echo "=== Installing Ollama Pet to /Applications ==="

# Build native app
./build-native.sh

DEST="/Applications/OllamaPet.app"
USER_DEST="$HOME/Applications/OllamaPet.app"

echo "Installing to Applications folder..."
if [ -w "/Applications" ]; then
    rm -rf "$DEST"
    cp -R "dist-native/OllamaPet.app" "/Applications/"
    FINAL_PATH="$DEST"
else
    mkdir -p "$HOME/Applications"
    rm -rf "$USER_DEST"
    cp -R "dist-native/OllamaPet.app" "$HOME/Applications/"
    FINAL_PATH="$USER_DEST"
fi

echo "✓ Successfully installed to: ${FINAL_PATH}"
echo "Launching Ollama Pet..."
open "${FINAL_PATH}"
