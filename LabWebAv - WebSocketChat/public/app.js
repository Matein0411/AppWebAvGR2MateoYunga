const byId = (id) => document.getElementById(id);
const themeButton = byId('theme-button');
const authPanel = byId('auth-panel');
const authFields = byId('auth-fields');
const authSwitch = byId('auth-switch');
const chatPanel = byId('chat-panel');
const timeline = byId('timeline');
const messages = byId('messages');
const input = byId('message-input');
const sendButton = byId('send');
const lengthLabel = byId('message-length');
const typingLabel = byId('typing');
const attachmentLimit = 8 * 1024 * 1024;
const attachments = new Set();
const greeting = '👋 ¡Hola a todos!';
const timeFormat = new Intl.DateTimeFormat(undefined, { timeStyle: 'short' });
const dateFormat = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' });
const seen = new Set();
const typingUsers = new Map();

let sdk;
let auth;
let authMode = 'login';
let authBusy = false;
let account;
let ownUid;
let socket;
let ready = false;
let connectionVersion = 0;
let reconnectTimer;
let reconnectDelay = 1000;
let lastTypingSent = 0;
let pending;
let retry;
let selectedFile;
let previewUrl;
let recording;
let microphonePending = false;

function setTheme(theme) {
  const dark = theme === 'dark';
  document.documentElement.dataset.theme = theme;
  document.querySelector('meta[name="theme-color"]').content = dark ? '#15131b' : '#f4f5fa';
  const action = dark ? 'Activar modo claro' : 'Activar modo oscuro';
  themeButton.setAttribute('aria-label', action);
  themeButton.title = action;
  byId('theme-sun').toggleAttribute('hidden', !dark);
  byId('theme-moon').toggleAttribute('hidden', dark);
}

let savedTheme;
try {
  savedTheme = localStorage.getItem('chat-epn-theme');
} catch {
  // El selector sigue disponible si el navegador bloquea el almacenamiento.
}
setTheme(savedTheme === 'light' ? 'light' : 'dark');
themeButton.addEventListener('click', () => {
  const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  setTheme(theme);
  try {
    localStorage.setItem('chat-epn-theme', theme);
  } catch {
    // Conserva el tema durante esta visita.
  }
});

function feedback(id, message = '') {
  const element = byId(id);
  element.textContent = message;
  element.hidden = !message;
}

function renderAuthForm(mode = authMode) {
  authMode = mode;
  const showName = mode !== 'login';
  const profileOnly = mode === 'profile';
  byId('auth-title').textContent = { login: 'Inicia sesión', register: 'Crea tu cuenta', profile: 'Completa tu perfil' }[mode];
  byId('auth-description').textContent = profileOnly
    ? 'Guarda un nombre visible para entrar a la sala general.'
    : 'Accede con tu cuenta para entrar a la sala general.';
  byId('auth-submit').textContent = { login: 'Iniciar sesión', register: 'Registrarse', profile: 'Guardar nombre' }[mode];
  byId('name-field').hidden = !showName;
  byId('display-name').disabled = !showName;
  byId('display-name').required = showName;
  for (const id of ['email', 'password']) {
    const field = byId(id);
    field.closest('label').hidden = profileOnly;
    field.disabled = profileOnly;
  }
  byId('password').autocomplete = mode === 'register' ? 'new-password' : 'current-password';
  authFields.disabled = authBusy || !auth;
  authSwitch.hidden = profileOnly;
  authSwitch.disabled = authBusy || !auth;
  authSwitch.textContent = mode === 'login' ? 'Crear una cuenta' : 'Ya tengo una cuenta';
  byId('cancel-profile').hidden = !profileOnly;
  byId('cancel-profile').disabled = authBusy;
}

function authError(error) {
  return {
    'auth/email-already-in-use': 'Ya existe una cuenta con ese correo.',
    'auth/invalid-email': 'Revisa el correo electrónico.',
    'auth/invalid-credential': 'El correo o la contraseña no coinciden.',
    'auth/weak-password': 'La contraseña debe tener al menos seis caracteres.',
    'auth/password-does-not-meet-requirements': 'La contraseña no cumple los requisitos del proyecto.',
    'auth/too-many-requests': 'Hay demasiados intentos. Vuelve a intentarlo más tarde.',
    'auth/network-request-failed': 'No se pudo contactar a Firebase. Revisa tu conexión.',
    'auth/operation-not-allowed': 'El inicio de sesión con correo y contraseña está deshabilitado en Firebase.'
  }[error.code] ?? 'No se pudo completar la operación. Vuelve a intentarlo.';
}

