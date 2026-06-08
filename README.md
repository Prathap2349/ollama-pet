# 🐾 Ollama Pet

A local AI desktop companion that lives on your screen — powered entirely by [Ollama](https://ollama.com) running on your own machine. No cloud, no API keys, no subscriptions. Just chat with your pet, make it dance to your music, set reminders, and watch it roam your desktop.

![Electron](https://img.shields.io/badge/Electron-42-blue?logo=electron) ![Ollama](https://img.shields.io/badge/Ollama-local-green) ![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

---

## ✨ Features

| Feature | Description |
|---|---|
| 💬 **AI Chat** | Talk to your pet using any Ollama model (llama3, mistral, gemma, etc.) |
| 🎭 **4 Characters** | Choose from Cat 🐱, Dragon 🐉, Robot 🤖, or Robot Cat 🐱‍💻 — each with unique animations |
| 💃 **Dance Mode** | Pet dances with animated beat bars. Upload any MP3 for real-time beat detection |
| 🎵 **Music Vibes** | Pop / Rock / Chill / Rave modes that change the dance energy and speed |
| ⏰ **Reminders** | Set timed reminders ("in 10 mins", "at 3:30") — pet dances and notifies you when due |
| 📊 **Stats Panel** | Tracks chats today, uptime, and CPU usage |
| 🚶 **Desktop Walker** | Pet walks across the bottom of your entire screen |
| 🎉 **Reactions** | Confetti + particles when excited, sleeping, shocked, and more |
| 📄 **Export Chat** | Save your conversation to a `.txt` file |
| 🎙️ **Voice Input** | Speak to your pet via the mic button (browser Speech API) |
| ⌨️ **Global Shortcut** | `Cmd+Shift+P` (Mac) / `Ctrl+Shift+P` (Windows/Linux) to show/hide the pet |
| 📌 **Always on Top** | Floats over all windows and works on every desktop/space |
| 💾 **Persistent Data** | Chats, reminders, and stats are saved between sessions |

---

## 🖥️ Requirements

- **macOS** 12+, **Windows** 10+, or **Linux** (Ubuntu 20.04+)
- **Node.js** v18 or later → [nodejs.org](https://nodejs.org)
- **Git** → [git-scm.com](https://git-scm.com)
- **Ollama** (see install guide below)

---

## 🦙 Step 1 — Install Ollama (from scratch)

### macOS
```bash
# Option A — Download the app (easiest)
# Go to https://ollama.com/download and click "Download for Mac"
# Open the .dmg and drag Ollama to Applications, then launch it.

# Option B — Homebrew
brew install ollama
```

### Windows
Go to [https://ollama.com/download](https://ollama.com/download) and click **Download for Windows**.  
Run the `.exe` installer and follow the prompts.

### Linux
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

---

## 🤖 Step 2 — Download an AI Model

After installing Ollama, pull a model. We recommend starting with **llama3.2** (small and fast):

```bash
ollama pull llama3.2
```

Other good options:

```bash
ollama pull mistral        # Great all-rounder, ~4 GB
ollama pull gemma3         # Google's model, fast
ollama pull phi4-mini      # Very small, runs on low RAM
ollama pull llama3.1:8b    # More capable, ~5 GB
```

> 💡 You only need to pull a model once. List your downloaded models with `ollama list`.

---

## 📦 Step 3 — Install & Run Ollama Pet

### Clone the repo
```bash
git clone https://github.com/Prathap2349/ollama-pet.git
cd ollama-pet
```

### Install dependencies
```bash
npm install
npm install concurrently --save-dev
```

### Start the app
```bash
npm run dev:safe
```

This command starts Ollama in the background and launches the Electron pet window.

> ⚠️ Make sure Ollama is installed and at least one model is downloaded before running.

---

## 🎮 How to Use

### Choosing your pet
Click the character buttons at the bottom of the window:
`🐱 Cat` · `🐉 Dragon` · `🤖 Robot` · `🐱‍💻 Robot Cat`

### Chatting
1. Click the **💬 Chat** tab
2. Type your message and press **Enter** or click Send
3. Your pet thinks, then replies using your local Ollama model
4. Click **📄 Export** to save the conversation

### Dancing to music
1. Click the **💃 Dance** tab
2. Pick a vibe: **Pop / Rock / Chill / Rave**
3. Click **🎧 Upload song** and select any MP3 file
4. The beat bars and pet animation sync to the real bass energy of the track

### Setting a reminder
1. Click the **⏰ Remind** tab
2. Type something like:
   - `"Take a break in 10 mins"`
   - `"Stand up in 1 hour"`
   - `"Meeting at 3:30"`
3. Press **Enter** or click **＋**
4. When time is up, the pet dances and a system notification fires
5. Click **✕** on any reminder to delete it

### Other controls
| Action | How |
|---|---|
| Show / hide pet | `Cmd+Shift+P` (Mac) · `Ctrl+Shift+P` (Win/Linux) |
| Move the window | Drag the pet |
| Snap to corner | Double-click the pet |
| Send pet for a walk | Stats tab → 🚶 Walk button |
| Voice input | Mic 🎙️ button in the chat bar |

---

## 🗂️ Project Structure

```
ollama-pet/
├── index.html   # All UI, animations, and frontend logic
├── main.js      # Electron main process (windows, IPC, shortcuts)
├── walker.html  # Fullscreen walker overlay window
└── package.json
```

---

## 🛠️ Troubleshooting

**Pet window doesn't appear**  
→ Check that Electron launched without errors in your terminal.

**"Could not connect to Ollama"**  
→ Run `ollama serve` manually in a separate terminal, then try again.

**Music uploads but doesn't play**  
→ If you see a ▶ Play button appear, click it once to unblock browser autoplay. This only happens the first time.

**No models available in chat**  
→ Run `ollama list` to confirm a model is downloaded. Pull one with `ollama pull llama3.2`.

**App is slow / responses take a long time**  
→ Try a smaller model like `phi4-mini` or `gemma3:1b`.

---

## 📄 License

MIT — free to use, modify, and share.

---

> Made with ☕ and way too many late nights. Your pet lives entirely on your machine — private, offline, and always home.
