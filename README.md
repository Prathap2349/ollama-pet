# 🐾 Ollama Pet

<p align="center">
  <img src="assets/banner.png" alt="Ollama Pet Banner" width="100%">
</p>

<p align="center">
  <strong>A native macOS AI desktop companion with local Ollama AI, animated characters, reminders, focus tools, Mac control, and privacy-first presence monitoring.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Language-Swift%205.9%20%2F%20SwiftUI-red?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/AI-Ollama%20(Local--First)-emerald" alt="Ollama">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License">
</p>

<p align="center">
  <a href="https://github.com/Prathap2349/ollama-pet/releases/latest">
    <img src="https://img.shields.io/badge/📥_Download_for_macOS-OllamaPet--macOS.zip-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Download Ollama Pet for macOS">
  </a>
</p>

---

## ✨ Overview

**Ollama Pet** is a native macOS application built with Swift, SwiftUI, and AppKit. It lives on your desktop as an interactive animated virtual companion powered by your local Ollama large language models. 

Unlike web wrappers or heavy electron apps, Ollama Pet is engineered specifically for macOS: ultra-lightweight, hardware-accelerated, power-efficient, and deeply respectful of your privacy.

---

## 🌟 Key Features

### 🧠 Local Ollama AI (Default)
* **Local-First Inference**: Connects directly to your local Ollama instance (`http://127.0.0.1:11434`).
* **Real-Time Token Streaming**: Text streams seamlessly into the chat interface with low latency.
* **Auto-Model Discovery**: Automatically detects installed models (`llama3`, `mistral`, `qwen`, `gemma`, `phi3`, etc.) with quick switching in Settings.
* **Typing Indicator**: Smooth, staggered 3-dot typing bubble that fades cleanly when streaming begins.

### ☁️ Optional Cloud AI Providers
* **Multi-Provider Support**: Optionally configure OpenAI, Google Gemini, or Anthropic Claude models alongside local Ollama.
* **Hardware Keychain Security**: API keys are securely stored directly in your macOS Keychain—never plaintext in dotfiles or preferences.
* **Zero Telemetry**: No user prompts or chat transcripts are logged to any third-party analytics servers.

### 🎭 Distinct Character Mascots & Silhouettes
* **5 Unique Species**:
  * **BOO (Ghost)**: Floating spectral companion with a curious sideways drift, liquid hemline, and expressive blue-cyan eyes.
  * **KIKI (Cat)**: Playful feline with twitching ears, curious head tilts, and kawaii expressions.
  * **POCHI (Bunny)**: Energetic rabbit with tall upright ears and bouncy step kinematics.
  * **DORA (Robot Cat)**: Digital cyber companion with LED visor expressions and futuristic sounds.
  * **KAI (Reptile)**: Calm draconian beast with vertical slit pupils and gentle breathing cycles.
* **Developer Grayscale Test Mode**: Verify anatomical silhouettes in high-contrast monochrome to confirm distinctive geometry without relying on color cues.

### 🏃 Character Animation & Kinematics
* **Organic Movement Physics**: Natural idle bobbing, breathing oscillation, and reactive squish/stretch on click or drag.
* **Walking Across Screen**: Companions can walk across your desktop workspace with selectable gait presets (*Bouncy March*, *Stealth Prowl*, *Hover Glide*).
* **Safe Mode Guard**: Automatic throttling to 15 FPS with all shaders disabled if battery or thermal load spikes.

### 🎙️ Voice Assistant
* **Push-to-Talk Speech Recognition**: High-accuracy local speech-to-text powered natively by Apple's Speech and AVFoundation frameworks.
* **Natural Voice Synthesis**: Speaks responses using macOS system voices with adjustable pitch and rate.

### 🧭 Safe Mac Control & Action Assistant
* **Strict Security Action Pipeline**: Natural language intent parsing for common Mac tasks without arbitrary shell execution:
  * Application management (open Safari, Finder, Terminal, Notes, etc.)
  * Volume & brightness adjustments
  * Direct web searches (Google, GitHub, Wikipedia, YouTube)
  * System telemetry checks (battery, uptime, CPU status)
* **Action History**: Local transparent audit log showing timestamps, intent, parameters, and execution outcomes.

### 👁️ Native Presence Monitor
* **Apple Vision Human Detection**: Detects human body rectangles locally with zero cloud streaming.
* **Enhanced Proximity & IoU Tracking**: Combines spatial IoU and center-distance matching with missed-frame tolerance to prevent jumping or flickering.
* **Separated Detection & Preview**: Detection runs silently in the background at an adaptive rate. Live video preview rendering is completely disabled unless you explicitly expand the camera view or open Settings.
* **Adaptive Sampling Modes**:
  * **Low Power**: 2.0s analysis intervals with maximum thermal throttling.
  * **Balanced** *(Default)*: 0.8–1.2s adaptive analysis (relaxes to 2.2s when owner is verified).
  * **Responsive**: 0.4–0.6s rapid presence reaction.
* **Optional Local Owner Recognition**:
  * Enroll your face locally using Apple Vision feature prints.
  * Distinguishes between verified Owner, Unverified Guests, and Obscured faces.
  * *Note: Owner recognition is designed for companion personalization and desktop convenience—it is not security-grade biometric authentication.*
