const { app, BrowserWindow, shell } = require('electron');
const path = require('path');

const VERSION = process.platform === 'darwin' ? '0.5.0 Mac' : process.platform === 'linux' ? '0.0.1 Alfa' : '0.0.2 Alfa';

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
      nodeIntegration: false
    }
  });
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith('file:')) {
      e.preventDefault();
      shell.openExternal(url);
    }
  });
  win.loadFile(path.join(__dirname, 'app', 'index.html'), { query: { v: VERSION } });
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.whenReady().then(() => {
    createWindow();
    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
  });
  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });
}
