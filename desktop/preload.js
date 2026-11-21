const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('nxDesktop', {
  checkUpdate: () => ipcRenderer.invoke('update-check'),
  downloadUpdate: () => ipcRenderer.invoke('update-download'),
  copyToDesktop: () => ipcRenderer.invoke('update-to-desktop'),
  showDownloaded: () => ipcRenderer.invoke('update-show'),
  onProgress: cb => ipcRenderer.on('update-progress', (e, p) => cb(p)),
  attention: () => ipcRenderer.send('attention')
});
