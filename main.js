const { app, BrowserWindow, ipcMain, screen, Notification, globalShortcut, dialog, powerMonitor, nativeTheme } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const http = require('http');
const { execSync, spawn } = require('child_process');

let win = null;
let walkerWin = null;
let petVisible = true;
let ollamaProcess = null;
let brightnessCliAvailable = null;

const CURRENT_SCHEMA_VERSION = 1;
const SAVE_PATH = path.join(os.homedir(), 'ollama-pet-data.json');

// ── RELIABLE OLLAMA DETECTION & MANAGEMENT ───────
function findOllamaExecutable() {
  const candidatePaths = [
    '/opt/homebrew/bin/ollama',
    '/usr/local/bin/ollama',
    '/usr/bin/ollama'
  ];

  for (const candidate of candidatePaths) {
    try {
      if (fs.existsSync(candidate)) return candidate;
    } catch (_) {}
  }

  try {
    const stdout = execSync('which ollama', { encoding: 'utf8', timeout: 1500 }).trim();
    if (stdout && fs.existsSync(stdout)) return stdout;
  } catch (_) {}

  return null;
}

function checkOllamaApiRunning(timeoutMs = 1500) {
  return new Promise((resolve) => {
    const req = http.get('http://localhost:11434/api/tags', { timeout: timeoutMs }, (res) => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        try {
          const data = JSON.parse(raw);
          const models = Array.isArray(data.models) ? data.models.map(m => m.name || m.model).filter(Boolean) : [];
          resolve({ running: true, models });
        } catch (_) {
          resolve({ running: true, models: [] });
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ running: false, models: [] });
    });

    req.on('error', () => {
      resolve({ running: false, models: [] });
    });
  });
}

async function startOllama() {
  const execPath = findOllamaExecutable();
  const apiCheck = await checkOllamaApiRunning(1500);

  if (apiCheck.running) {
    console.log('Ollama server is already running ✓');
    return { status: 'running', execPath, models: apiCheck.models };
  }

  if (!execPath) {
    console.warn('Ollama executable not found in /opt/homebrew/bin, /usr/local/bin, or PATH');
    return { status: 'not_installed', execPath: null, models: [] };
  }

  try {
    const envPath = ['/opt/homebrew/bin', '/usr/local/bin', '/usr/bin', '/bin', process.env.PATH].filter(Boolean).join(':');
    ollamaProcess = spawn(execPath, ['serve'], {
      detached: true,
      stdio: 'ignore',
      env: { ...process.env, PATH: envPath }
    });
    ollamaProcess.unref();
    console.log(`Ollama started automatically using ${execPath} ✓`);
    return { status: 'started', execPath, models: [] };
  } catch (err) {
    console.error('Could not auto-start Ollama:', err.message);
    return { status: 'failed', execPath, error: err.message, models: [] };
  }
}

// Start Ollama check safely
startOllama().catch(err => console.error('Error during startOllama:', err));

// ── SINGLE INSTANCE LOCK ─────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win && !win.isDestroyed()) {
      win.showInactive();
      petVisible = true;
      win.webContents.send('pet-visibility', true);
    }
  });
}

// ── MULTI-MONITOR POSITION HELPERS ───────────────
let petClosedPos = null;
let currentAnchor = { x: 'right', y: 'bottom' };

