const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const JWT_SECRET =
  process.env.JWT_SECRET || 'replace_this_with_a_strong_secret';
const PAIR_CODE_TTL_MS = 5 * 60 * 1000; // 5 minutes

const app = express();
app.use(cors());
app.use(bodyParser.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

/*
In-memory stores for demo.
In production use persistent DB or redis.
*/
const pairingStore = new Map(); // pairingId => {code, createdAt, desktopSocketId}
const deviceRoom = new Map(); // deviceId => roomId (for broadcasting)
const socketsByDevice = new Map(); // deviceId => socket.id

// Helper: make token for device
function makeToken(deviceId, role, room) {
  return jwt.sign({ deviceId, role, room }, JWT_SECRET, { expiresIn: '7d' });
}

// API: Desktop requests a pairing code
app.post('/pair/create', (req, res) => {
  // Generate an id + short numeric code
  const pairingId = uuidv4();
  const code = Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit
  pairingStore.set(pairingId, {
    code,
    createdAt: Date.now(),
    desktopSocketId: null,
  });
  // Return pairing information; QR payload can contain pairingId + code
  res.json({ pairingId, code, expiresInMs: PAIR_CODE_TTL_MS });
});

// API: Mobile confirms pairing by sending scanned pairingId + code + mobileDeviceId
app.post('/pair/confirm', (req, res) => {
  const { pairingId, code, mobileDeviceId } = req.body;
  if (!pairingId || !code || !mobileDeviceId)
    return res.status(400).json({ error: 'missing' });

  const pair = pairingStore.get(pairingId);
  if (!pair)
    return res.status(404).json({ error: 'pairing not found or expired' });
  if (Date.now() - pair.createdAt > PAIR_CODE_TTL_MS) {
    pairingStore.delete(pairingId);
    return res.status(410).json({ error: 'pairing expired' });
  }
  if (pair.code !== code)
    return res.status(401).json({ error: 'invalid code' });

  // Create a shared room id
  const roomId = uuidv4();
  // create tokens for desktop and mobile devices
  const desktopDeviceId = `desktop-${pairingId}`;
  const desktopToken = makeToken(desktopDeviceId, 'desktop', roomId);
  const mobileToken = makeToken(mobileDeviceId, 'mobile', roomId);

  // Save mapping (in production save to DB)
  deviceRoom.set(desktopDeviceId, roomId);
  deviceRoom.set(mobileDeviceId, roomId);

  // If desktop socket is connected and saved in pairingStore.desktopSocketId, notify it
  if (pair.desktopSocketId) {
    const sockId = pair.desktopSocketId;
    const sock = io.sockets.sockets.get(sockId);
    if (sock) {
      sock.emit('paired', {
        desktopToken,
        mobileToken,
        roomId,
        mobileDeviceId,
      });
    }
  }

  // Return token to mobile client
  pairingStore.delete(pairingId);
  res.json({ mobileToken, roomId });
});

// Simple health
app.get('/', (req, res) => res.send('Clipboard sync server'));

app.post('/pair/disconnect', (req, res) => {
  const { desktopToken, mobileToken } = req.body;

  console.log('Disconnect request:', desktopToken, mobileToken);

  try {
    const desktopPayload = desktopToken
      ? jwt.verify(desktopToken, JWT_SECRET)
      : null;
    const mobilePayload = mobileToken
      ? jwt.verify(mobileToken, JWT_SECRET)
      : null;

    const room = desktopPayload?.room || mobilePayload?.room || null;

    if (room) {
      io.to(room).emit('disconnected');
    }

    return res.json({ success: true });
  } catch (err) {
    console.error('Disconnect token error:', err.message);
    return res.status(400).json({ error: 'invalid token' });
  }
});

/* Socket.io connection flow:
 - Desktop initially connects with query { pairingId } so it can receive 'paired' event.
 - After 'paired' event desktop receives desktopToken and can re-authenticate as normal device (or just keep listening).
 - Devices that have a JWT token should connect with ?token=... ; we verify JWT and join room.
*/
io.on('connection', socket => {
  const { token, pairingId, role } = socket.handshake.query;

  // If connecting as desktop pre-pair (has pairingId but no token)
  if (pairingId && !token) {
    const pair = pairingStore.get(pairingId);
    if (pair) {
      // store desktop socket id so /pair/confirm can notify it
      pair.desktopSocketId = socket.id;
      pairingStore.set(pairingId, pair);
      socket.emit('pairing_wait', {
        pairingId,
        message: 'waiting for mobile to confirm pairing',
      });
      // Keep the socket until pairing is confirmed
      return;
    }
  }

  // If connecting with token: verify
  if (!token) {
    socket.emit('error', 'missing token or pairingId');
    socket.disconnect(true);
    return;
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const { deviceId, role, room } = payload;
    socketsByDevice.set(deviceId, socket.id);
    socket.join(room);
    console.log(`Device ${deviceId} joined room ${room}`);

    // allow client to send clipboard_update
    socket.on('clipboard_update', data => {
      // for safety, re-check device is in mapping to prevent spoofing (simple demo)
      const assignedRoom = deviceRoom.get(deviceId);
      if (!assignedRoom || assignedRoom !== room) {
        console.warn('device-room mismatch');
        return;
      }
      // Broadcast to room except sender
      socket.to(room).emit('new_clipboard', {
        text: data.text,
        from: deviceId,
        ts: Date.now(),
      });
    });

    socket.on('disconnect', () => {
      socketsByDevice.delete(deviceId);
    });
  } catch (err) {
    console.error('token verify failed', err.message);
    socket.emit('error', 'invalid token');
    socket.disconnect(true);
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Server running on ${PORT}`));