function stopConnection() {
  connectionVersion++;
  clearTimeout(reconnectTimer);
  if (socket) socket.close(1000);
  socket = undefined;
  reconnectDelay = 1000;
  lastTypingSent = 0;
  setStatus('offline');
}

function syncAccount(user) {
  if (authBusy) return;
  if (user?.uid && user.uid === account?.uid) return;
  stopConnection();
  account = undefined;
  ownUid = undefined;
  pending = undefined;
  retry = undefined;
  stopRecording(true);
  setAttachment();
  toggleEmoji(false);
  for (const url of attachments) URL.revokeObjectURL(url);
  attachments.clear();
  input.readOnly = false;
  seen.clear();
  messages.replaceChildren();
  typingUsers.clear();
  renderTyping();
  setPresence(0);
  byId('empty').hidden = true;
  input.value = '';
  updateLength();
  feedback('chat-message');

  const hasName = Boolean(user?.displayName?.trim());
  authPanel.hidden = hasName;
  chatPanel.hidden = !hasName;
  renderAuthForm(user && !hasName ? 'profile' : 'login');
  if (hasName) {
    account = user;
    byId('account-name').textContent = user.displayName;
    void connect();
  }
}

authSwitch.addEventListener('click', () => {
  feedback('auth-message');
  renderAuthForm(authMode === 'login' ? 'register' : 'login');
  byId(authMode === 'register' ? 'display-name' : 'email').focus();
});

byId('auth-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!auth || authBusy) return;
  const name = byId('display-name').value.trim();
  if (authMode !== 'login' && !name) {
    feedback('auth-message', 'Escribe un nombre visible.');
    return;
  }
  authBusy = true;
  renderAuthForm();
  feedback('auth-message');
  try {
    if (authMode === 'profile') {
      await sdk.updateProfile(auth.currentUser, { displayName: name });
    } else {
      const email = byId('email').value.trim();
      const password = byId('password').value;
      if (authMode === 'register') {
        const { user } = await sdk.createUserWithEmailAndPassword(auth, email, password);
        await sdk.updateProfile(user, { displayName: name });
      } else {
        await sdk.signInWithEmailAndPassword(auth, email, password);
      }
    }
    event.target.reset();
  } catch (error) {
    feedback('auth-message', authError(error));
  } finally {
    authBusy = false;
    renderAuthForm();
    if (auth.currentUser) syncAccount(auth.currentUser);
  }
});

async function logout() {
  if (authBusy) return;
  authBusy = true;
  byId('logout').disabled = true;
  renderAuthForm();
  stopConnection();
  stopRecording(true);
  if (pending) {
    retry = pending;
    pending = undefined;
    input.readOnly = false;
  }
  try {
    await sdk.signOut(auth);
    feedback('auth-message');
  } catch (error) {
    feedback(chatPanel.hidden ? 'auth-message' : 'chat-message', authError(error));
    if (account) void connect();
  } finally {
    authBusy = false;
    byId('logout').disabled = false;
    renderAuthForm();
    syncAccount(auth.currentUser);
  }
}
byId('logout').addEventListener('click', logout);
byId('cancel-profile').addEventListener('click', logout);

function setStatus(state) {
  const status = byId('connection');
  status.dataset.state = state;
  status.textContent = { online: 'Conectado', offline: 'Desconectado', reconnecting: 'Reconectando' }[state];
  ready = state === 'online';
  updateComposer();
}

function setPresence(count) {
  byId('presence').textContent = count === 1 ? '1 usuario en línea' : `${count} usuarios en línea`;
}

function renderTyping() {
  const names = Array.from(typingUsers.values());
  typingLabel.textContent = names.length === 1 ? `${names[0]} está escribiendo…`
    : names.length > 1 ? `${new Intl.ListFormat('es').format(names)} están escribiendo…` : '';
}