function loadSavedDataFromDisk() {
  try {
    if (fs.existsSync(SAVE_PATH)) {
      const raw = fs.readFileSync(SAVE_PATH, 'utf8');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Failed to read saved data from disk:', err.message);
  }
  return null;
}

function getValidWorkAreaForPosition(x, y, w, h) {
  const displays = screen.getAllDisplays();
  if (!displays || displays.length === 0) {
    const primary = screen.getPrimaryDisplay();
    return { display: primary, x: primary.workArea.x, y: primary.workArea.y };
  }

  let match = displays.find(d => {
    const wa = d.workArea;
    return x >= wa.x - 20 && x <= wa.x + wa.width + 20 &&
           y >= wa.y - 20 && y <= wa.y + wa.height + 20;
  });

  if (!match) {
    match = screen.getDisplayNearestPoint({ x: Math.round(x), y: Math.round(y) }) || screen.getPrimaryDisplay();
  }

  const wa = match.workArea;
  const clampedX = Math.max(wa.x + 10, Math.min(x, wa.x + wa.width - w - 10));
  const clampedY = Math.max(wa.y + 10, Math.min(y, wa.y + wa.height - h - 10));
  return { display: match, x: clampedX, y: clampedY };
}

function ensureWindowOnScreen(targetWin) {
  if (!targetWin || targetWin.isDestroyed()) return;
  const [curX, curY] = targetWin.getPosition();
  const [curW, curH] = targetWin.getSize();
  const valid = getValidWorkAreaForPosition(curX, curY, curW, curH);

  if (Math.abs(curX - valid.x) > 5 || Math.abs(curY - valid.y) > 5) {
    targetWin.setPosition(valid.x, valid.y);
    if (curW <= 135) petClosedPos = { x: valid.x, y: valid.y };
    targetWin.webContents.send('position-reply', { x: valid.x, y: valid.y });
  }

  if (walkerWin && !walkerWin.isDestroyed()) {
    const wa = valid.display.workArea;
    walkerWin.setBounds({
      x: wa.x,
      y: wa.y + wa.height - 120,
      width: wa.width,
      height: 120
    });
  }
}

// ── APP READY ────────────────────────────────────
app.whenReady().then(() => {
  if (process.platform === 'darwin') {
    app.setLoginItemSettings({ openAtLogin: true, openAsHidden: true });
    if (app.dock) app.dock.hide();
  }

  const primaryDisplay = screen.getPrimaryDisplay();
  const { x: px, y: py, width: pw, height: ph } = primaryDisplay.workArea;

  const defaultW = 130;
  const defaultH = 145;
  let defaultX = px + pw - defaultW - 10;
  let defaultY = py + ph - defaultH - 10;

  // Restore saved position directly at launch to prevent jump/drift
  const savedData = loadSavedDataFromDisk();
  if (savedData && savedData.position && typeof savedData.position.x === 'number' && typeof savedData.position.y === 'number') {
    const valid = getValidWorkAreaForPosition(savedData.position.x, savedData.position.y, defaultW, defaultH);
    defaultX = valid.x;
    defaultY = valid.y;
  }
  petClosedPos = { x: defaultX, y: defaultY };

  // Main pet window
  win = new BrowserWindow({
    width: defaultW,
    height: defaultH,
    x: defaultX,
    y: defaultY,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    show: false,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: true,
      autoplayPolicy: 'no-user-gesture-required'
    }
  });

  win.loadFile('index.html');

  win.once('ready-to-show', () => {
    win.showInactive();
  });

  if (process.platform === 'darwin') {
    win.setAlwaysOnTop(true, 'floating', 1);
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  } else {
    win.setAlwaysOnTop(true, 'screen-saver');
    win.setVisibleOnAllWorkspaces(true);
  }

  // Global shortcut — Cmd+Shift+P on Mac, Ctrl+Shift+P on Windows/Linux
  const shortcut = process.platform === 'darwin' ? 'Command+Shift+P' : 'Ctrl+Shift+P';
  globalShortcut.register(shortcut, () => {
    petVisible = !petVisible;
    if (petVisible) {
      win.showInactive();
      win.webContents.send('pet-visibility', true);
    } else {
      win.webContents.send('pet-visibility', false);
      setTimeout(() => {
        if (!petVisible && win && !win.isDestroyed()) win.hide();
      }, 200);
    }
  });

  // Walker window
  walkerWin = new BrowserWindow({
    width: pw,
    height: 120,
    x: px,
    y: py + ph - 120,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    show: false,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    focusable: false,
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: true
    }
  });

  walkerWin.loadFile('walker.html');
  walkerWin.setIgnoreMouseEvents(true);

  walkerWin.once('ready-to-show', () => {
    walkerWin.showInactive();
  });

  if (process.platform === 'darwin') {
    walkerWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  } else {
    walkerWin.setVisibleOnAllWorkspaces(true);
  }

  // Crash recovery guards
  setupCrashRecovery(win, 'main', 'index.html');
  setupCrashRecovery(walkerWin, 'walker', 'walker.html');

  // Monitor topology change listeners
  screen.on('display-metrics-changed', () => ensureWindowOnScreen(win));
  screen.on('display-removed', () => ensureWindowOnScreen(win));
  screen.on('display-added', () => ensureWindowOnScreen(win));
});

