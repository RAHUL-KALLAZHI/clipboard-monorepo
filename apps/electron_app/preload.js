const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  createPair: () => ipcRenderer.invoke('createPair'),
  startPrePairSocket: () => ipcRenderer.invoke('startPrePairSocket'),
  startPollingClipboard: token =>
    ipcRenderer.invoke('startPollingClipboard', token),

  // 🔥 You are missing this
  generateQR: text => ipcRenderer.invoke('generateQR', text),
  disconnect: tokens => ipcRenderer.invoke('disconnect', tokens),

  on: (evt, cb) => ipcRenderer.on(evt, (_, data) => cb(data)),
});
