const { app, BrowserWindow, shell, ipcMain, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');

const VERSION = process.platform === 'darwin' ? '0.9.1 mac build' : '0.5.1 pc build';
const VERSION_URL = 'https://4yrfd6vww2-cmd.github.io/calculat/version.json';
const DOWNLOAD_PREFIX = 'https://github.com/4yrfd6vww2-cmd/calculat/releases/download/';
let mainWin = null;
let pendingUpdate = null;
let lastFile = null;
let tray = null;
let quitting = false;

// В AppImage на новых Ubuntu песочница Chromium может не стартовать; грузим только свои файлы.
if (process.platform === 'linux') app.commandLine.appendSwitch('no-sandbox');

function createWindow() {
  const win = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 760,
    minHeight: 520,
    backgroundColor: '#040817',
    title: 'neirox',
    autoHideMenuBar: true,
    webPreferences: {
      // Приложение грузит только свои локальные файлы и ходит на свой сервер,
      // поэтому CORS отключаем: Edge Functions не отвечают на preflight-запросы.
      webSecurity: false,
      contextIsolation: true,
      nodeIntegration: false,
      // таймеры не должны замедляться в свёрнутом окне — иначе звонки и сообщения придут с задержкой
      backgroundThrottling: false,
      preload: path.join(__dirname, 'preload.js')
    }
  });
  mainWin = win;
  // закрытие окна сворачивает приложение в трей: звонки и сообщения продолжают приходить
  win.on('close', e => {
    if (!quitting && tray) { e.preventDefault(); win.hide(); }
  });
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith('file:')) {
      e.preventDefault();
      if (/^https?:\/\//i.test(url)) shell.openExternal(url);
    }
  });
  win.loadFile(path.join(__dirname, 'app', 'index.html'), { query: { v: VERSION } });
}

// ---------- обновления ----------
function fetchBuffer(url, onProgress, redirects) {
  return new Promise((resolve, reject) => {
    if ((redirects || 0) > 6) return reject(new Error('redirects'));
    https.get(url, { headers: { 'User-Agent': 'neirox-desktop' } }, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return fetchBuffer(new URL(res.headers.location, url).toString(), onProgress, (redirects || 0) + 1).then(resolve, reject);
      }
      if (res.statusCode !== 200) { res.resume(); return reject(new Error('HTTP ' + res.statusCode)); }
      const total = Number(res.headers['content-length'] || 0);
      let got = 0;
      const chunks = [];
      res.on('data', c => { chunks.push(c); got += c.length; if (onProgress && total) onProgress(Math.floor(got * 100 / total)); });
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

function newer(a, b) {
  const x = String(a).split('.').map(Number), y = String(b).split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    const p = x[i] || 0, q = y[i] || 0;
    if (p !== q) return p > q;
  }
  return false;
}

ipcMain.handle('update-check', async () => {
  try {
    const legacy = /^0\.0\./.test(app.getVersion());
    const key = legacy
      ? (process.platform === 'darwin' ? 'legacy_mac' : process.arch === 'ia32' ? 'legacy_linux32' : 'legacy_linux')
      : (process.platform === 'win32' ? 'win' : process.platform === 'darwin' ? 'mac' : 'linux');
    const info = JSON.parse((await fetchBuffer(VERSION_URL + '?t=' + Date.now())).toString('utf8'));
    const e = info[key];
    if (!e) return null;
    const url = e[process.arch] || e.url;
    if (!url || !url.startsWith(DOWNLOAD_PREFIX)) return null;
    if (!newer(e.version, app.getVersion())) return null;
    pendingUpdate = { version: e.version, url };
    return { version: e.version };
  } catch (err) {
    return null;
  }
});

ipcMain.handle('update-download', async () => {
  if (!pendingUpdate) return { error: 'no_update' };
  try {
    const ext = path.extname(new URL(pendingUpdate.url).pathname);
    const base = path.basename(new URL(pendingUpdate.url).pathname, ext);
    const dest = path.join(app.getPath('downloads'), base + '-' + pendingUpdate.version + ext);
    const buf = await fetchBuffer(pendingUpdate.url, p => {
      if (mainWin && !mainWin.isDestroyed()) mainWin.webContents.send('update-progress', p);
    });
    fs.writeFileSync(dest, buf);
    lastFile = dest;
    return { path: dest };
  } catch (err) {
    return { error: String(err && err.message || err) };
  }
});

ipcMain.handle('update-to-desktop', async () => {
  if (!lastFile) return { error: 'no_file' };
  try {
    const dest = path.join(app.getPath('desktop'), path.basename(lastFile));
    fs.copyFileSync(lastFile, dest);
    return { path: dest };
  } catch (err) {
    return { error: String(err && err.message || err) };
  }
});

ipcMain.handle('update-show', async () => {
  if (lastFile) shell.showItemInFolder(lastFile);
  return true;
});

ipcMain.on('attention', () => {
  if (!mainWin || mainWin.isDestroyed()) return;
  try {
    if (mainWin.isMinimized()) mainWin.restore();
    mainWin.show();
    mainWin.flashFrame(true);
  } catch (e) { }
});

function showMain() {
  if (!mainWin || mainWin.isDestroyed()) { createWindow(); return; }
  if (mainWin.isMinimized()) mainWin.restore();
  mainWin.show();
  mainWin.focus();
}

function createTray() {
  try {
    let img = nativeImage.createFromPath(path.join(__dirname, 'build', 'icon.png'));
    if (img.isEmpty()) return;
    img = img.resize({ width: 24, height: 24 });
    tray = new Tray(img);
    tray.setToolTip('neirox');
    tray.setContextMenu(Menu.buildFromTemplate([
      { label: 'Открыть', click: showMain },
      { label: 'Выход', click: () => { quitting = true; app.quit(); } }
    ]));
    tray.on('click', showMain);
  } catch (e) {
    tray = null;
  }
}

app.on('before-quit', () => { quitting = true; });

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', showMain);
  app.whenReady().then(() => {
    createWindow();
    createTray();
    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });
  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });
}