// ── RENDERER CRASH HANDLING ──────────────────────
const crashTracker = {
  main: { count: 0, lastTime: 0 },
  walker: { count: 0, lastTime: 0 }
};

function setupCrashRecovery(targetWin, name, fileToLoad) {
  if (!targetWin) return;
  targetWin.webContents.on('render-process-gone', (event, details) => {
    console.error(`[CRASH] ${name} renderer process gone:`, details);
    const now = Date.now();
    const tracker = crashTracker[name];
    if (now - tracker.lastTime > 60000) tracker.count = 0;
    tracker.lastTime = now;
    tracker.count++;

    if (tracker.count <= 3) {
      console.log(`[RECOVERY] Reloading ${name} window (attempt ${tracker.count}/3)...`);
      setTimeout(() => {
        if (targetWin && !targetWin.isDestroyed()) {
          targetWin.loadFile(fileToLoad).catch(e => console.error(`Failed to reload ${name}:`, e));
        }
      }, 500);
    } else {
      console.error(`[CRASH] ${name} crashed repeatedly. Halting auto-reload to avoid loop.`);
    }
  });
}

app.on('will-quit', () => globalShortcut.unregisterAll());

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ── SYSTEM CPU MEASUREMENT (REAL SYSTEM DELTA) ──
let lastCpuSnapshot = null;

function computeSystemCpuUsage() {
  const cpus = os.cpus();
  if (!cpus || cpus.length === 0) return null;

  let idle = 0;
  let total = 0;

  for (const core of cpus) {
    for (const key in core.times) {
      total += core.times[key];
    }
    idle += core.times.idle;
  }

  if (!lastCpuSnapshot) {
    lastCpuSnapshot = { idle, total };
    return null;
  }

  const idleDiff = idle - lastCpuSnapshot.idle;
  const totalDiff = total - lastCpuSnapshot.total;
  lastCpuSnapshot = { idle, total };

  if (totalDiff <= 0) return 0;
  const usage = 100 - Math.round((idleDiff / totalDiff) * 100);
  return Math.max(0, Math.min(100, usage));
}

setInterval(() => {
  try {
    if (win && !win.isDestroyed()) {
      const cpuPct = computeSystemCpuUsage();
      if (cpuPct !== null) {
        win.webContents.send('cpu-update', cpuPct);
      }
    }
  } catch (err) {
    console.warn('CPU monitor tick error:', err.message);
  }
}, 3000);

// ── SYSTEM IDLE TIME ─────────────────────────────
setInterval(() => {
  try {
    if (win && !win.isDestroyed()) {
      const idleSecs = powerMonitor.getSystemIdleTime();
      win.webContents.send('idle-update', idleSecs);
    }
  } catch (err) {
    console.warn('Idle monitor tick error:', err.message);
  }
}, 10000);

// ── DARK/LIGHT THEME ─────────────────────────────
function sendTheme() {
  try {
    if (win && !win.isDestroyed()) {
      win.webContents.send('theme-update', nativeTheme.shouldUseDarkColors ? 'dark' : 'light');
    }
  } catch (_) {}
}
nativeTheme.on('updated', sendTheme);
app.whenReady().then(() => setTimeout(sendTheme, 1500));

