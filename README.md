<p align="center">
  <img src="banner.png" alt="Ollama Pet Banner" width="100%">
</p>

<h1 align="center">🐾 Ollama Pet</h1>

<p align="center">
  <b>Your Local AI Desktop Companion — Now Available as a Lightweight Native macOS Application (Swift/SwiftUI) & Cross-Platform Companion</b>
</p>

A local AI desktop companion that lives on your screen — powered entirely by [Ollama](https://ollama.ai) running on your own machine. No cloud, no external API keys, no subscriptions. Chat with your pet, watch it dance to your music, schedule reminders that survive restarts, check live weather, track focus with Pomodoro, and monitor real system vitals.

---

## ⚡ What's New: Native macOS Edition (`Swift` + `SwiftUI` + `AppKit`)

Ollama Pet has been rebuilt natively for macOS using **Swift**, **SwiftUI**, and **AppKit** alongside the existing cross-platform edition!

- 🚀 **Blazing Fast & Lightweight**: Zero Chromium overhead, instantaneous startup, and minimal memory usage.
- 🪟 **True Native Floating NSPanel**: Genuine transparent background with zero black or white flash on spawn.
- 🎯 **Smooth Draggable Interface**: Exact mouse-offset dragging with a 5px threshold (click vs drag separation) and corner snapping.
- 🖥 **Multi-Monitor Safe**: Clamped to visible screen areas with automatic layout recovery when external monitors disconnect or rearrange.
- ⚡ **Apple Silicon Optimized**: Native ARM64 Mach-O binary compiled specifically for macOS 13+ (Ventura, Sonoma, Sequoia).
- 🐾 **Menu Bar & Global Hotkey**: Access via the status bar item (`🐾`) or toggle visibility globally anytime using <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd>.

---

## ✨ Features

| Feature | What it does |
|---|---|
| 💬 **AI Chat** | Talk to your pet using Ollama local models (`gemma4`, `llama3.2`, `phi3`, etc.). Auto-detects installed models and supports exact-prompt retries. |
| 🐾 **7 Unique Characters** | **Mochi** (Cat 🐱), **Ember** (Dragon 🐉), **ARIA** (Robot 🤖), **NEO** (RobotCat 🐱‍💻), **BOO** (Ghost 👻), **KITA** (Fox 🦊), and **POCHI** (Bunny 🐰) — each with custom animations, colors, and personalities. |
| 🎭 **5 Animation States** | `Idle`, `Dance`, `Thinking`, `Sleep` (with Zzz bubbles), and `Shock`. |
| 🎵 **Music & Dance** | Upload an audio file — the pet dances to an 8-band live beat visualizer with selectable vibes (Pop, Rock, Chill, Rave). |
| ⏰ **Persistent Reminders** | Set reminders that survive restarts (`~/ollama-pet-data.json`). Immediate overdue alerts if due date passed while offline. |
| 🌤 **Live Weather** | Search any city worldwide via Open-Meteo for real-time temperature, condition icons, and daily highs/lows. |
| 🍅 **Pomodoro Timer** | Built-in 25-minute focus session and 5-minute break timers with desktop notifications. |
| 📊 **System Vitals** | Real Mach kernel CPU load, IOKit battery percentage/charging status, system uptime, and active foreground apps. |
| 🚶 **Walk Mode** | Pet hops into a borderless bottom panel and walks across your screen with natural turnarounds. |
| 🎮 **Mini Games** | Play Rock Paper Scissors or test your knowledge with interactive trivia questions. |
| 📌 **Always-on-Top & Companion Mode** | Floats on top of all spaces and fullscreen apps; optional click-through companion mode. |

---

## 🛠 Project Structure

```
ollama-pet/
├── OllamaPetNative/               # Native macOS Swift codebase
│   ├── Package.swift              # SPM package definition
│   └── Sources/OllamaPet/
│       ├── AppDelegate.swift      # Menu bar status item, hotkey & app lifecycle
│       ├── ChatView.swift         # Multi-tab SwiftUI drawer (Chat, Weather, Reminders, etc.)
│       ├── DataManager.swift      # Persistent storage & UNUserNotificationCenter alerts
│       ├── Models.swift           # Characters, moods, chat and reminder data types
│       ├── MusicManager.swift     # AVFoundation audio player & audio metering
│       ├── OllamaClient.swift     # URLSession client for localhost:11434 (tags, chat, retry)
│       ├── PetArtwork.swift       # SVG vector rendering for all 7 species & animations
│       ├── PetStageView.swift     # Transparent interactive pet stage & status bubbles
│       ├── PetState.swift         # Animation, mood, Pomodoro, and game state machine
│       ├── PetWindowController.swift # NSPanel with exact-offset dragging & snapping
│       ├── SoundEffects.swift     # AudioToolbox sound effects
│       ├── SystemMonitor.swift    # Mach host processor stats, IOKit power & NSWorkspace
│       ├── WalkerManager.swift    # Bottom-screen walk panel animation
│       └── main.swift             # Native app entry point
├── build-native.sh                # Automated build & packaging script for Native macOS .app
├── build-app.sh                   # Build script for Electron package
├── icon.icns                      # High-resolution macOS app icon bundle
├── icon.png                       # App icon asset
├── index.html                     # Cross-platform Web UI reference
├── main.js                        # Cross-platform Electron runtime reference
└── package.json                   # Node.js project manifest
```

---

## 🚀 Building & Running

### 1. Requirements

- **macOS**: macOS 13.0 or later (Apple Silicon or Intel).
- **Xcode Command Line Tools**: `xcode-select --install`
- **Ollama**: Download from [ollama.ai](https://ollama.ai) and pull any model:
  ```bash
  ollama pull gemma4:12b
  # or
  ollama pull phi3
  ```

---

### 2. Option A — Build the Genuine Native macOS `.app` (Recommended)

To compile and package the native Swift application bundle:

```bash
git clone git@github.com:Prathap2349/ollama-pet.git
cd ollama-pet

# Compile and package OllamaPet.app into dist-native/
./build-native.sh
```

To run the native application:
```bash
open dist-native/OllamaPet.app
```
*You can also drag `dist-native/OllamaPet.app` directly into your `/Applications` folder!*

---

### 3. Option B — Run the Electron Version (Cross-Platform)

```bash
git clone git@github.com:Prathap2349/ollama-pet.git
cd ollama-pet

npm install
npm start
```

---

## ⌨️ Shortcuts & Controls

- **Click Pet**: Open or close the interactive drawer.
- **Drag Pet**: Reposition anywhere on screen with automatic corner snapping.
- **5 Clicks in a Row**: Triggers an instant celebration dance party! 🎉
- <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd>: Toggle pet visibility globally on macOS.
- **Status Bar Menu (`🐾`)**: Switch characters, toggle launch at login, or quit the app.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
