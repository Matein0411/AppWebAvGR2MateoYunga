const { accessSync } = require('node:fs');
const { resolve } = require('node:path');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { createChatServer } = require('./chat-server');
const { attachmentStore } = require('./attachments');

function start() {
  try {
    process.loadEnvFile(resolve(__dirname, '.env'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }

  const port = Number(process.env.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT debe estar entre 1 y 65535.');
  }
  const allowedOrigins = new Set((process.env.ALLOWED_ORIGINS ?? 'http://localhost:3000')
    .split(',').map((origin) => origin.trim()).filter(Boolean));
  for (const origin of allowedOrigins) {
    if (!/^https?:\/\//.test(origin) || !URL.canParse(origin) || new URL(origin).origin !== origin) {
      throw new Error('ALLOWED_ORIGINS debe contener orígenes HTTP o HTTPS sin rutas ni barras finales.');
    }
  }
  if (!allowedOrigins.size) throw new Error('Configura al menos un origen en ALLOWED_ORIGINS.');

  const config = {
    apiKey: process.env.FIREBASE_API_KEY,
    authDomain: process.env.FIREBASE_AUTH_DOMAIN,
    projectId: process.env.FIREBASE_PROJECT_ID,
    appId: process.env.FIREBASE_APP_ID
  };
  if (Object.values(config).some((value) => !value?.trim())) {
    throw new Error('Configura FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, FIREBASE_PROJECT_ID y FIREBASE_APP_ID en .env.');
  }
  const authEmulator = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestoreEmulator = process.env.FIRESTORE_EMULATOR_HOST;
  if (authEmulator || firestoreEmulator) {
    const localHost = /^127\.0\.0\.1:[0-9]+$/;
    if (!config.projectId.startsWith('demo-') || !localHost.test(authEmulator) ||
        !localHost.test(firestoreEmulator) || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      throw new Error('Para los emuladores usa un proyecto demo-, ambos servicios en 127.0.0.1 y omite las credenciales.');
    }
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const credentialsPath = resolve(__dirname, process.env.GOOGLE_APPLICATION_CREDENTIALS);
    try {
      accessSync(credentialsPath);
    } catch {
      throw new Error('Revisa la ruta en GOOGLE_APPLICATION_CREDENTIALS.');
    }
    process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialsPath;
  }

  const firebase = initializeApp({ credential: applicationDefault(), projectId: config.projectId });
  const auth = getAuth(firebase);
  const messages = getFirestore(firebase).collection('messages');
  const attachments = attachmentStore(resolve(__dirname, process.env.ATTACHMENTS_DIR || 'uploads'));

  function historyMessage({ id, data }) {
    const { uid, name, text, timestamp, attachment, sticker } = data;
    return { id, uid, name, text, timestamp: timestamp.toDate().toISOString(),
      ...(attachment ? { attachment } : {}), ...(sticker ? { sticker } : {}) };
  }

  const server = createChatServer({
    config,
    authEmulator,
    allowedOrigins,
    verifyIdToken: (token) => auth.verifyIdToken(token),
    getUser: (uid) => auth.getUser(uid),
    attachmentPath: attachments.pathFor,
    async readAttachment(id) {
      return (await messages.doc(id).get()).data()?.attachment;
    },
    async readHistory() {
      const snapshot = await messages.orderBy('timestamp', 'desc').limit(50).get();
      return snapshot.docs.reverse().map((doc) => historyMessage({ id: doc.id, data: doc.data() }));
    },
    async saveMessage(message, file) {
      const ref = messages.doc(message.id);
      if (file) await attachments.write(message.id, message.attachment.digest, file);
      try {
        await ref.create({ ...message, timestamp: new Date(message.timestamp) });
        return { message, created: true };
      } catch (error) {
        if (error.code !== 6) throw error; // ALREADY_EXISTS: el envío anterior sí se guardó.
        const original = historyMessage({ id: ref.id, data: (await ref.get()).data() });
        if (original.uid !== message.uid || original.text !== message.text ||
            original.sticker !== message.sticker ||
            original.attachment?.digest !== message.attachment?.digest ||
            original.attachment?.name !== message.attachment?.name) throw error;
        return { message: original, created: false };
      }
    }
  });
  server.on('error', (error) => {
    console.error('No se pudo iniciar el servidor.', error.code ?? '');
    process.exitCode = 1;
  });
  server.listen(port, authEmulator ? '127.0.0.1' : undefined,
    () => console.log(`Chat disponible en http://localhost:${port}`));
}

try {
  start();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