* **Event-Based Local Security Snapshots**:
  * **Disabled by default**.
  * When enabled, captures 1 discrete snapshot per unfamiliar encounter (> 5s dwell) with a 60-second cooldown.
  * Strictly local storage (`~/Library/Application Support/OllamaPet/Snapshots`), capped at 20 images maximum (oldest pruned automatically).
* **Internal Self-Healing Watchdog**: Automatically detects camera stalls and recovers the session without terminal commands or system freezes.

### ⏱️ Focus Guardian & Healthy Habits
* **Pomodoro Focus Timer**: Custom work intervals and break durations with discrete notification chimes.
* **Hydration & Posture Nudges**: Gentle periodic companion alerts encouraging healthy desk habits.
* **Eye Rest Reminders**: Screen awareness cues reminding you to take 20-20-20 breaks.

### 🌦️ Weather & Music
* **Live Weather Dashboard**: Queries current temperature, conditions, and humidity for your city.
* **Atmospheric Visuals**: Optional real-time weather particle overlays (raindrops, flurries, golden hour aura).
* **Local Music Player**: Play local MP3/audio files with synced companion dance animations.

---

## 🏗️ Architecture

```text
┌────────────────────────────────────────────────────────┐
│                      Ollama Pet                        │
│                (Native macOS Application)              │
└───────────┬────────────────────────────────┬───────────┘
            │                                │
    ┌───────▼────────┐               ┌───────▼────────┐
    │ Companion Core │               │   AI Engine    │
    ├────────────────┤               ├────────────────┤
    │ PetStageView   │               │ OllamaClient   │
    │ CanvasRenderer │               │ AIProviderMgr  │
    │ MotionStateMachine             │ APIKeyManager  │
    │ WalkerManager  │               │ (Keychain)     │
    └───────┬────────┘               └───────┬────────┘
            │                                │
    ┌───────▼────────────────────────────────▼────────┐
    │            Hardware & OS Integration            │
    ├─────────────────────────────────────────────────┤
    │ AVFoundation (Camera & Audio Capture)           │
    │ Apple Vision (Human & Face Analysis)            │
    │ Apple Speech & NSSpeechSynthesizer              │
    │ AppKit Floating Windows (NSPanel)               │
    │ CoreImage & Metal Graphics Acceleration         │
    └─────────────────────────────────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites
* **macOS 13.0 (Ventura)** or later (Apple Silicon M1/M2/M3/M4 recommended)
* [Ollama](https://ollama.com) installed and running:
  ```bash
  ollama serve
  ollama pull llama3:latest
  ```

### 📦 Quick Install (Pre-built Release)

1. **Download** `OllamaPet-macOS.zip` from [Releases](https://github.com/Prathap2349/ollama-pet/releases/latest).
2. **Unzip** the archive to reveal `OllamaPet.app`.
3. **Drag** `OllamaPet.app` into your macOS `/Applications` folder.
4. **Launch** the app:
   * Double-click `OllamaPet.app` in `/Applications`.
   * *Note: Because Ollama Pet uses ad-hoc signing for open-source builds, if macOS displays a warning on first launch, simply right-click `OllamaPet.app` and select **Open**, or run:*
     ```bash
     xattr -cr /Applications/OllamaPet.app
     ```

### 🛠️ Build & Install from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Prathap2349/ollama-pet.git
   cd ollama-pet
   ```

2. **Build the native application**:
   ```bash
   ./build-native.sh
   ```
   *This compiles an arm64 release binary, code-signs the `.app` bundle ad-hoc, and packages `dist-release/OllamaPet-macOS.zip`.*

3. **Install to `/Applications`**:
   ```bash
   ./install.sh
   ```
   *Safely installs `OllamaPet.app` to your Applications folder and launches it.*

---

## 🔒 Privacy & Permissions

* **100% On-Device Processing**: Ollama Pet never transmits camera frames, speech audio, or companion interactions to external cloud servers unless you explicitly configure a Cloud AI API key.
* **Explicit Microphone Access**: Used solely when you click and hold the Push-to-Talk button.
* **Explicit Camera Access**: Used solely for the local Presence Monitor. Can be disabled or paused at any time from the status bar or widget.
* **Local Keychain Storage**: Cloud API credentials remain encrypted within the macOS Keychain.

---

## 📝 Changelog & Recent Fixes

### Presence Monitor Live Preview Request Ownership Fix
* **Issue Addressed**: Fixed camera preview image becoming blank/hidden when multiple UI components were open simultaneously (e.g., Settings Presence tab, Owner Calibration Wizard, and Floating Presence Widget). Previously, closing any single component set a shared `isLivePreviewRequested` boolean to `false`, cutting off live video preview frames for remaining active screens even though face detection continued working.
* **Architecture Fix**: Upgraded `PresenceMonitor` to use reference-counted, consumer-keyed request/release ownership (`requestLivePreview(id:)`, `releaseLivePreview(id:)`, `resetLivePreviewRequests()`). Live camera preview frames now remain active as long as at least one UI consumer holds an active request, and cleanly spin down when all requests are released.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