function addToTimeline(row, timestamp, id = '') {
  row.dataset.timestamp = timestamp;
  row.dataset.id = id;
  let previous = messages.lastElementChild;
  while (previous && (previous.dataset.timestamp > timestamp ||
    (previous.dataset.timestamp === timestamp && previous.dataset.id > id))) {
    previous = previous.previousElementSibling;
  }
  messages.insertBefore(row, previous ? previous.nextSibling : messages.firstChild);
}

function renderAttachment({ id, attachment }) {
  const holder = document.createElement('div');
  holder.className = 'message-attachment';
  const download = document.createElement('button');
  download.type = 'button';
  download.className = 'attachment-download';
  download.textContent = `↓ ${attachment.name}`;
  download.title = 'Descargar adjunto';
  let fileRequest;
  function getFile() {
    if (fileRequest) return fileRequest;
    const owner = account;
    fileRequest = (async () => {
      const token = await owner.getIdToken();
      const response = await fetch(`/attachments/${id}`, { headers: { Authorization: `Bearer ${token}` } });
      if (!response.ok) throw new Error('Adjunto no disponible');
      const blob = await response.blob();
      if (account !== owner) throw new Error('Cambió la sesión');
      const url = URL.createObjectURL(blob);
      attachments.add(url);
      return url;
    })().catch((error) => {
      fileRequest = undefined;
      throw error;
    });
    return fileRequest;
  }

  download.addEventListener('click', async () => {
    download.disabled = true;
    try {
      const link = document.createElement('a');
      link.href = await getFile();
      link.download = attachment.name;
      link.click();
    } catch {
      if (holder.isConnected) feedback('chat-message', 'No se pudo descargar el archivo.');
    } finally {
      download.disabled = false;
    }
  });

  if (attachment.kind === 'image' || attachment.kind === 'audio') {
    const media = document.createElement(attachment.kind === 'image' ? 'img' : 'audio');
    if (attachment.kind === 'image') {
      media.alt = attachment.name;
    } else {
      media.preload = 'metadata';
      media.controls = true;
      media.setAttribute('aria-label', attachment.name);
    }
    holder.append(media);
    media.addEventListener('error', () => media.remove());
    const observer = new IntersectionObserver(([entry]) => {
      if (!holder.isConnected) { observer.disconnect(); return; }
      if (!entry.isIntersecting) return;
      observer.disconnect();
      const scrollAtEnd = timeline.scrollHeight - timeline.scrollTop - timeline.clientHeight < 65;
      media.addEventListener('load', () => {
        if (scrollAtEnd) timeline.scrollTop = timeline.scrollHeight;
      }, { once: true });
      void getFile().then((url) => { media.src = url; }).catch(() => media.remove());
    }, { root: timeline, rootMargin: '160px' });
    observer.observe(holder);
  }
  holder.append(download);
  return holder;
}

function addMessage(message) {
  if (seen.has(message.id)) return;
  seen.add(message.id);
  byId('empty').hidden = true;
  const row = document.createElement('li');
  row.className = 'message';
  if (message.uid === ownUid) {
    row.classList.add('own');
    row.setAttribute('aria-label', 'Tu mensaje');
  } else {
    const author = document.createElement('strong');
    author.className = 'message-author';
    author.textContent = message.name;
    row.append(author);
  }
  if (message.attachment) row.append(renderAttachment(message));
  if (message.sticker === 'greeting') {
    row.classList.add('greeting-message');
    const sticker = document.createElement('img');
    sticker.src = './greeting.png';
    sticker.alt = greeting;
    row.append(sticker);
  } else if (message.text) {
    const body = document.createElement('p');
    body.textContent = message.text;
    row.append(body);
  }
  const date = new Date(message.timestamp);
  const time = document.createElement('time');
  time.dateTime = message.timestamp;
  time.textContent = timeFormat.format(date);
  time.title = dateFormat.format(date);
  row.append(time);
  addToTimeline(row, message.timestamp, message.id);
}

