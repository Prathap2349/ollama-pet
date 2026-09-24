<p align="center">
  <img src="banner.png" alt="Ollama Pet Banner" width="100%">
</p>

<h1 align="center">🐾 Ollama Pet</h1>

<p align="center">
  <b>Lightweight, Native macOS Desktop AI Companion built with Swift, SwiftUI, and AppKit</b>
</p>

A local AI desktop companion that lives on your screen — powered entirely by [Ollama](https://ollama.ai) running on your own machine. No cloud, no external API keys, no subscriptions, and zero web runtime overhead. Chat with your pet, watch it dance to your music, schedule reminders that survive restarts, check live weather, track focus with Pomodoro, and monitor real system vitals.

---

## ⚡ Native macOS Architecture

Ollama Pet is built natively for macOS using **Swift**, **SwiftUI**, and **AppKit**:

- 🚀 **Blazing Fast & Lightweight**: Zero Chromium or Node.js overhead, instantaneous startup, and minimal memory usage.
- 🪟 **True Floating NSPanel**: Borderless, transparent floating window with zero window flickering on spawn.
- 🎯 **Anchor-Aware Dynamic Geometry**: Control drawer expands intelligently away from screen edges based on quadrant detection, preserving pet screen coordinates with 0px cumulative drift.
- 🖐️ **Fluid Draggable Interface**: Mouse-offset dragging with a 5px threshold (click vs. drag separation) and corner snapping.
- 🖥️ **Multi-Monitor Safe**: Window bounds are automatically constrained to active display `workArea` boundaries.
- ⚡ **Apple Silicon Optimized**: Native ARM64 Mach-O binary compiled for macOS 13+ (Ventura, Sonoma, Sequoia).
- 🐾 **Menu Bar & Global Hotkey**: Access via the status bar item (`🐾`) or toggle visibility globally anytime using <kbd>Cmd</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd>.

---

## ✨ Features

| Feature | What it does |
|---|---|
| 💬 **AI Chat & Voice Assistant** | Talk to your pet using local Ollama models (`llama3.2`, `gemma2`, `phi3`, etc.). Includes full Push-to-Talk speech recognition (`SFSpeechRecognizer`), voice responses (`AVSpeechSynthesizer`), and voice speed/volume controls. |
| 🐾 **7 Unique Characters** | **Mochi** (Cat 🐱), **Ember** (Dragon 🐉), **ARIA** (Robot 🤖), **NEO** (RobotCat 🐱‍💻), **BOO** (Ghost 👻), **KITA** (Fox 🦊), and **POCHI** (Bunny 🐰) — each with distinct anatomy, silhouettes, facial features, and animations. |
| 🎭 **5 Animation States** | `Idle`, `Dance`, `Thinking`, `Sleep` (with Zzz bubbles), and `Shock`. |
| 🚶 **Realistic Gaits & Walk Mode** | Species-tailored walking physics: Cat quad-stride, Fox trot, Bunny hops, Dragon wing-beats, Robot mechanical walk, and Ghost floating waves. Includes speed controls ($0.5\times - 2.0\times$) and preview test walk. |
| 👁️ **Optional Vision Guardian** | Privacy-first Apple Vision human detection. Periodically scans ($640\times 480$, 5s/10s/30s) to detect presence, prevent prolonged stillness, and welcome you back when returning to your desk. Off by default. |
| 🖥️ **Optional Screen Context** | Lightweight activity awareness checking active app context (Coding, Terminal, Browser, Documents) without continuous screen recording. Off by default. |
| 🍅 **Focus Guardian & Hydration** | Built-in 25-minute focus session with Vision break alerts and periodic hydration reminders (30/60/90 mins). |
| 🎵 **Music & Dance** | Upload an audio file — AVFoundation metering powers a live beat visualizer with selectable dance vibes. |
| ⏰ **Persistent Reminders** | Set reminders that survive restarts (`~/ollama-pet-data.json`). Delivers system notifications via `UNUserNotificationCenter`. |
| 🌤️ **Live Weather** | Search any city worldwide via Open-Meteo for real-time temperature, condition icons, and daily highs/lows. |
| 📊 **System Vitals** | Real Mach kernel CPU load, IOKit battery percentage/charging status, system uptime, and active foreground apps. |
| ⌨️ **Customizable Shortcuts** | Assign custom global hotkeys for Pet Toggle, Voice Assistant Push-to-Talk, and Focus Timer with instant duplicate/conflict detection. |
| 🔐 **Privacy Center** | Explicit status monitors and toggle controls for Microphone, Speech Recognition, Camera, and Screen Recording permissions. |
| 🎮 **Mini Games** | Play Rock Paper Scissors or test your knowledge with interactive trivia questions. |
| 📌 **Always-on-Top & Companion Mode** | Floats on top of all spaces and fullscreen apps; optional click-through companion mode. |

---

## 🛠 Project Structure

```text
ollama-pet/
├── OllamaPetNative/               # Native macOS Swift codebase
│   ├── Package.swift              # SPM package definition
│   └── Sources/OllamaPet/
│       ├── AppDelegate.swift      # Menu bar status item, hotkey & app lifecycle
│       ├── ChatView.swift         # Multi-tab SwiftUI drawer (Chat, Focus, Settings, etc.)
│       ├── DataManager.swift      # Persistent storage & UNUserNotificationCenter alerts
│       ├── FocusGuardian.swift    # Pomodoro session coordinator & hydration alerts
│       ├── Models.swift           # Characters, moods, chat, preferences & shortcut data types
│       ├── MusicManager.swift     # AVFoundation audio player & audio metering
│       ├── OllamaClient.swift     # URLSession client for localhost:11434 (tags, chat, retry)
│       ├── PetArtwork.swift       # SVG vector rendering & gait kinematics for all 7 species
│       ├── PetStageView.swift     # Transparent interactive pet stage & status bubbles
│       ├── PetState.swift         # Animation, mood, Pomodoro, and game state machine
│       ├── PetWindowController.swift # NSPanel with exact-offset dragging & snapping
│       ├── ScreenGuardian.swift   # Privacy-first frontmost app context analyzer
│       ├── ShortcutManager.swift  # Global keyboard event monitors & conflict resolver
│       ├── SoundEffects.swift     # AudioToolbox sound effects
│       ├── SystemMonitor.swift    # Mach host processor stats, IOKit power & NSWorkspace
│       ├── VisionGuardian.swift   # Camera awareness & Apple Vision human detection
│       ├── VoiceAssistant.swift   # Push-to-talk STT & TTS speech synthesizer
│       ├── WalkerManager.swift    # Dynamic bottom-screen walk panel animation
│       ├── WeatherService.swift   # URLSession weather service via Open-Meteo
│       └── main.swift             # Native app entry point
├── build-native.sh                # Automated build & packaging script for Native macOS .app
├── icon.icns                      # High-resolution macOS app icon bundle
├── icon.png                       # App icon asset
├── banner.png                     # Project banner asset
├── LICENSE                        # Project license
├── .gitignore                     # Git ignore rules for native builds
└── README.md                      # Documentation
```

---

## 🚀 Building & Running

### 1. Requirements

- **macOS**: macOS 13.0 or later (Apple Silicon or Intel).
- **Xcode Command Line Tools**: `xcode-select --install`
- **Ollama**: Download from [ollama.ai](https://ollama.ai) and pull any model:
  ```bash
  ollama pull llama3.2
  # or
  ollama pull phi3
  ```

---

### 2. Install to Applications (Recommended)

To build and automatically install directly into your macOS `/Applications` folder:

```bash
chmod +x install.sh
./install.sh
```

This compiles the release binary and copies `OllamaPet.app` directly into `/Applications`, making it instantly searchable in Spotlight and Launchpad.

---

### 3. Alternative: Build & Run Locally

To compile and run directly from the workspace folder:

```bash
chmod +x build-native.sh
./build-native.sh
open dist-native/OllamaPet.app
```

> **Note**: Whenever you launch Ollama Pet outside your Applications folder (e.g. from Downloads or this repository), the app will automatically prompt:
> *"Move to Applications Folder?"*
> You can also click the status bar icon (`🐾`) at any time and choose **"📥 Move to Applications Folder..."**.

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
