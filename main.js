const { app, BrowserWindow, ipcMain, screen, Notification, globalShortcut, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync, spawn } = require('child_process');

let win;
let walkerWin;
let petVisible = true;
let ollamaProcess = null;

const SAVE_PATH = path.join(os.homedir(), 'ollama-pet-data.json');

// ── AUTO-START OLLAMA ─────────────────────────
function startOllama() {
  // Full path needed — .app bundles have a restricted PATH
  const ollamaPath = '/usr/local/bin/ollama';
  try {
    execSync('curl -s http://localhost:11434/api/tags', { timeout: 1000 });
    console.log('Ollama already running ✓');
  } catch(_) {
    try {
      ollamaProcess = spawn(ollamaPath, ['serve'], {
        detached: true,
        stdio: 'ignore',
        env: { ...process.env, PATH: '/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin' },
      });
      ollamaProcess.unref();
      console.log('Ollama started automatically ✓');
    } catch(err) {
      console.warn('Could not start Ollama:', err.message);
    }
  }
}

startOllama();

// ── SINGLE INSTANCE LOCK ─────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) win.showInactive();
  });
}

app.whenReady().then(() => {
  // Auto-start at login (macOS) — starts hidden, no dock bounce
  if (process.platform === 'darwin') {
    app.setLoginItemSettings({ openAtLogin: true, openAsHidden: true });
    app.dock.hide(); // floating pet, not a dock app
  }

  const { width, height } = screen.getPrimaryDisplay().workAreaSize;

  // Main pet window
  win = new BrowserWindow({
    width: 130,
    height: 145,
    x: width - 140,
    y: height - 155,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      webSecurity: false,
      autoplayPolicy: 'no-user-gesture-required',
    },
  });

  win.loadFile('index.html');

  // Mac: 'floating' level + visibleOnFullScreen so it shows over other apps and spaces
  if (process.platform === 'darwin') {
    win.setAlwaysOnTop(true, 'floating', 1);
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  } else {
    win.setAlwaysOnTop(true, 'screen-saver');
    win.setVisibleOnAllWorkspaces(true);
  }

  // Global shortcut — Cmd+H on Mac, Ctrl+H on Windows/Linux
  const shortcut = process.platform === 'darwin' ? 'Command+Shift+P' : 'Ctrl+Shift+P';
  globalShortcut.register(shortcut, () => {
    petVisible = !petVisible;
    if (petVisible) {
      win.showInactive();
      win.webContents.send('pet-visibility', true);
    } else {
      win.webContents.send('pet-visibility', false);
      setTimeout(() => win.hide(), 200); // let fade animation play
    }
  });

  // Walker window
  walkerWin = new BrowserWindow({
    width: width,
    height: 120,
    x: 0,
    y: height - 120,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    focusable: false,
    hasShadow: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });
  walkerWin.loadFile('walker.html');
  walkerWin.setIgnoreMouseEvents(true);
  if (process.platform === 'darwin') {
    walkerWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  } else {
    walkerWin.setVisibleOnAllWorkspaces(true);
  }
});

app.on('will-quit', () => globalShortcut.unregisterAll());

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ── IPC ────────────────────────────────────────────────────────
ipcMain.on('close-app', () => app.quit());

ipcMain.on('set-size', (e, { open }) => {
  if (!win || win.isDestroyed()) return;
  // Anchor resize to the display the window is on, not always the primary
  const display = screen.getDisplayMatching(win.getBounds());
  const { width, height } = display.workArea;
  // When open: 340w fits the 320px chatbox. Height = chatbox(450) + pet(130) + gap(30) = 620
  // When closed: just the pet 130x145
  const newW = open ? 340 : 130;
  const newH = open ? 640 : 145;
  // Always anchor window to bottom-right so pet stays in corner
  const newX = width  - newW - 10;
  const newY = height - newH - 10;
  win.setSize(newW, newH);
  win.setPosition(newX, newY);
});

ipcMain.on('move-win', (e, { x, y }) => {
  win.setPosition(Math.round(x), Math.round(y));
});