function handlePacket(packet) {
  const nearBottom = timeline.scrollHeight - timeline.scrollTop - timeline.clientHeight < 60;
  if (packet.type === 'ready') {
    ownUid = packet.uid;
    byId('account-name').textContent = packet.name;
    packet.history.forEach(addMessage);
    byId('empty').hidden = seen.size !== 0;
    setPresence(packet.count);
    typingUsers.clear();
    packet.typing.forEach(({ uid, name }) => typingUsers.set(uid, name));
    renderTyping();
    reconnectDelay = 1000;
    if (!retry) feedback('chat-message');
    setStatus('online');
  } else if (packet.type === 'message') {
    addMessage(packet.message);
  } else if (packet.type === 'ack' && pending?.id === packet.requestId) {
    addMessage(packet.message);
    input.value = '';
    pending = undefined;
    retry = undefined;
    input.readOnly = false;
    setAttachment();
    feedback('chat-message');
    updateLength();
  } else if (packet.type === 'error') {
    if (pending && pending.id === packet.requestId) {
      retry = pending;
      pending = undefined;
      input.readOnly = false;
      updateComposer();
    }
    feedback('chat-message', packet.message);
  } else if (packet.type === 'presence') {
    setPresence(packet.count);
    const notice = document.createElement('li');
    notice.className = 'notice';
    notice.textContent = `${packet.name} ${packet.action === 'join' ? 'entró a' : 'salió de'} la sala.`;
    addToTimeline(notice, packet.timestamp);
  } else if (packet.type === 'typing') {
    if (packet.active) typingUsers.set(packet.uid, packet.name);
    else typingUsers.delete(packet.uid);
    renderTyping();
  }
  if (nearBottom || packet.type === 'ack') timeline.scrollTop = timeline.scrollHeight;
}

function scheduleReconnect(forceRefresh = false) {
  if (!account) return;
  setStatus('offline');
  reconnectTimer = setTimeout(() => void connect(forceRefresh), reconnectDelay);
  reconnectDelay = Math.min(reconnectDelay * 2, 15000);
}

async function connect(forceRefresh = false) {
  if (!account) return;
  const version = ++connectionVersion;
  setStatus('reconnecting');
  ownUid = account.uid;
  let token;
  try {
    token = await account.getIdToken(forceRefresh);
  } catch (error) {
    if (connectionVersion !== version) return;
    feedback('chat-message', authError(error));
    scheduleReconnect(forceRefresh);
    return;
  }
  if (connectionVersion !== version) return;
  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const current = new WebSocket(`${protocol}//${location.host}/ws`);
  socket = current;
  current.addEventListener('open', () => {
    if (connectionVersion === version) current.send(JSON.stringify({ type: 'auth', token }));
    token = undefined;
  });
  current.addEventListener('message', (event) => {
    if (connectionVersion === version) handlePacket(JSON.parse(event.data));
  });
  current.addEventListener('close', ({ code }) => {
    token = undefined;
    if (connectionVersion !== version) return;
    socket = undefined;
    typingUsers.clear();
    renderTyping();
    setPresence(0);
    lastTypingSent = 0;
    if (pending) {
      retry = pending;
      pending = undefined;
      input.readOnly = false;
      feedback('chat-message', 'Se perdió la confirmación. Puedes volver a enviar el mensaje.');
    }
    if (code === 4403 || (code === 4401 && forceRefresh)) {
      setStatus('offline');
      feedback('chat-message', 'No se pudo autenticar la conexión. Cierra sesión y vuelve a iniciarla.');
      return;
    }
    scheduleReconnect(code === 4408 || code === 4401);
  });
}

function updateLength() {
  const length = Array.from(input.value.trim()).length;
  lengthLabel.textContent = `${length} / 500`;
  lengthLabel.classList.toggle('over-limit', length > 500);
  updateComposer();
  return length;
}

function updateComposer() {
  const locked = Boolean(pending || recording || microphonePending);
  const hasDraft = Boolean(input.value.trim() || selectedFile);
  sendButton.hidden = !hasDraft || Boolean(recording);
  sendButton.disabled = !ready || locked;
  byId('record').hidden = hasDraft && !recording;
  byId('record').disabled = !ready || microphonePending || Boolean(pending);
  byId('attach').disabled = !ready || locked;
  byId('emoji').disabled = !ready || locked;
  if (!ready || locked) toggleEmoji(false);
  byId('remove-attachment').disabled = locked;
  byId('say-hello').disabled = !ready || locked || hasDraft;
  input.readOnly = locked;
}

