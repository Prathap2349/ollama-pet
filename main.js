const { app, BrowserWindow, ipcMain, screen, Notification, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');

let win;
let walkerWin;
let petVisible = true;

const SAVE_PATH = path.join(os.homedir(), 'ollama-pet-data.json');

app.whenReady().then(() => {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;

  // Main pet window
  win = new BrowserWindow({
    width: 200,
    height: 420,
    x: width - 220,
    y: height - 440,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
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

ipcMain.on('set-size', (e, { w, h }) => {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;
  const [cx, cy] = win.getPosition();
  const [oldW] = win.getSize();

  // Determine which horizontal edge the window is anchored to
  // so resizing doesn't drift it across the screen
  const anchoredRight = cx + oldW > width / 2;

  win.setSize(w, h);

  let nx, ny;
  if (anchoredRight) {
    // Keep the RIGHT edge fixed — chat opens leftward, not rightward
    nx = cx + oldW - w;
  } else {
    // Keep the LEFT edge fixed
    nx = cx;
  }
  ny = cy; // always keep top edge fixed — height grows downward

  // Only clamp if actually out of screen bounds
  nx = Math.max(0, Math.min(nx, width - w - 4));
  ny = Math.max(0, Math.min(ny, height - h - 4));

  win.setPosition(Math.round(nx), Math.round(ny));
});

ipcMain.on('move-win', (e, { x, y }) => {
  win.setPosition(Math.round(x), Math.round(y));
});

ipcMain.on('snap-corner', () => {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;
  const [cx, cy] = win.getPosition();
  const [cw, ch] = win.getSize();
  // Snap to nearest corner with a small margin
  const snapX = cx + cw/2 < width  / 2 ? 10 : width  - cw - 10;
  const snapY = cy + ch/2 < height / 2 ? 10 : height - ch - 10;
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

ipcMain.on('export-chat', (e, text) => {
  const p = path.join(os.homedir(), `ollama-chat-${Date.now()}.txt`);
  try { fs.writeFileSync(p, text); win.webContents.send('export-done', p); } catch(_) {}
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

// CPU usage approximation
setInterval(() => {
  try {
    if (win && !win.isDestroyed()) {
      const cpuUsage = process.cpuUsage();
      win.webContents.send('cpu-update', Math.min(100, Math.round(cpuUsage.user / 10000)));
    }
  } catch(_) {}
}, 5000);
