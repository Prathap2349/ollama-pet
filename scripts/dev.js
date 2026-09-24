const http = require('http');
const { spawn } = require('child_process');

function isOllamaRunning() {
  return new Promise((resolve) => {
    const req = http.get('http://localhost:11434/api/tags', { timeout: 1500 }, (res) => {
      resolve(res.statusCode === 200 || res.statusCode === 404);
    });
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.on('error', () => resolve(false));
  });
}

async function runDev() {
  const running = await isOllamaRunning();
  if (running) {
    console.log('✓ Ollama server is already running on port 11434. Launching Ollama Pet...');
  } else {
    console.log('🐾 Starting Ollama server in background...');
    try {
      const ollama = spawn('ollama', ['serve'], { stdio: 'ignore', detached: true });
      ollama.unref();
      for (let i = 0; i < 6; i++) {
        await new Promise(r => setTimeout(r, 500));
        if (await isOllamaRunning()) {
          console.log('✓ Ollama server started.');
          break;
        }
      }
    } catch (err) {
      console.warn('Could not launch ollama serve:', err.message);
    }
  }

  console.log('🚀 Starting Electron...');
  const electronCmd = process.platform === 'win32' ? 'npx.cmd' : 'npx';
  const electron = spawn(electronCmd, ['electron', '.'], { stdio: 'inherit' });
  electron.on('exit', (code) => process.exit(code || 0));
}

runDev();