function setAttachment(file) {
  if (file && (!file.size || file.size > attachmentLimit || file.name.length > 180)) {
    feedback('chat-message', 'Elige un archivo de hasta 8 MB con un nombre de hasta 180 caracteres.');
    return;
  }
  selectedFile = file;
  if (previewUrl) URL.revokeObjectURL(previewUrl);
  previewUrl = undefined;
  const preview = byId('attachment-preview');
  preview.replaceChildren();
  if (file?.type.startsWith('audio/') || /^image\/(png|jpeg|gif|webp)$/.test(file?.type)) {
    const audio = file.type.startsWith('audio/');
    const media = document.createElement(audio ? 'audio' : 'img');
    if (audio) {
      media.controls = true;
      media.setAttribute('aria-label', 'Vista previa del audio');
    } else {
      media.alt = 'Vista previa de la imagen';
    }
    previewUrl = URL.createObjectURL(file);
    media.src = previewUrl;
    preview.append(media);
  }
  byId('attachment-label').textContent = file?.name ?? '';
  byId('attachment-draft').hidden = !file;
  byId('file-input').value = '';
  updateComposer();
}

function toggleEmoji(open) {
  byId('emoji-picker').hidden = !open;
  byId('emoji').setAttribute('aria-expanded', String(open));
}

function stopRecording(discard = false) {
  if (!recording) return;
  recording.discard ||= discard;
  if (recording.recorder.state !== 'inactive') recording.recorder.stop();
  if (discard) recording.stream.getTracks().forEach((track) => track.stop());
}

async function startRecording() {
  if (recording) { stopRecording(); return; }
  if (!navigator.mediaDevices?.getUserMedia || !globalThis.MediaRecorder) {
    feedback('chat-message', 'Para grabar audio, abre el chat en localhost o mediante HTTPS con un navegador compatible.');
    return;
  }
  const owner = account;
  const version = connectionVersion;
  microphonePending = true;
  updateComposer();
  let stream;
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    if (owner !== account || version !== connectionVersion || !ready) {
      stream.getTracks().forEach((track) => track.stop());
      return;
    }
    const supported = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus']
      .find((type) => MediaRecorder.isTypeSupported(type));
    const recorder = supported ? new MediaRecorder(stream, { mimeType: supported }) : new MediaRecorder(stream);
    const take = { stream, recorder, discard: false };
    const chunks = [];
    recorder.addEventListener('dataavailable', ({ data }) => { if (data.size) chunks.push(data); });
    recorder.addEventListener('error', () => {
      take.discard = true;
      if (account === owner) feedback('chat-message', 'No se pudo terminar la grabación.');
    });
    recorder.addEventListener('stop', () => {
      clearTimeout(take.timeout);
      stream.getTracks().forEach((track) => track.stop());
      recording = undefined;
      byId('recording').hidden = true;
      byId('record').setAttribute('aria-label', 'Grabar nota de voz');
      byId('record').title = 'Grabar nota de voz';
      if (!take.discard && account === owner) {
        const mime = (recorder.mimeType || chunks[0]?.type || 'audio/webm').split(';')[0];
        const extension = { 'audio/mp4': 'm4a', 'audio/ogg': 'ogg', 'audio/webm': 'webm' }[mime] ?? 'audio';
        const file = new File(chunks, `Nota de voz.${extension}`, { type: mime });
        setAttachment(file);
      }
      updateComposer();
    });
    recorder.start(250);
    recording = take;
    take.timeout = setTimeout(() => stopRecording(), 120000);
    byId('recording').hidden = false;
    byId('record').setAttribute('aria-label', 'Detener grabación');
    byId('record').title = 'Detener grabación';
    feedback('chat-message');
  } catch {
    stream?.getTracks().forEach((track) => track.stop());
    if (account === owner) feedback('chat-message', 'No se pudo acceder al micrófono. Revisa los permisos del navegador.');
  } finally {
    microphonePending = false;
    updateComposer();
  }
}