ipcMain.on('snap-corner', () => {
  if (!win || win.isDestroyed()) return;
  // Use the display the window is currently on, not always the primary
  const display = screen.getDisplayMatching(win.getBounds());
  const { width, height } = display.workAreaSize;
  const [cx, cy] = win.getPosition();
  const [cw, ch] = win.getSize();
  // Snap to nearest corner with a small margin
  const snapX = cx + cw/2 < display.workArea.x + width  / 2 ? 10 : display.workArea.x + width  - cw - 10;
  const snapY = cy + ch/2 < display.workArea.y + height / 2 ? 10 : display.workArea.y + height - ch - 10;
  win.setPosition(snapX, snapY);
  // Reply so renderer can persist the new position
  win.webContents.send('position-reply', { x: snapX, y: snapY });
});

ipcMain.on('notify', (e, { title, body }) => {
  if (Notification.isSupported()) {
    new Notification({ title, body, silent: true }).show();
  }
});

ipcMain.on('save-data', (e, data) => {
  try { fs.writeFileSync(SAVE_PATH, JSON.stringify(data, null, 2)); } catch(_) {}
});

ipcMain.on('load-data', (e) => {
  try {
    if (fs.existsSync(SAVE_PATH)) {
      const d = JSON.parse(fs.readFileSync(SAVE_PATH, 'utf8'));
      win.webContents.send('data-loaded', d);
    }
  } catch(_) {}
});

ipcMain.on('export-chat', async (e, text) => {
  const defaultName = `ollama-chat-${new Date().toISOString().slice(0,10)}.txt`;
  const { canceled, filePath } = await dialog.showSaveDialog(win, {
    title: 'Export Chat',
    defaultPath: path.join(os.homedir(), defaultName),
    filters: [{ name: 'Text Files', extensions: ['txt'] }]
  });
  if (canceled || !filePath) return;
  try { fs.writeFileSync(filePath, text); win.webContents.send('export-done', filePath); } catch(_) {}
});

ipcMain.on('walk-char', (e, svgContent) => {
  if (walkerWin && !walkerWin.isDestroyed()) {
    walkerWin.webContents.send('start-walk', svgContent);
  }
});

ipcMain.on('get-position', (e) => {
  if (win && !win.isDestroyed()) {
    const [x, y] = win.getPosition();
    e.reply('position-reply', { x, y });
  }
});

ipcMain.on('set-ignore-mouse', (e, flag) => {
  if (win && !win.isDestroyed()) win.setIgnoreMouseEvents(flag, { forward: true });
});

ipcMain.on('open-music-dialog', async () => {
  const { canceled, filePaths } = await dialog.showOpenDialog(win, {
    title: 'Select Music File',
    properties: ['openFile'],
    filters: [{ name: 'Audio', extensions: ['mp3','wav','ogg','flac','m4a','aac'] }]
  });
  if (canceled || !filePaths.length) return;
  const fp = filePaths[0];
  const fileName = require('path').basename(fp);
  win.webContents.send('music-file-selected', { filePath: fp, fileName });
});


