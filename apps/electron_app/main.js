const { app, BrowserWindow, clipboard, ipcMain } = require('electron');
const path = require('path');
const axios = require('axios');
const ioClient = require('socket.io-client');
const QRCode = require('qrcode');

const SERVER = process.env.SERVER || 'https://clipboard-mono-repo.onrender.com';

let win;
let pairing = null;
let socket = null;
let lastText = '';

function createWindow() {
  win = new BrowserWindow({
    width: 520,
    height: 640,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  });
  win.loadFile('index.html');
}

app.whenReady().then(createWindow);

ipcMain.handle('generateQR', async (_, text) => {
  return QRCode.toDataURL(text);
});

// Expose functionality via IPC from renderer to main
ipcMain.handle('createPair', async () => {
  const resp = await axios.post(`${SERVER}/pair/create`);
  pairing = resp.data; // { pairingId, code, expiresInMs }
  return pairing;
});

ipcMain.handle('startPrePairSocket', async () => {
  if (!pairing) throw new Error('no pairing info created');
  // Connect to socket with pairingId so server can notify when mobile confirms
  socket = ioClient(SERVER, {
    query: { pairingId: pairing.pairingId },
  });
  socket.on('connect', () => {
    console.log('pre-pair socket connected');
  });
  socket.on('pairing_wait', d => {
    win.webContents.send('pairing_wait', d);
  });
  socket.on('paired', d => {
    // d contains desktopToken, mobileToken, roomId
    win.webContents.send('paired', d);
    // You might choose to reconnect with desktopToken, but for demo we can use token to reinit socket
    socket.disconnect();
    startAuthenticatedSocket(d.desktopToken);
  });
  socket?.on('disconnected', () => {
    win.webContents.send('disconnected');
  });
  return true;
});

function startAuthenticatedSocket(desktopToken) {
  if (socket) {
    try {
      socket.disconnect();
    } catch (e) {}
  }
  socket = ioClient(SERVER, {
    query: { token: desktopToken },
  });
  socket.on('connect', () =>
    console.log('desktop authenticated socket connected'),
  );
  socket.on('new_clipboard', payload => {
    console.log('incoming clipboard', payload);
    // notify renderer
    win.webContents.send('new_clipboard', payload);
  });
}

ipcMain.handle('startPollingClipboard', async (_, desktopToken) => {
  // start socket using desktopToken if provided (if not provided, it will start unauthenticated pre-pair)
  if (desktopToken) startAuthenticatedSocket(desktopToken);

  // simple polling loop
  setInterval(() => {
    try {
      const text = clipboard.readText() || '';
      if (text && text !== lastText) {
        lastText = text;
        // send to server if authenticated
        if (socket && socket.connected) {
          socket.emit('clipboard_update', { text });
        }
      }
    } catch (e) {
      console.error('clipboard read error', e);
    }
  }, 700); // poll every 700ms
});

ipcMain.handle('disconnect', async (_, tokens) => {
  try {
    await axios.post(`${SERVER}/pair/disconnect`, tokens);

    // close socket
    if (socket) {
      socket.disconnect();
      socket = null;
    }

    pairing = null;
    lastText = '';

    return true;
  } catch (e) {
    console.error('disconnect failed', e);
    return false;
  }
});