// ── IPC HANDLERS ─────────────────────────────────
ipcMain.on('close-app', () => app.quit());

ipcMain.handle('check-ollama', async () => {
  const execPath = findOllamaExecutable();
  const apiCheck = await checkOllamaApiRunning(2000);

  if (apiCheck.running) {
    if (apiCheck.models.length > 0) {
      return { status: 'ready', models: apiCheck.models, binaryPath: execPath };
    }
    return { status: 'no_models', models: [], binaryPath: execPath };
  }

  if (execPath) {
    return { status: 'server_offline', models: [], binaryPath: execPath };
  }

  return { status: 'not_installed', models: [], binaryPath: null };
});

ipcMain.on('set-size', (e, { open }) => {
  if (!win || win.isDestroyed()) return;

  // 1. Resolve display and workArea BEFORE resizing
  const currentBounds = win.getBounds();
  const display = screen.getDisplayMatching(currentBounds);
  const wa = display.workArea;

  const closedW = 130;
  const closedH = 145;
  const openW = 340;
  const openH = 640;

  if (open) {
    if (!petClosedPos) {
      petClosedPos = { x: currentBounds.x, y: currentBounds.y };
    }

    // Determine anchor based on pet closed position relative to the display work area
    const isLeft = (petClosedPos.x + closedW / 2) < (wa.x + wa.width / 2);
    const isTop = (petClosedPos.y + closedH / 2) < (wa.y + wa.height / 2);
    currentAnchor = { x: isLeft ? 'left' : 'right', y: isTop ? 'top' : 'bottom' };

    let targetX = isLeft ? petClosedPos.x : petClosedPos.x - (openW - closedW);
    let targetY = isTop ? petClosedPos.y : petClosedPos.y - (openH - closedH);

    // Strictly clamp within the SAME display's workArea
    targetX = Math.max(wa.x, Math.min(targetX, wa.x + wa.width - openW));
    targetY = Math.max(wa.y, Math.min(targetY, wa.y + wa.height - openH));

    win.webContents.send('anchor-update', currentAnchor);
    win.setBounds({
      x: Math.round(targetX),
      y: Math.round(targetY),
      width: openW,
      height: openH
    });
  } else {
    // Restoring to closed pet position with ZERO drift
    const targetX = petClosedPos ? petClosedPos.x : currentBounds.x;
    const targetY = petClosedPos ? petClosedPos.y : currentBounds.y;

    const clampedX = Math.max(wa.x, Math.min(targetX, wa.x + wa.width - closedW));
    const clampedY = Math.max(wa.y, Math.min(targetY, wa.y + wa.height - closedH));
    petClosedPos = { x: clampedX, y: clampedY };

    win.setBounds({
      x: Math.round(clampedX),
      y: Math.round(clampedY),
      width: closedW,
      height: closedH
    });
    win.webContents.send('position-reply', petClosedPos);
  }
});

ipcMain.on('move-win', (e, { x, y }) => {
  if (!win || win.isDestroyed()) return;
  if (typeof x !== 'number' || typeof y !== 'number' || isNaN(x) || isNaN(y)) return;
  const roundX = Math.round(x);
  const roundY = Math.round(y);
  win.setPosition(roundX, roundY);

  const [w] = win.getSize();
  if (w <= 135) {
    petClosedPos = { x: roundX, y: roundY };
  } else {
    const closedX = currentAnchor.x === 'left' ? roundX : roundX + (340 - 130);
    const closedY = currentAnchor.y === 'top' ? roundY : roundY + (640 - 145);
    petClosedPos = { x: closedX, y: closedY };
  }
});