ipcMain.on('get-system-status', (e) => {
  try {
    const platform = process.platform;
    const totalMem = os.totalmem();
    const freeMem  = os.freemem();
    const usedMem  = totalMem - freeMem;
    const memPct   = Math.round(usedMem / totalMem * 100);

    let battery = null;
    if (platform === 'darwin') {
      try {
        const raw = execSync('pmset -g batt', { timeout: 1500 }).toString();
        const pct = raw.match(/(\d+)%/);
        const charging = raw.includes('AC Power') || raw.includes('charging');
        if (pct) battery = { level: parseInt(pct[1]), charging };
      } catch(_) {}
    }

    const cpus = os.cpus();
    const model = cpus[0]?.model || 'Unknown CPU';
    const cores = cpus.length;
    const uptimeSec = os.uptime();
    const uptimeH = Math.floor(uptimeSec / 3600);
    const uptimeM = Math.floor((uptimeSec % 3600) / 60);

    // Get top process on Mac
    let topProc = null;
    if (platform === 'darwin') {
      try {
        const raw = execSync('ps -Ao comm,pcpu -r | head -3', { timeout: 1500 }).toString().trim().split('\n');
        topProc = raw.slice(1).map(l => l.trim()).filter(Boolean)[0] || null;
      } catch(_) {}
    }

    win.webContents.send('system-status', {
      platform,
      totalMemGB: (totalMem / 1073741824).toFixed(1),
      usedMemGB:  (usedMem  / 1073741824).toFixed(1),
      memPct,
      battery,
      cpuModel: model.replace(/\s+/g,' ').trim(),
      cores,
      uptime: `${uptimeH}h ${uptimeM}m`,
      topProc,
      hostname: os.hostname(),
    });
  } catch(err) {
    // Fallback: send basic info even if shell commands fail (e.g. desktop Mac, no battery)
    try {
      win.webContents.send('system-status', {
        platform: process.platform,
        hostname: os.hostname(),
        cpuModel: (os.cpus()[0]?.model || 'Unknown CPU').replace(/\s+/g,' ').trim(),
        cores: os.cpus().length,
        totalMemGB: (os.totalmem()/1073741824).toFixed(1),
        usedMemGB:  ((os.totalmem()-os.freemem())/1073741824).toFixed(1),
        memPct: Math.round((os.totalmem()-os.freemem())/os.totalmem()*100),
        uptime: `${Math.floor(os.uptime()/3600)}h ${Math.floor((os.uptime()%3600)/60)}m`,
        battery: null,
        topProc: '—'
      });
    } catch(_) {}
  }
});


setInterval(() => {
  try {
    if (win && !win.isDestroyed()) {
      const cpuUsage = process.cpuUsage();
      win.webContents.send('cpu-update', Math.min(100, Math.round(cpuUsage.user / 10000)));
    }
  } catch(_) {}
}, 5000);

// ── IDLE TIME ──────────────────────────────────
const { powerMonitor } = require('electron');
setInterval(() => {
  try {
    if (win && !win.isDestroyed()) {
      const idleSecs = powerMonitor.getSystemIdleTime();
      win.webContents.send('idle-update', idleSecs);
    }
  } catch(_) {}
}, 10000);

// ── DARK/LIGHT MODE ───────────────────────────
const { nativeTheme } = require('electron');
function sendTheme() {
  try {
    if (win && !win.isDestroyed()) {
      win.webContents.send('theme-update', nativeTheme.shouldUseDarkColors ? 'dark' : 'light');
    }
  } catch(_) {}
}
nativeTheme.on('updated', sendTheme);
app.whenReady().then(() => setTimeout(sendTheme, 1500));

// ── ACTIVE APPS (extended) ─────────────────────
ipcMain.on('get-active-apps', (e) => {
  try {
    const platform = process.platform;
    let apps = [];
    if (platform === 'darwin') {
      const raw = execSync("ps -Ao comm -r | head -20", { timeout: 2000 }).toString().trim().split('\n');
      apps = [...new Set(raw.map(l => l.trim().split('/').pop()).filter(Boolean))].slice(0, 10);
    } else if (platform === 'linux') {
      const raw = execSync("ps -Ao comm --sort=-%cpu | head -15", { timeout: 2000 }).toString().trim().split('\n');
      apps = [...new Set(raw.map(l => l.trim()).filter(Boolean))].slice(0, 10);
    } else {
      apps = ['explorer', 'chrome', 'code'];
    }
    win.webContents.send('active-apps', apps);
  } catch(_) {
    win.webContents.send('active-apps', []);
  }
});

// ── SCREEN BRIGHTNESS (macOS) ─────────────────
ipcMain.on('get-brightness', (e) => {
  try {
    if (process.platform === 'darwin') {
      const raw = execSync("brightness -l 2>/dev/null | grep 'display 0' | awk '{print $NF}'", { timeout: 1500 }).toString().trim();
      const val = parseFloat(raw);
      win.webContents.send('brightness-update', isNaN(val) ? -1 : Math.round(val * 100));
    } else {
      win.webContents.send('brightness-update', -1);
    }
  } catch(_) { win.webContents.send('brightness-update', -1); }
});

// ── TYPING SPEED ─────────────────────────────
ipcMain.on('typing-speed', (e, wpm) => {
  // just relay back; renderer handles reaction
  win.webContents.send('typing-speed-reaction', wpm);
});
