const { createHash } = require('node:crypto');
const { createServer } = require('node:http');
const { join } = require('node:path');
const express = require('express');
const { WebSocket, WebSocketServer } = require('ws');
const { decodePacket, describeAttachment, maxAttachmentSize, maxJsonSize, messageIdPattern } = require('./attachments');

const authenticationTimeout = 5000;
const typingTimeout = 3500;

function createChatServer({ config, authEmulator, allowedOrigins, verifyIdToken, getUser,
  readHistory, saveMessage, readAttachment, attachmentPath }) {
  const app = express();
  app.get('/firebase-config.json', (_request, response) => {
    response.set('Cache-Control', 'no-store').json({ firebase: config, authEmulator });
  });
  app.get('/attachments/:id', async (request, response) => {
    const token = request.get('authorization')?.match(/^Bearer (\S+)$/i)?.[1];
    try {
      if (!token) return response.sendStatus(401);
      const { uid } = await verifyIdToken(token);
      const profile = await getUser(uid);
      if (profile.disabled || !profile.displayName?.trim()) return response.sendStatus(403);
    } catch {
      return response.sendStatus(401);
    }
    const { id } = request.params;
    if (!messageIdPattern.test(id)) return response.sendStatus(404);
    const attachment = await readAttachment(id);
    if (!attachment || !messageIdPattern.test(attachment.digest)) return response.sendStatus(404);
    const path = attachmentPath(id, attachment.digest);
    response.set({
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; sandbox"
    });
    if (attachment.kind === 'file') {
      response.attachment(attachment.name).type('application/octet-stream');
    } else {
      response.type(attachment.mime);
    }
    response.sendFile(path);
  });
  app.use(express.static(join(__dirname, 'public')));

  const server = createServer(app);
  const wss = new WebSocketServer({ noServer: true, maxPayload: maxAttachmentSize + maxJsonSize + 1 });
  const users = new Map();

  server.on('upgrade', (request, socket, head) => {
    if (request.url !== '/ws' || !allowedOrigins.has(request.headers.origin)) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      return;
    }
    wss.handleUpgrade(request, socket, head, (ws) => wss.emit('connection', ws));
  });

  function send(ws, packet) {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(packet));
  }

  function broadcast(packet) {
    for (const { sockets } of users.values()) {
      for (const ws of sockets) send(ws, packet);
    }
  }

  function broadcastTyping(user, active) {
    for (const other of users.values()) {
      if (other === user) continue;
      for (const ws of other.sockets) {
        send(ws, { type: 'typing', uid: user.uid, name: user.name, active });
      }
    }
  }

  function stopTyping(user, ws) {
    clearTimeout(user.typing.get(ws));
    if (user.typing.delete(ws) && !user.typing.size) broadcastTyping(user, false);
  }

  function updateTyping(user, ws, active) {
    if (!active) {
      stopTyping(user, ws);
      return;
    }
    if (!user.typing.size) broadcastTyping(user, true);
    clearTimeout(user.typing.get(ws));
    user.typing.set(ws, setTimeout(() => stopTyping(user, ws), typingTimeout));
  }

  function announce(user, action) {
    broadcast({
      type: 'presence', count: users.size, action, name: user.name, timestamp: new Date().toISOString()
    });
  }

  wss.on('connection', (ws) => {
    let user;
    let ready = false;
    let alive = true;
    let receivedFirstFrame = false;
    let saving = false;
    let expiryTimer;
    let expiresAt;
    const authTimer = setTimeout(() => ws.close(4401, 'Autenticación requerida'), authenticationTimeout);
    const heartbeat = setInterval(() => {
      if (!alive) {
        ws.terminate();
        return;
      }
      alive = false;
      if (ws.readyState === WebSocket.OPEN) ws.ping();
    }, 25000);

    async function authenticate(packet) {
      if (packet?.type !== 'auth' || typeof packet.token !== 'string' || !packet.token) {
        ws.close(4401, 'Autenticación requerida');
        return;
      }

      let claims;
      let profile;
      try {
        claims = await verifyIdToken(packet.token);
        profile = await getUser(claims.uid);
      } catch (error) {
        if (error.code === 'auth/id-token-expired') {
          ws.close(4408, 'Token vencido');
        } else {
          ws.close(4401, 'Autenticación inválida');
        }
        return;
      }
      if (ws.readyState !== WebSocket.OPEN) return;
      if (profile.disabled) {
        ws.close(4401, 'Cuenta deshabilitada');
        return;
      }
      const name = profile.displayName?.trim();
      if (!name) {
        ws.close(4403, 'Falta el nombre visible');
        return;
      }
      expiresAt = claims.exp * 1000;
      if (expiresAt <= Date.now()) {
        ws.close(4408, 'Token vencido');
        return;
      }

      clearTimeout(authTimer);
      expiryTimer = setTimeout(() => ws.close(4408, 'Token vencido'), expiresAt - Date.now());

      user = users.get(claims.uid);
      const firstConnection = !user;
      if (!user) {
        user = { uid: claims.uid, name, sockets: new Set(), typing: new Map() };
        users.set(user.uid, user);
      }
      user.sockets.add(ws);
      if (firstConnection) announce(user, 'join');

      try {
        const history = await readHistory();
        if (ws.readyState !== WebSocket.OPEN) return;
        if (expiresAt <= Date.now()) {
          ws.close(4408, 'Token vencido');
          return;
        }
        send(ws, {
          type: 'ready', uid: user.uid, name, history, count: users.size,
          typing: Array.from(users.values())
            .filter((other) => other !== user && other.typing.size)
            .map(({ uid, name }) => ({ uid, name }))
        });
        ready = true;
      } catch {
        send(ws, { type: 'error', message: 'No se pudo cargar el historial. Se volverá a intentar.' });
        ws.close(1011, 'Historial no disponible');
      }
    }

    async function save(packet, file) {
      const text = typeof packet.text === 'string' ? packet.text.trim() : '';
      const length = Array.from(text).length;
      const requestId = typeof packet.id === 'string' && /^[0-9a-f]{32}$/.test(packet.id) ? packet.id : null;
      const attachment = file && describeAttachment(file, packet.filename, packet.mime);
      const sticker = packet.sticker === 'greeting' && !file && !text ? packet.sticker : undefined;
      if ((file && !attachment) || (!file && !sticker && length < 1) || length > 500 || !requestId || saving) {
        send(ws, {
          type: 'error', requestId,
          message: saving ? 'Hay un mensaje en espera de confirmación.'
            : file && !attachment ? 'El archivo debe tener un nombre válido y pesar hasta 8 MB.'
            : 'Escribe un mensaje de 1 a 500 caracteres.'
        });
        return;
      }

      // El mismo envío puede repetirse si se pierde la confirmación al reconectar.
      const id = createHash('sha256').update(JSON.stringify([user.uid, requestId])).digest('hex');
      for (const typingSocket of user.typing.keys()) stopTyping(user, typingSocket);
      saving = true;
      try {
        const { message, created } = await saveMessage({
          id, uid: user.uid, name: user.name, text, timestamp: new Date().toISOString(),
          ...(attachment ? { attachment } : {}),
          ...(sticker ? { sticker } : {})
        }, file);
        if (created) broadcast({ type: 'message', message });
        send(ws, { type: 'ack', requestId, message });
      } catch {
        send(ws, {
          type: 'error', requestId, message: 'No se pudo guardar el mensaje. Puedes volver a enviarlo.'
        });
      } finally {
        saving = false;
      }
    }

    ws.on('message', (data, binary) => {
      let packet;
      let file;
      try {
        if (!binary || ready) ({ packet, file } = decodePacket(data, binary));
      } catch {
        // Las tramas que no contienen JSON válido se rechazan abajo.
      }
      if (!receivedFirstFrame) {
        receivedFirstFrame = true;
        void authenticate(packet);
        return;
      }
      if (!ready || ws.readyState !== WebSocket.OPEN) return;
      if (expiresAt <= Date.now()) {
        ws.close(4408, 'Token vencido');
        return;
      }
      if (packet?.type === 'message') {
        void save(packet, file);
      } else if (!file && packet?.type === 'typing' && typeof packet.active === 'boolean') {
        updateTyping(user, ws, packet.active);
      } else {
        send(ws, { type: 'error', message: 'El formato del mensaje no es válido.' });
      }
    });

    ws.on('pong', () => { alive = true; });
    ws.on('error', () => ws.terminate());
    ws.on('close', () => {
      clearTimeout(authTimer);
      clearTimeout(expiryTimer);
      clearInterval(heartbeat);
      if (!user) return;
      user.sockets.delete(ws);
      stopTyping(user, ws);
      if (!user.sockets.size) {
        users.delete(user.uid);
        announce(user, 'leave');
      }
    });
  });
  return server;
}

module.exports = { createChatServer };