ipcMain.on('snap-corner', () => {
  if (!win || win.isDestroyed()) return;
  const display = screen.getDisplayMatching(win.getBounds());
  const { x, y, width, height } = display.workArea;
  const [cx, cy] = win.getPosition();
  const [cw, ch] = win.getSize();

  const CORNER_THRESHOLD = 90;
  const nearLeft = Math.abs(cx - (x + 10)) < CORNER_THRESHOLD;
  const nearRight = Math.abs(cx - (x + width - cw - 10)) < CORNER_THRESHOLD;
  const nearTop = Math.abs(cy - (y + 10)) < CORNER_THRESHOLD;
  const nearBottom = Math.abs(cy - (y + height - ch - 10)) < CORNER_THRESHOLD;

  let snapX = cx;
  let snapY = cy;

  if ((nearLeft || nearRight) && (nearTop || nearBottom)) {
    snapX = nearLeft ? (x + 10) : (x + width - cw - 10);
    snapY = nearTop ? (y + 10) : (y + height - ch - 10);
  } else {
    snapX = Math.max(x + 10, Math.min(cx, x + width - cw - 10));
    snapY = Math.max(y + 10, Math.min(cy, y + height - ch - 10));
  }

  win.setPosition(snapX, snapY);
  if (cw <= 135) {
    petClosedPos = { x: snapX, y: snapY };
  } else {
    const closedX = currentAnchor.x === 'left' ? snapX : snapX + (340 - 130);
    const closedY = currentAnchor.y === 'top' ? snapY : snapY + (640 - 145);
    petClosedPos = { x: closedX, y: closedY };
  }
  win.webContents.send('position-reply', { x: snapX, y: snapY });
});

ipcMain.on('notify', (e, { title, body }) => {
  if (Notification.isSupported()) {
    try {
      new Notification({ title, body, silent: true }).show();
    } catch (err) {
      console.warn('Failed to display notification:', err.message);
    }
  }
});

// ── DATA PERSISTENCE WITH SCHEMA VERSIONING ──────
ipcMain.on('save-data', (e, data) => {
  try {
    const payload = {
      version: CURRENT_SCHEMA_VERSION,
      ...data,
      updatedAt: Date.now()
    };
    fs.writeFileSync(SAVE_PATH, JSON.stringify(payload, null, 2), 'utf8');
  } catch (err) {
    console.error('Failed to save data:', err.message);
  }
});

ipcMain.on('load-data', (e) => {
  try {
    if (fs.existsSync(SAVE_PATH)) {
      const raw = fs.readFileSync(SAVE_PATH, 'utf8');
      const d = JSON.parse(raw);
      const validChars = ['cat', 'dragon', 'robot', 'ghost', 'fox', 'bunny'];
      let chosenChar = typeof d.currentChar === 'string' && validChars.includes(d.currentChar) ? d.currentChar : 'cat';
      if (d.randomCharOnLaunch === true) {
        chosenChar = validChars[Math.floor(Math.random() * validChars.length)];
      }

      const validated = {
        version: d.version || CURRENT_SCHEMA_VERSION,
        currentChar: chosenChar,
        randomCharOnLaunch: !!d.randomCharOnLaunch,
        streak: typeof d.streak === 'number' ? d.streak : 0,
        lastChatDate: typeof d.lastChatDate === 'string' ? d.lastChatDate : '',
        moodPoints: typeof d.moodPoints === 'number' ? d.moodPoints : 100,
        gameBest: typeof d.gameBest === 'number' ? d.gameBest : 0,
        activeTab: typeof d.activeTab === 'string' ? d.activeTab : 'chat',
        selectedModel: typeof d.selectedModel === 'string' ? d.selectedModel : '',
        history: Array.isArray(d.history) ? d.history : [],
        reminders: Array.isArray(d.reminders) ? d.reminders : [],
        position: (d.position && typeof d.position.x === 'number' && typeof d.position.y === 'number')
          ? d.position
          : null
      };

      // Validate coordinates if present
      if (validated.position) {
        const [w, h] = win.getSize();
        const valid = getValidWorkAreaForPosition(validated.position.x, validated.position.y, w, h);
        validated.position = { x: valid.x, y: valid.y };
        petClosedPos = { x: valid.x, y: valid.y };
      }

      win.webContents.send('data-loaded', validated);
    }
  } catch (err) {
    console.error('Failed to load data:', err.message);
  }
});

