const { contextBridge, ipcRenderer } = require('electron');

// Securely expose APIs to renderer via contextBridge
contextBridge.exposeInMainWorld('electronAPI', {
  // Window & App management
  closeApp: () => ipcRenderer.send('close-app'),
  setSize: (opts) => ipcRenderer.send('set-size', opts),
  moveWindow: (coords) => ipcRenderer.send('move-win', coords),
  snapCorner: () => ipcRenderer.send('snap-corner'),
  getPosition: () => ipcRenderer.send('get-position'),
  setIgnoreMouse: (flag) => ipcRenderer.send('set-ignore-mouse', flag),

  // Notifications & Persistence
  notify: (data) => ipcRenderer.send('notify', data),
  saveData: (data) => ipcRenderer.send('save-data', data),
  loadData: () => ipcRenderer.send('load-data'),
  exportChat: (text) => ipcRenderer.send('export-chat', text),

  // Features
  walkChar: (svg) => ipcRenderer.send('walk-char', svg),
  openMusicDialog: () => ipcRenderer.send('open-music-dialog'),
  getSystemStatus: () => ipcRenderer.send('get-system-status'),
  getActiveApps: () => ipcRenderer.send('get-active-apps'),
  getBrightness: () => ipcRenderer.send('get-brightness'),
  sendTypingSpeed: (wpm) => ipcRenderer.send('typing-speed', wpm),

  // Ollama
  checkOllama: () => ipcRenderer.invoke('check-ollama'),

  // Event listeners from main process
  onPetVisibility: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('pet-visibility', handler);
    return () => ipcRenderer.removeListener('pet-visibility', handler);
  },
  onPositionReply: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('position-reply', handler);
    return () => ipcRenderer.removeListener('position-reply', handler);
  },
  onDataLoaded: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('data-loaded', handler);
    return () => ipcRenderer.removeListener('data-loaded', handler);
  },
  onExportDone: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('export-done', handler);
    return () => ipcRenderer.removeListener('export-done', handler);
  },
  onMusicFileSelected: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('music-file-selected', handler);
    return () => ipcRenderer.removeListener('music-file-selected', handler);
  },
  onSystemStatus: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('system-status', handler);
    return () => ipcRenderer.removeListener('system-status', handler);
  },
  onCpuUpdate: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('cpu-update', handler);
    return () => ipcRenderer.removeListener('cpu-update', handler);
  },
  onIdleUpdate: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('idle-update', handler);
    return () => ipcRenderer.removeListener('idle-update', handler);
  },
  onThemeUpdate: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('theme-update', handler);
    return () => ipcRenderer.removeListener('theme-update', handler);
  },
  onActiveApps: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('active-apps', handler);
    return () => ipcRenderer.removeListener('active-apps', handler);
  },
  onBrightnessUpdate: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('brightness-update', handler);
    return () => ipcRenderer.removeListener('brightness-update', handler);
  },
  onStartWalk: (callback) => {
    const handler = (e, val) => callback(val);
    ipcRenderer.on('start-walk', handler);
    return () => ipcRenderer.removeListener('start-walk', handler);
  }
});
