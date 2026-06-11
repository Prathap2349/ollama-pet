# 🐾 Ollama Pet

A local AI desktop companion that lives on your screen — powered entirely by [Ollama](https://ollama.ai) running on your own machine. No cloud, no API keys, no subscriptions. Just chat with your pet, make it dance to your music, set reminders, check the weather, track your habits, and more.

---

## 📸 What It Looks Like

A small animated pet (cat, dog, fox, or robot) sits in the bottom-right corner of your screen. Click it to open the chat panel. It stays on top of all your windows, across all your desktops, even over fullscreen apps.

---

## ✨ Features

| Feature | What it does |
|---|---|
| 💬 **AI Chat** | Talk to your pet using Ollama (local LLM — fully offline) |
| 🎵 **Music & Dance** | Upload an MP3 — the pet dances to the actual beat |
| 🌤 **Live Weather** | Enter your city, get real-time weather via Open-Meteo (free, no key) |
| ⏰ **Reminders** | Set a reminder — pet notifies you with a bubble and system notification |
| 🍅 **Pomodoro Timer** | 25-min work / 5-min break timer built in |
| 📊 **System Stats** | Live CPU, RAM, battery, uptime, active apps |
| 🎮 **Mini Games** | Rock Paper Scissors and trivia games |
| 🏆 **Streak & XP** | Daily chat streak, mood tracking, hunger system |
| 🖥 **Companion Mode** | Pet goes transparent/click-through when you're working |
| 🌙 **Day/Night Skin** | Automatically changes appearance based on time of day |
| 🎨 **4 Characters** | Cat 🐱, Dog 🐶, Fox 🦊, Robot 🤖 — switch anytime |
| 🚶 **Walk Mode** | Pet walks across your screen |
| 🌈 **Wallpaper Mode** | Pet reacts to your desktop wallpaper colours |

---

## 🖥 System Requirements

| Requirement | Details |
|---|---|
| **macOS** | 12 Monterey or later (Apple Silicon M1/M2/M3 or Intel) |
| **Node.js** | v20 or later — [download here](https://nodejs.org) |
| **Ollama** | Required for AI chat — [download here](https://ollama.ai) |
| **RAM** | 8GB minimum, 16GB recommended (for running a local LLM) |
| **Storage** | ~500MB for the app + whichever Ollama model you use |

> ⚠️ **Windows/Linux:** The app runs but some features (battery, brightness, system stats) are macOS-only.

---

## 🚀 Installation — Two Ways

### Option A — Run from Source (for developers)

**Step 1: Install Node.js**
Download from [nodejs.org](https://nodejs.org) and install. Check it works:
```bash
node --version   # should say v20.x.x or higher
```

**Step 2: Install Ollama**
Download from [ollama.ai](https://ollama.ai) and install. Then pull a model:
```bash
ollama pull llama3.2
# or for a smaller/faster model:
ollama pull phi3
```

**Step 3: Clone and run**
```bash
git clone https://github.com/Prathap2349/ollama-pet.git
cd ollama-pet
npm install
npm start
```

The pet appears in the bottom-right corner of your screen. ✅

---

### Option B — Build a real .app (recommended — no terminal needed after this)

**Step 1:** Follow steps 1 and 2 above to install Node.js and Ollama.

**Step 2:** Clone and build:
```bash
git clone https://github.com/Prathap2349/ollama-pet.git
cd ollama-pet
npm install
chmod +x build-app.sh && ./build-app.sh
```

**Step 3:** Copy to Applications:
- Open Finder → go to `ollama-pet/dist/OllamaPet-darwin-arm64/`
- Drag `OllamaPet.app` into your `/Applications` folder

**Step 4:** First launch:
- **Right-click** `OllamaPet.app` → click **Open**
- Click **Open** on the security popup (only needed once)

**From now on:** The pet starts automatically every time you log into your Mac. No terminal needed ever again.

---

## 🎮 How to Use

### Basic Controls

| Action | How |
|---|---|
| **Open chat** | Click the pet |
| **Close chat** | Click ✕ or click the pet again |
| **Move the pet** | Drag it anywhere on screen |
| **Snap to corner** | Drag near a corner — it snaps automatically |
| **Hide/show pet** | Press `Cmd+Shift+P` |
| **Quit** | Click ✕ in the top-right of the chat panel |

### Chat Panel Tabs

Once you click the pet, the chat panel opens with tabs at the top:

- **💬 Chat** — Talk to the AI pet
- **🎵 Music** — Upload an MP3 to make it dance, choose a vibe (pop/rock/chill)
- **🌤 System** — Weather, clock, system stats, battery
- **⏰ Timer** — Pomodoro timer + reminders
- **🎮 Games** — Rock Paper Scissors, trivia

### Setting Up AI Chat

1. Make sure Ollama is running: open Terminal and type `ollama serve`
2. The pet shows a green dot 🟢 when connected, red 🔴 when offline
3. If red, click the ↻ retry button in the chat panel

### Weather Setup

1. Open the chat panel → click the **System** tab
2. Type your city name in the weather box (e.g. `Chennai` or `London`)
3. Press Enter or click the fetch button
4. It remembers your city next time

### Music & Dancing

1. Open the chat panel → click the **Music** tab
2. Click **🎧 Upload song** → select any MP3/WAV/M4A file
3. The pet starts dancing to the actual beat of your music
4. Choose a vibe: Pop 🎵 / Rock 🤘 / Chill 😌

### Reminders

1. Open the chat panel → click the **Timer** tab
2. Type what you want to be reminded of
3. Set the minutes
4. Click **+** — the pet will bubble-notify you when time is up

### Companion Mode

Turn on companion mode in the System tab — the pet becomes click-through after 1 minute of inactivity so it doesn't get in the way while you work. Any click on the panel wakes it back up.

---

## 🛑 How to Stop / Remove

**Stop auto-start:**
System Settings → General → Login Items → find OllamaPet → click **−** to remove

**Quit the app:**
Click the pet → click ✕ (close button) in the chat panel

**Completely delete:**
1. Drag `OllamaPet.app` from `/Applications` to Trash
2. Delete the `ollama-pet` folder from Downloads
3. Delete saved data (optional): `rm ~/ollama-pet-data.json`

Done. Nothing else left behind.

---

## 🔧 Troubleshooting

**Pet doesn't appear after launching**
- Check you're running macOS 12+
- Try right-click → Open instead of double-click (security warning)
- Check System Settings → Privacy & Security and allow the app

**AI chat not working (red dot)**
- Make sure Ollama is installed and running: `ollama serve` in Terminal
- Make sure you've pulled a model: `ollama pull llama3.2`
- Click the ↻ retry button in the chat panel

**"Unidentified developer" warning**
- Right-click the app → Open → click Open on the popup
- Only needed once

**App won't open after build**
- Make sure you're on Apple Silicon (M1/M2/M3) — if Intel Mac, the build script auto-detects it
- Try: `xattr -cr /Applications/OllamaPet.app` in Terminal then open again

**Node.js version warning during build**
- The warnings about Node v20 vs v22 are harmless — the app builds and runs fine on v20

---

## 🏗 Project Structure

```
ollama-pet/
├── index.html       # entire frontend — UI, animations, all features
├── main.js          # Electron main process — window management, IPC, system APIs
├── walker.html      # walk-across-screen animation window
├── package.json     # dependencies and build scripts
├── build-app.sh     # one-click .app builder script
└── LICENSE          # MIT
```

---

## 🤖 Models That Work Well

| Model | Size | Speed | Best for |
|---|---|---|---|
| `llama3.2` | 2GB | Fast | General chat |
| `phi3` | 2.3GB | Very fast | Quick responses |
| `mistral` | 4GB | Medium | Better reasoning |
| `llama3.1:8b` | 4.7GB | Medium | More capable |

Pull any model with: `ollama pull <model-name>`

The pet uses whichever model is default in Ollama. To set a specific model, change the model name in `index.html` (search for `"model":` in the fetch call to Ollama).

---

## 📝 License

MIT — free to use, modify, and share.

---

## 👤 Author

**Prathap** — [@Prathap2349](https://github.com/Prathap2349)

Built with ❤️ using Electron + Ollama.