ipcMain.on('export-chat', async (e, text) => {
  try {
    const defaultName = `ollama-chat-${new Date().toISOString().slice(0, 10)}.txt`;
    const { canceled, filePath } = await dialog.showSaveDialog(win, {
      title: 'Export Chat',
      defaultPath: path.join(os.homedir(), defaultName),
      filters: [{ name: 'Text Files', extensions: ['txt'] }]
    });
    if (canceled || !filePath) return;
    fs.writeFileSync(filePath, text, 'utf8');
    win.webContents.send('export-done', filePath);
  } catch (err) {
    console.error('Failed to export chat:', err.message);
  }
});

ipcMain.on('walk-char', (e, svgContent) => {
  if (walkerWin && !walkerWin.isDestroyed()) {
    // Ensure walker is positioned on current window's display
    const display = screen.getDisplayMatching(win.getBounds());
    const { x, y, width, height } = display.workArea;
    walkerWin.setBounds({ x, y: y + height - 120, width, height: 120 });
    walkerWin.webContents.send('start-walk', svgContent);
  }
});

ipcMain.on('get-position', (e) => {
  if (win && !win.isDestroyed()) {
    const [x, y] = win.getPosition();
    const [w] = win.getSize();
    const pos = (w <= 135 && petClosedPos) ? petClosedPos : { x, y };
    e.reply('position-reply', pos);
  }
});

ipcMain.on('set-ignore-mouse', (e, flag) => {
  if (win && !win.isDestroyed()) {
    try {
      win.setIgnoreMouseEvents(Boolean(flag), { forward: true });
    } catch (err) {
      console.warn('Failed to setIgnoreMouseEvents:', err.message);
    }
  }
});