for (const symbol of '😀 😂 🥹 😍 😎 🤔 😅 😭 😴 🤩 🙌 👋 👍 👏 💜 ❤️ 🔥 ✨ 🎉 🚀 🫶 ✅ 💯 👀 🐱 🌙 ☕ 📚 🎧'.split(' ')) {
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = symbol;
  button.addEventListener('click', () => {
    input.setRangeText(symbol, input.selectionStart, input.selectionEnd, 'end');
    input.dispatchEvent(new Event('input'));
    toggleEmoji(false);
    input.focus();
  });
  byId('emoji-picker').append(button);
}
byId('emoji').addEventListener('click', () => toggleEmoji(byId('emoji-picker').hidden));
document.addEventListener('click', (event) => {
  if (!event.target.closest('#emoji, #emoji-picker')) toggleEmoji(false);
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && !byId('emoji-picker').hidden) {
    toggleEmoji(false);
    byId('emoji').focus();
  }
});
byId('attach').addEventListener('click', () => byId('file-input').click());
byId('file-input').addEventListener('change', (event) => {
  const [file] = event.target.files;
  if (file) setAttachment(file);
  event.target.value = '';
});
byId('remove-attachment').addEventListener('click', () => setAttachment());
byId('record').addEventListener('click', () => void startRecording());
byId('cancel-recording').addEventListener('click', () => stopRecording(true));
byId('say-hello').addEventListener('click', () => {
  if (byId('say-hello').disabled) return;
  submitDraft(true);
});

function send(packet, file) {
  if (!ready || socket?.readyState !== WebSocket.OPEN) return false;
  const json = JSON.stringify(packet);
  socket.send(file ? new Blob([json, '\n', file]) : json);
  return true;
}

input.addEventListener('input', () => {
  const length = updateLength();
  if (!length) {
    if (lastTypingSent) send({ type: 'typing', active: false });
    lastTypingSent = 0;
  } else if (Date.now() - lastTypingSent >= 900 && send({ type: 'typing', active: true })) {
    lastTypingSent = Date.now();
  }
});

byId('message-form').addEventListener('submit', (event) => {
  event.preventDefault();
  submitDraft();
});

function submitDraft(sticker = false) {
  if (!ready || pending || recording || microphonePending) return;
  const length = updateLength();
  if ((!selectedFile && !sticker && length < 1) || length > 500) {
    feedback('chat-message', 'Escribe un mensaje de 1 a 500 caracteres.');
    input.focus();
    return;
  }
  const text = input.value.trim();
  const file = selectedFile;
  const id = retry?.text === text && retry.file === file && retry.sticker === sticker ? retry.id : Array.from(
    crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, '0')
  ).join('');
  const packet = { type: 'message', text, id };
  if (sticker) packet.sticker = 'greeting';
  if (file) Object.assign(packet, { filename: file.name, mime: file.type.split(';')[0] });
  if (!send(packet, file)) return;
  pending = { id, text, file, sticker };
  input.readOnly = true;
  updateComposer();
  lastTypingSent = 0;
  feedback('chat-message');
  input.focus();
}

async function initialize() {
  if (location.protocol === 'file:') {
    feedback('auth-message', 'Para iniciar sesión, ejecuta npm start y abre http://localhost:3000.');
    return;
  }
  try {
    const [response, { initializeApp }, authSdk] = await Promise.all([
      fetch('/firebase-config.json'),
      import('https://www.gstatic.com/firebasejs/13.3.0/firebase-app.js'),
      import('https://www.gstatic.com/firebasejs/13.3.0/firebase-auth.js')
    ]);
    if (!response.ok) throw new Error('Configuración no disponible');
    sdk = authSdk;
    const { firebase, authEmulator } = await response.json();
    auth = sdk.getAuth(initializeApp(firebase));
    if (authEmulator) sdk.connectAuthEmulator(auth, `http://${authEmulator}`, { disableWarnings: true });
    sdk.onAuthStateChanged(auth, syncAccount);
  } catch {
    feedback('auth-message', 'No se pudo iniciar Firebase. Revisa la conexión y la configuración del servidor.');
  }
}

void initialize();