ipcMain.on('open-music-dialog', async () => {
  try {
    const { canceled, filePaths } = await dialog.showOpenDialog(win, {
      title: 'Select Music File',
      properties: ['openFile'],
      filters: [{ name: 'Audio', extensions: ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'] }]
    });
    if (canceled || !filePaths.length) return;
    const fp = filePaths[0];
    const fileName = path.basename(fp);
    win.webContents.send('music-file-selected', { filePath: fp, fileName });
  } catch (err) {
    console.error('Failed to open music dialog:', err.message);
  }
});

// ── SYSTEM STATUS (DIAGNOSTICS & HARDWARE) ────────
ipcMain.on('get-system-status', (e) => {
  try {
    const platform = process.platform;
    const totalMem = os.totalmem();
    const freeMem  = os.freemem();
    const usedMem  = totalMem - freeMem;
    const memPct   = Math.round((usedMem / totalMem) * 100);

    let battery = null;
    if (platform === 'darwin') {
      try {
        const raw = execSync('pmset -g batt', { timeout: 1500, encoding: 'utf8' });
        const pct = raw.match(/(\d+)%/);
        const charging = raw.includes('AC Power') || raw.includes('charging');
        if (pct) battery = { level: parseInt(pct[1], 10), charging };
      } catch (_) {}
    }

    const cpus = os.cpus();
    const model = cpus && cpus[0]?.model ? cpus[0].model : 'Apple Silicon / x86';
    const cores = cpus ? cpus.length : 1;
    const uptimeSec = os.uptime();
    const uptimeH = Math.floor(uptimeSec / 3600);
    const uptimeM = Math.floor((uptimeSec % 3600) / 60);

    let topProc = null;
    if (platform === 'darwin') {
      try {
        const raw = execSync('ps -Ao comm,pcpu -r | head -3', { timeout: 1500, encoding: 'utf8' }).trim().split('\n');
        topProc = raw.slice(1).map(l => l.trim()).filter(Boolean)[0] || null;
      } catch (_) {}
    }

    win.webContents.send('system-status', {
      platform,
      totalMemGB: (totalMem / 1073741824).toFixed(1),
      usedMemGB:  (usedMem  / 1073741824).toFixed(1),
      memPct,
      battery,
      cpuModel: model.replace(/\s+/g, ' ').trim(),
      cores,
      uptime: `${uptimeH}h ${uptimeM}m`,
      topProc,
      hostname: os.hostname(),
    });
  } catch (err) {
    console.warn('System status collection fallback triggered:', err.message);
    try {
      win.webContents.send('system-status', {
        platform: process.platform,
        hostname: os.hostname(),
        cpuModel: 'System CPU',
        cores: os.cpus() ? os.cpus().length : 1,
        totalMemGB: (os.totalmem() / 1073741824).toFixed(1),
        usedMemGB:  ((os.totalmem() - os.freemem()) / 1073741824).toFixed(1),
        memPct: Math.round(((os.totalmem() - os.freemem()) / os.totalmem()) * 100),
        uptime: `${Math.floor(os.uptime() / 3600)}h ${Math.floor((os.uptime() % 3600) / 60)}m`,
        battery: null,
        topProc: '—'
      });
    } catch (_) {}
  }
});

// ── ACTIVE APPS (ACCURATE MACOS FOREGROUND DETECTION) ──
ipcMain.on('get-active-apps', (e) => {
  try {
    const platform = process.platform;
    let apps = [];
    if (platform === 'darwin') {
      try {
        const script = 'tell application "System Events" to get name of every process whose background only is false';
        const raw = execSync(`osascript -e '${script}'`, { timeout: 2000, encoding: 'utf8' }).trim();
        apps = raw.split(',').map(s => s.trim()).filter(Boolean).slice(0, 10);
      } catch (osascriptErr) {
        // Fallback to top running processes
        const raw = execSync("ps -Ao comm -r | head -20", { timeout: 2000, encoding: 'utf8' }).trim().split('\n');
        apps = [...new Set(raw.map(l => l.trim().split('/').pop()).filter(Boolean))].slice(0, 10);
      }
    } else if (platform === 'linux') {
      const raw = execSync("ps -Ao comm --sort=-%cpu | head -15", { timeout: 2000, encoding: 'utf8' }).trim().split('\n');
      apps = [...new Set(raw.map(l => l.trim()).filter(Boolean))].slice(0, 10);
    } else {
      apps = ['explorer', 'chrome', 'code'];
    }
    win.webContents.send('active-apps', apps);
  } catch (err) {
    console.warn('Active apps error:', err.message);
    win.webContents.send('active-apps', []);
  }
});

// ── SCREEN BRIGHTNESS (FAIL-SAFE) ────────────────
function checkBrightnessSupport() {
  if (brightnessCliAvailable !== null) return brightnessCliAvailable;
  if (process.platform !== 'darwin') {
    brightnessCliAvailable = false;
    return false;
  }
  try {
    execSync('which brightness', { timeout: 1000, stdio: 'ignore' });
    brightnessCliAvailable = true;
  } catch (_) {
    brightnessCliAvailable = false;
  }
  return brightnessCliAvailable;
}

ipcMain.on('get-brightness', (e) => {
  try {
    if (checkBrightnessSupport()) {
      const raw = execSync("brightness -l 2>/dev/null | grep 'display 0' | awk '{print $NF}'", { timeout: 1500, encoding: 'utf8' }).trim();
      const val = parseFloat(raw);
      win.webContents.send('brightness-update', isNaN(val) ? -1 : Math.round(val * 100));
    } else {
      win.webContents.send('brightness-update', -1);
    }
  } catch (err) {
    win.webContents.send('brightness-update', -1);
  }
});

// ── TYPING SPEED ─────────────────────────────────
ipcMain.on('typing-speed', (e, wpm) => {
  if (win && !win.isDestroyed()) {
    win.webContents.send('typing-speed-reaction', wpm);
  }
});
