'use strict';
/* neirox desktop — веб-клиент на том же Supabase, что и приложения для iPhone и Android */

const SB_URL = 'https://seimbpskeemozcibybsy.supabase.co';
const SB_KEY = 'sb_publishable_h5MfmS1nk907f6_1gwjm-Q_7JsUwDpI';
const VERSION = new URLSearchParams(location.search).get('v') || 'web';
const MAX_FILE = 25 * 1024 * 1024;

const $ = (s, r) => (r || document).querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const lsGet = (k, d) => { try { const v = localStorage.getItem(k); return v == null ? d : v; } catch (e) { return d; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch (e) { } };

/* ---------- настройки ---------- */
const ACCENTS = ['#4AA8FF', '#9B6BFF', '#35E0B4', '#FF6BB5', '#FF8A4A', '#FFD24A', '#4AE0E0', '#7CFF6B', '#FF5C5C', '#B06BFF', '#6B8BFF', '#E06BFF'];
const S = {
  lang: lsGet('s.lang', 'ru'),
  mode: lsGet('s.mode', 'dark'),
  size: lsGet('s.size', 'medium'),
  accent: lsGet('s.accent', '#4AA8FF'),
  sound: lsGet('s.sound', '1') === '1'
};
function t(ru, en, de) { return S.lang === 'en' ? en : S.lang === 'de' ? de : ru; }
function applyTheme() {
  const r = document.documentElement;
  r.dataset.mode = S.mode;
  r.style.setProperty('--accent', S.accent);
  const n = parseInt(S.accent.slice(1), 16);
  r.style.setProperty('--accent-rgb', [(n >> 16) & 255, (n >> 8) & 255, n & 255].join(','));
  r.style.fontSize = { small: '14px', medium: '16px', large: '19px' }[S.size] || '16px';
}
function saveSettings() {
  lsSet('s.lang', S.lang); lsSet('s.mode', S.mode); lsSet('s.size', S.size);
  lsSet('s.accent', S.accent); lsSet('s.sound', S.sound ? '1' : '0');
  applyTheme();
}

/* ---------- API ---------- */
let session = null;
try { session = JSON.parse(lsGet('neirox.session', 'null')); } catch (e) { }
function setSession(s) {
  session = s;
  if (s) lsSet('neirox.session', JSON.stringify(s)); else { try { localStorage.removeItem('neirox.session'); } catch (e) { } }
}
const fakeEmail = n => n.toLowerCase() + '@neirox.app';
const myId = () => (session ? session.userId : '');

function extractError(text, code) {
  try {
    const o = JSON.parse(text);
    for (const k of ['error', 'msg', 'message', 'error_description', 'detail']) {
      if (typeof o[k] === 'string' && o[k]) return o[k];
    }
  } catch (e) { }
  return 'HTTP ' + code;
}

function friendly(e) {
  const raw = (e && e.message) || String(e || '');
  const s = raw.toLowerCase();
  if (s.includes('invalid login') || s.includes('invalid_credentials')) return t('Неверный ник или пароль', 'Wrong nick or password', 'Nick oder Passwort falsch');
  if (s.includes('nick_taken')) return t('Этот ник уже занят', 'This nick is taken', 'Dieser Nick ist vergeben');
  if (s.includes('email_taken')) return t('Эта почта уже привязана к другому аккаунту', 'This email is already used', 'Diese E-Mail wird bereits verwendet');
  if (s.includes('bad_nick')) return t('Ник: 3–20 символов, только a–z, цифры и _', 'Nick: 3–20 chars, a–z, digits and _', 'Nick: 3–20 Zeichen, a–z, Ziffern und _');
  if (s.includes('bad_password')) return t('Пароль: минимум 6 символов', 'Password: at least 6 characters', 'Passwort: mindestens 6 Zeichen');
  if (s.includes('bad_code')) return t('Неверный или просроченный код', 'Wrong or expired code', 'Code falsch oder abgelaufen');
  if (s.includes('too_many')) return t('Слишком много попыток, попробуй через час', 'Too many attempts, try again in an hour', 'Zu viele Versuche, versuche es in einer Stunde erneut');
  if (s.includes('mail_failed') || s.includes('mail_not_configured')) return t('Не удалось отправить письмо, попробуй позже', 'Could not send the email, try later', 'E-Mail konnte nicht gesendet werden');
  if (s.includes('no_profile')) return t('Профиль не найден', 'Profile not found', 'Profil nicht gefunden');
  if (s.includes('bad_email')) return t('Проверь адрес почты', 'Check the email address', 'E-Mail prüfen');
  if (s.includes('rate_limited')) return t('Лимит запросов в час исчерпан, попробуй позже', 'Hourly limit reached, try later', 'Stundenlimit erreicht, versuche es später');
  if (s === 'network' || s.includes('failed to fetch') || s.includes('network')) return t('Нет связи с сервером', 'No connection to server', 'Keine Verbindung zum Server');
  return raw;
}

let refreshing = false;
async function refreshIfNeeded() {
  if (!session || refreshing || session.expiresAt - Date.now() > 60000) return;
  refreshing = true;
  try {
    const txt = await raw('POST', '/auth/v1/token', { query: { grant_type: 'refresh_token' }, json: { refresh_token: session.refreshToken }, auth: false });
    setSession(parseSession(txt));
  } catch (e) {
    const m = String(e.message).toLowerCase();
    if (m.includes('refresh') || m.includes('invalid')) { setSession(null); showAuth(); }
    throw e;
  } finally { refreshing = false; }
}
function parseSession(txt) {
  const o = JSON.parse(txt);
  if (!o.access_token || !o.user) throw new Error('Bad auth response');
  return { accessToken: o.access_token, refreshToken: o.refresh_token, userId: o.user.id, expiresAt: Date.now() + (o.expires_in || 3600) * 1000 };
}

async function raw(method, path, o) {
  o = o || {};
  if (o.auth !== false) await refreshIfNeeded();
  let url = SB_URL + path;
  if (o.query) url += '?' + new URLSearchParams(o.query).toString();
  const h = Object.assign({ apikey: SB_KEY }, o.headers || {});
  if (o.auth !== false && session) h.Authorization = 'Bearer ' + session.accessToken;
  let body;
  if (o.json !== undefined) { body = JSON.stringify(o.json); h['Content-Type'] = 'application/json'; }
  else if (o.body) { body = o.body; h['Content-Type'] = o.contentType || 'application/octet-stream'; }
  let res;
  try { res = await fetch(url, { method, headers: h, body }); } catch (e) { throw new Error('network'); }
  const text = await res.text();
  if (res.ok) return text;
  throw new Error(extractError(text, res.status));
}
const sel = async (table, query) => JSON.parse(await raw('GET', '/rest/v1/' + table, { query }) || '[]');
const ins = (table, row) => raw('POST', '/rest/v1/' + table, { json: row, headers: { Prefer: 'return=minimal' } });
const upd = (table, query, values) => raw('PATCH', '/rest/v1/' + table, { query, json: values, headers: { Prefer: 'return=minimal' } });
const del = (table, query) => raw('DELETE', '/rest/v1/' + table, { query });

async function signIn(nick, password) {
  const txt = await raw('POST', '/auth/v1/token', { query: { grant_type: 'password' }, json: { email: fakeEmail(nick), password }, auth: false });
  setSession(parseSession(txt));
}
async function register(nick, password, email) {
  const body = { nick, password };
  if (email) body.email = email;
  await raw('POST', '/functions/v1/register', { json: body, auth: false });
}

const urlCache = {};
async function signedUrl(path) {
  const c = urlCache[path];
  if (c && c.exp > Date.now()) return c.url;
  const o = JSON.parse(await raw('POST', '/storage/v1/object/sign/chat-media/' + path, { json: { expiresIn: 3600 } }));
  const url = SB_URL + '/storage/v1' + o.signedURL;
  urlCache[path] = { url, exp: Date.now() + 50 * 60000 };
  return url;
}
const publicUrl = (bucket, path) => SB_URL + '/storage/v1/object/public/' + bucket + '/' + path;
async function uploadFile(bucket, path, blob, mime, upsert) {
  await raw('POST', '/storage/v1/object/' + bucket + '/' + path, { body: blob, contentType: mime, headers: { 'x-upsert': upsert ? 'true' : 'false' } });
}
async function aiText(messages) {
  const o = JSON.parse(await raw('POST', '/functions/v1/ai', { json: { type: 'text', messages } }));
  if (!o.text) throw new Error('Empty AI answer');
  return o.text;
}
async function aiImage(prompt) {
  const o = JSON.parse(await raw('POST', '/functions/v1/ai', { json: { type: 'image', prompt } }));
  if (!o.base64) throw new Error('Empty AI image');
  const bin = atob(o.base64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return new Blob([arr], { type: 'image/jpeg' });
}

/* ---------- данные ---------- */
const D = { me: null, friendships: [], profiles: {}, messages: [], hidden: new Set(), email: null, loaded: false };
let knownIds = new Set();
let firstLoadDone = false;
let timer = null;

async function refresh() {
  if (!session) return;
  try {
    const me = await sel('profiles', { id: 'eq.' + myId(), select: '*' });
    D.me = me[0] || null;
    D.friendships = await sel('friendships', { select: '*' });
    const msgs = await sel('messages', { select: '*', order: 'created_at.desc', limit: '1000' });
    try { D.hidden = new Set((await sel('message_hidden', { select: 'message_id' })).map(r => r.message_id)); } catch (e) { }
    notifyNew(msgs);
    D.messages = msgs.filter(m => !D.hidden.has(m.id)).reverse();
    const ids = new Set();
    D.friendships.forEach(f => { ids.add(f.requester); ids.add(f.addressee); });
    msgs.forEach(m => { ids.add(m.sender); ids.add(m.receiver); });
    ids.delete(myId());
    if (ids.size) {
      const ps = await sel('profiles', { id: 'in.(' + Array.from(ids).join(',') + ')', select: '*' });
      ps.forEach(p => { D.profiles[p.id] = p; });
    }
    if (D.me) D.profiles[D.me.id] = D.me;
    D.loaded = true;
    if (D.email === null) {
      try { const pp = await sel('private_profiles', { user_id: 'eq.' + myId(), select: '*' }); D.email = pp[0] ? pp[0].recovery_email : ''; } catch (e) { }
    }
    upd('profiles', { id: 'eq.' + myId() }, { last_seen: new Date().toISOString() }).catch(() => { });
  } catch (e) {
    if (!session) return;
  }
  renderAll();
  markReadIfOpen();
}

function notifyNew(msgs) {
  const ids = new Set(msgs.map(m => m.id));
  if (firstLoadDone) {
    const fresh = msgs.filter(m => !knownIds.has(m.id) && m.receiver === myId());
    if (fresh.length) {
      if (S.sound) beep();
      if (!document.hasFocus() && 'Notification' in window) {
        try {
          const p = D.profiles[fresh[0].sender];
          const body = fresh[0].kind === 'text' ? fresh[0].body : (fresh[0].kind === 'image' ? '📷' : '📎 ' + (fresh[0].file_name || ''));
          if (Notification.permission === 'granted') new Notification(p ? p.nick : 'neirox', { body });
          else if (Notification.permission === 'default') Notification.requestPermission();
        } catch (e) { }
      }
    }
  }
  knownIds = ids;
  firstLoadDone = true;
}
let actx = null;
function beep() {
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    const o = actx.createOscillator(), g = actx.createGain();
    o.type = 'sine'; o.frequency.value = 880;
    g.gain.setValueAtTime(.12, actx.currentTime);
    g.gain.exponentialRampToValueAtTime(.001, actx.currentTime + .25);
    o.connect(g); g.connect(actx.destination);
    o.start(); o.stop(actx.currentTime + .25);
  } catch (e) { }
}

const friendIds = () => D.friendships.filter(f => f.status === 'accepted').map(f => f.requester === myId() ? f.addressee : f.requester);
const incoming = () => D.friendships.filter(f => f.status === 'pending' && f.addressee === myId());
const outgoing = () => D.friendships.filter(f => f.status === 'pending' && f.requester === myId());
const friendshipWith = id => D.friendships.find(f => (f.requester === id && f.addressee === myId()) || (f.requester === myId() && f.addressee === id));
const thread = id => D.messages.filter(m => (m.sender === id && m.receiver === myId()) || (m.sender === myId() && m.receiver === id));
const unread = id => D.messages.filter(m => m.sender === id && m.receiver === myId() && !m.read_at).length;
const totalUnread = () => friendIds().reduce((a, id) => a + unread(id), 0);

async function markReadIfOpen() {
  const id = U.chat;
  if (!id || id === 'ai' || !unread(id)) return;
  try {
    await upd('messages', { sender: 'eq.' + id, receiver: 'eq.' + myId(), read_at: 'is.null' }, { read_at: new Date().toISOString() });
    D.messages.forEach(m => { if (m.sender === id && m.receiver === myId() && !m.read_at) m.read_at = new Date().toISOString(); });
    renderAll();
  } catch (e) { }
}

/* ---------- сообщения: операции ---------- */
async function sendText(text, to) {
  await ins('messages', { sender: myId(), receiver: to, kind: 'text', body: text });
  await refresh();
}
async function sendMedia(blob, mime, fileName, kind, to) {
  const ext = (fileName.split('.').pop() || '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8);
  const path = myId() + '/' + crypto.randomUUID() + (ext && ext !== fileName ? '.' + ext : '');
  await uploadFile('chat-media', path, blob, mime, false);
  await ins('messages', { sender: myId(), receiver: to, kind, media_path: path, file_name: fileName });
  await refresh();
}
async function editMessage(id, text) {
  await upd('messages', { id: 'eq.' + id }, { body: text, edited_at: new Date().toISOString() });
  await refresh();
}
async function deleteForAll(list) {
  for (const m of list) {
    if (m.sender !== myId()) continue;
    await del('messages', { id: 'eq.' + m.id });
    if (m.media_path) raw('DELETE', '/storage/v1/object/chat-media/' + m.media_path).catch(() => { });
  }
  await refresh();
}
async function deleteForMe(list) {
  for (const m of list) { await ins('message_hidden', { message_id: m.id }); D.hidden.add(m.id); }
  D.messages = D.messages.filter(m => !D.hidden.has(m.id));
  await refresh();
}
async function forwardMsg(m, to) {
  if (m.kind === 'text') { await sendText(m.body || '', to); return; }
  if (!m.media_path) return;
  const blob = await (await fetch(await signedUrl(m.media_path))).blob();
  const name = m.file_name || (m.kind === 'image' ? 'photo.jpg' : 'file');
  await sendMedia(blob, m.kind === 'image' ? 'image/jpeg' : (blob.type || 'application/octet-stream'), name, m.kind, to);
}
function compress(file) {
  return new Promise((res, rej) => {
    const img = new Image();
    const u = URL.createObjectURL(file);
    img.onload = () => {
      const sc = Math.min(1, 1600 / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * sc); c.height = Math.round(img.height * sc);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(u);
      c.toBlob(b => b ? res(b) : rej(new Error('Bad image')), 'image/jpeg', .8);
    };
    img.onerror = () => rej(new Error('Bad image'));
    img.src = u;
  });
}

/* ---------- UI-состояние ---------- */
const U = { tab: 'chats', chat: null, selected: new Set(), editing: null, error: '', busy: false, query: '', results: [], aiImageMode: false, authScreen: 'login', authErr: '', authBusy: false };
const A = { msgs: [], images: {}, busy: false, err: '' };
try { A.msgs = JSON.parse(lsGet('neirox.ai.history', '[]')); } catch (e) { A.msgs = []; }
const P = { tracks: [], cur: -1, playing: false };

function toast(text) {
  const el = $('#toast');
  el.textContent = text; el.classList.remove('hidden');
  clearTimeout(toast.t);
  toast.t = setTimeout(() => el.classList.add('hidden'), 2000);
}
function setHTML(el, html) {
  if (!el) return;
  if (el._h === html) return;
  el._h = html;
  el.innerHTML = html;
}
function timeOf(iso) {
  try { return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); } catch (e) { return ''; }
}
function avatarHtml(p, size) {
  const nick = p ? p.nick : '?';
  const st = 'width:' + size + 'px;height:' + size + 'px;font-size:' + Math.round(size * .42) + 'px;';
  if (p && p.avatar_url) return '<div class="avatar" style="' + st + '"><img src="' + esc(p.avatar_url) + '" alt=""></div>';
  let h = 0; for (const c of nick) h = (h * 31 + c.charCodeAt(0)) % 360;
  return '<div class="avatar" style="' + st + 'background:linear-gradient(135deg,hsl(' + h + ',70%,55%),hsl(' + ((h + 60) % 360) + ',70%,50%))">' + esc(nick.slice(0, 1).toUpperCase()) + '</div>';
}

/* ---------- авторизация ---------- */
function showAuth() {
  $('#app').classList.add('hidden');
  $('#auth').classList.remove('hidden');
  if (timer) { clearInterval(timer); timer = null; }
  renderAuth();
}
function renderAuth() {
  const sc = U.authScreen;
  const err = U.authErr ? '<div class="err">' + esc(U.authErr) + '</div>' : '';
  const lang = '<div class="seg" style="margin:0 auto">' + ['ru', 'en', 'de'].map(l => '<button data-act="lang" data-v="' + l + '" class="' + (S.lang === l ? 'on' : '') + '">' + l.toUpperCase() + '</button>').join('') + '</div>';
  let body = '';
  if (sc === 'login') {
    body = '<input class="field" id="a-nick" placeholder="' + t('Ник', 'Nick', 'Nick') + '" autocomplete="username">' +
      '<input class="field" id="a-pass" type="password" placeholder="' + t('Пароль', 'Password', 'Passwort') + '" autocomplete="current-password">' + err +
      '<button class="btn full" data-act="login" ' + (U.authBusy ? 'disabled' : '') + '>' + t('Войти', 'Sign in', 'Anmelden') + '</button>' +
      '<button class="link" data-act="auth-go" data-v="register">' + t('Создать аккаунт', 'Create account', 'Konto erstellen') + '</button>' +
      '<button class="link" data-act="auth-go" data-v="recover">' + t('Забыл пароль?', 'Forgot password?', 'Passwort vergessen?') + '</button>';
  } else if (sc === 'register') {
    body = '<input class="field" id="a-nick" placeholder="' + t('Ник (a–z, цифры, _)', 'Nick (a–z, digits, _)', 'Nick (a–z, Ziffern, _)') + '">' +
      '<input class="field" id="a-pass" type="password" placeholder="' + t('Пароль (от 6 символов)', 'Password (6+ chars)', 'Passwort (ab 6 Zeichen)') + '">' +
      '<input class="field" id="a-mail" placeholder="' + t('Почта для восстановления (необязательно)', 'Recovery email (optional)', 'Wiederherstellungs-E-Mail (optional)') + '">' + err +
      '<button class="btn full" data-act="register" ' + (U.authBusy ? 'disabled' : '') + '>' + t('Создать аккаунт', 'Create account', 'Konto erstellen') + '</button>' +
      '<button class="link" data-act="auth-go" data-v="login">' + t('Уже есть аккаунт? Войти', 'Have an account? Sign in', 'Schon ein Konto? Anmelden') + '</button>';
  } else if (sc === 'recover') {
    body = '<div class="muted" style="font-size:14px">' + t('Код придёт на почту, привязанную к аккаунту.', 'The code is sent to the email bound to the account.', 'Der Code wird an die verknüpfte E-Mail gesendet.') + '</div>' +
      '<input class="field" id="a-nick" placeholder="' + t('Ник', 'Nick', 'Nick') + '">' + err +
      '<button class="btn full" data-act="recover-req" ' + (U.authBusy ? 'disabled' : '') + '>' + t('Отправить код', 'Send code', 'Code senden') + '</button>' +
      '<button class="link" data-act="auth-go" data-v="login">' + t('Назад', 'Back', 'Zurück') + '</button>';
  } else if (sc === 'recover2') {
    body = '<input class="field" id="a-code" placeholder="' + t('Код из письма', 'Code from email', 'Code aus der E-Mail') + '">' +
      '<input class="field" id="a-pass" type="password" placeholder="' + t('Новый пароль', 'New password', 'Neues Passwort') + '">' + err +
      '<button class="btn full" data-act="recover-ok" ' + (U.authBusy ? 'disabled' : '') + '>' + t('Сменить пароль', 'Change password', 'Passwort ändern') + '</button>' +
      '<button class="link" data-act="auth-go" data-v="login">' + t('Назад', 'Back', 'Zurück') + '</button>';
  }
  const keep = {};
  ['a-nick', 'a-pass', 'a-mail', 'a-code'].forEach(id => { const e = document.getElementById(id); if (e) keep[id] = e.value; });
  $('#auth').innerHTML = '<div class="auth-box"><div class="auth-logo">N</div><h1>neirox</h1><div class="sub">' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div>' + body + '<div style="margin-top:10px">' + lang + '</div><div class="muted" style="font-size:12px">v' + esc(VERSION) + '</div></div>';
  Object.keys(keep).forEach(id => { const e = document.getElementById(id); if (e) e.value = keep[id]; });
}
const val = id => (document.getElementById(id) ? document.getElementById(id).value.trim() : '');
async function authAction(fn) {
  U.authErr = ''; U.authBusy = true; renderAuth();
  try { await fn(); } catch (e) { U.authErr = friendly(e); }
  U.authBusy = false;
  if (session) return;
  renderAuth();
}

async function startApp() {
  $('#auth').classList.add('hidden');
  $('#app').classList.remove('hidden');
  D.email = null; knownIds = new Set(); firstLoadDone = false;
  buildShell();
  await refresh();
  if (timer) clearInterval(timer);
  timer = setInterval(refresh, 4000);
}
function logout() {
  setSession(null);
  Object.assign(D, { me: null, friendships: [], profiles: {}, messages: [], hidden: new Set(), email: null, loaded: false });
  U.chat = null; U.tab = 'chats'; U.selected = new Set(); U.editing = null;
  U.authScreen = 'login'; U.authErr = '';
  showAuth();
}

/* ---------- каркас ---------- */
function buildShell() { renderRail(); renderContent(true); }
function renderRail() {
  const tabs = [['chats', '💬', t('Чаты', 'Chats', 'Chats')], ['friends', '👥', t('Друзья', 'Friends', 'Freunde')], ['player', '🎵', t('Плеер', 'Player', 'Player')], ['settings', '⚙️', t('Настройки', 'Settings', 'Einstellungen')]];
  const n = totalUnread();
  setHTML($('#rail'), tabs.map(([id, ic, name]) =>
    '<button class="rail-btn ' + (U.tab === id ? 'on' : '') + '" data-act="tab" data-v="' + id + '">' + ic + '<small>' + esc(name) + '</small>' +
    (id === 'chats' && n ? '<span class="badge">' + n + '</span>' : '') + '</button>').join(''));
}
let shellTab = null;
function renderContent(force) {
  const c = $('#content');
  if (force || shellTab !== U.tab) {
    shellTab = U.tab;
    c._h = null;
    if (U.tab === 'chats') {
      c.innerHTML = '<div class="split"><aside id="list"></aside><section id="pane"></section></div>';
      paneBuilt = null;
    } else {
      c.innerHTML = '<div class="page" id="page"></div>';
    }
  }
}
function renderAll() {
  if (!session || $('#app').classList.contains('hidden')) return;
  renderRail();
  renderContent();
  if (U.tab === 'chats') { renderList(); renderPane(); }
  else if (U.tab === 'friends') renderFriends();
  else if (U.tab === 'player') renderPlayer();
  else if (U.tab === 'settings') renderSettings();
}

/* ---------- список чатов ---------- */
function preview(m) {
  if (!m) return t('Нет сообщений', 'No messages', 'Keine Nachrichten');
  const pre = m.sender === myId() ? t('Вы: ', 'You: ', 'Du: ') : '';
  if (m.kind === 'image') return pre + '📷 ' + t('Фото', 'Photo', 'Foto');
  if (m.kind === 'file') return pre + '📎 ' + (m.file_name || '');
  return pre + (m.body || '');
}
function renderList() {
  const friends = friendIds().map(id => D.profiles[id]).filter(Boolean);
  friends.sort((a, b) => {
    const la = (thread(a.id).slice(-1)[0] || {}).created_at || '', lb = (thread(b.id).slice(-1)[0] || {}).created_at || '';
    return la !== lb ? (la < lb ? 1 : -1) : a.nick.localeCompare(b.nick);
  });
  let h = '<div class="chat-item ' + (U.chat === 'ai' ? 'on' : '') + '" data-act="open" data-v="ai">' +
    '<div class="avatar" style="width:46px;height:46px;font-size:22px;background:linear-gradient(135deg,var(--accent),var(--accent2))">✨</div>' +
    '<div class="grow" style="min-width:0"><div class="title">' + t('Умный Чат (ИИ)', 'Smart Chat (AI)', 'Smarter Chat (KI)') + '</div><div class="prev">' + t('Вопросы и картинки', 'Questions and images', 'Fragen und Bilder') + '</div></div></div>';
  friends.forEach(p => {
    const u = unread(p.id);
    h += '<div class="chat-item ' + (U.chat === p.id ? 'on' : '') + '" data-act="open" data-v="' + esc(p.id) + '">' + avatarHtml(p, 46) +
      '<div class="grow" style="min-width:0;flex:1"><div class="title">' + esc(p.nick) + '</div><div class="prev">' + esc(preview(thread(p.id).slice(-1)[0])) + '</div></div>' +
      (u ? '<span class="unread">' + u + '</span>' : '') + '</div>';
  });
  if (!friends.length) h += '<div class="empty">' + t('Добавь друзей на вкладке «Друзья», чтобы начать переписку.', 'Add friends in the Friends tab to start chatting.', 'Füge im Tab „Freunde“ Freunde hinzu, um zu chatten.') + '</div>';
  setHTML($('#list'), h);
}

/* ---------- панель чата ---------- */
let paneBuilt = null;
function buildPane() {
  const pane = $('#pane');
  if (!U.chat) { pane.innerHTML = '<div class="pane-empty">' + t('Выбери чат слева', 'Pick a chat on the left', 'Wähle links einen Chat') + '</div>'; paneBuilt = null; return; }
  const ai = U.chat === 'ai';
  pane.innerHTML =
    '<div class="chead" id="chead"></div>' +
    '<div class="msgs" id="msgs"></div>' +
    '<div id="cerr"></div>' +
    '<div id="banner"></div>' +
    '<div class="composer">' +
    (ai ? '<div class="seg" id="aimode"></div>' :
      '<button class="icon-btn" data-act="attach-photo" title="' + t('Фото', 'Photo', 'Foto') + '">🖼</button>' +
      '<button class="icon-btn" data-act="attach-file" title="' + t('Файл', 'File', 'Datei') + '">📎</button>' +
      '<button class="icon-btn" data-act="ai-pic" title="' + t('Картинка от ИИ', 'AI image', 'KI-Bild') + '">✨</button>') +
    '<textarea id="inp" rows="1" placeholder="' + t('Сообщение', 'Message', 'Nachricht') + '"></textarea>' +
    '<button class="icon-btn send" id="sendbtn" data-act="send">➤</button></div>';
  const inp = $('#inp');
  inp.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); doSend(); } });
  inp.addEventListener('input', () => { inp.style.height = 'auto'; inp.style.height = Math.min(140, inp.scrollHeight) + 'px'; });
  if (!ai) {
    pane.ondragover = e => { e.preventDefault(); pane.classList.add('drop'); };
    pane.ondragleave = () => pane.classList.remove('drop');
    pane.ondrop = e => {
      e.preventDefault(); pane.classList.remove('drop');
      Array.from(e.dataTransfer.files || []).forEach(f => sendPicked(f, f.type.startsWith('image/')));
    };
  } else { pane.ondragover = pane.ondragleave = pane.ondrop = null; }
  paneBuilt = U.chat;
  setTimeout(() => inp.focus(), 30);
}
function renderPane() {
  if (paneBuilt !== U.chat) buildPane();
  if (!U.chat) return;
  const ai = U.chat === 'ai';
  const p = ai ? null : D.profiles[U.chat];
  // шапка
  let head;
  if (U.selected.size) {
    const one = U.selected.size === 1 ? D.messages.find(m => m.id === Array.from(U.selected)[0]) : null;
    head = '<button class="icon-btn" data-act="sel-clear">✕</button><div class="title grow" style="flex:1">' + U.selected.size + '</div>' +
      (one && one.sender === myId() && one.kind === 'text' ? '<button class="icon-btn" data-act="sel-edit" title="' + t('Изменить', 'Edit', 'Bearbeiten') + '">✏️</button>' : '') +
      '<button class="icon-btn" data-act="sel-copy" title="' + t('Копировать', 'Copy', 'Kopieren') + '">📋</button>' +
      '<button class="icon-btn" data-act="sel-forward" title="' + t('Переслать', 'Forward', 'Weiterleiten') + '">↪️</button>' +
      '<button class="icon-btn" data-act="sel-delete" title="' + t('Удалить', 'Delete', 'Löschen') + '">🗑</button>';
  } else if (ai) {
    head = '<div class="avatar" style="width:40px;height:40px;font-size:20px;background:linear-gradient(135deg,var(--accent),var(--accent2))">✨</div><div class="title" style="flex:1">' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div><button class="icon-btn" data-act="ai-clear" title="' + t('Очистить', 'Clear', 'Leeren') + '">🗑</button>';
  } else {
    head = avatarHtml(p, 40) + '<div class="title">' + esc(p ? p.nick : '') + '</div>';
  }
  setHTML($('#chead'), head);

  const msgs = $('#msgs');
  const atBottom = msgs.scrollHeight - msgs.scrollTop - msgs.clientHeight < 80;
  let html;
  if (ai) {
    html = !A.msgs.length ? '<div class="empty">' + t('Задай вопрос или переключись на «Картинка» и опиши, что нарисовать.', 'Ask a question, or switch to “Image” and describe what to draw.', 'Stelle eine Frage oder wechsle zu „Bild“ und beschreibe, was gezeichnet werden soll.') + '</div>' : '';
    html += A.msgs.map((m, i) => {
      const mine = m.role === 'user';
      const img = A.images[m.id];
      return '<div class="mrow ' + (mine ? 'mine' : '') + '"><div class="bubble" data-ai="' + i + '">' +
        (img ? '<img class="pic" src="' + img + '" data-act="view-url" data-v="' + i + '">' : esc(m.text)) + '</div></div>';
    }).join('');
    if (A.busy) html += '<div class="muted" style="padding:6px">…</div>';
    setHTML($('#cerr'), A.err ? '<div class="err" style="padding:0 18px">' + esc(A.err) + '</div>' : '');
    setHTML($('#aimode'), '<button data-act="ai-mode" data-v="0" class="' + (!U.aiImageMode ? 'on' : '') + '">' + t('Текст', 'Text', 'Text') + '</button><button data-act="ai-mode" data-v="1" class="' + (U.aiImageMode ? 'on' : '') + '">' + t('Картинка', 'Image', 'Bild') + '</button>');
    setHTML($('#banner'), '');
  } else {
    const list = thread(U.chat);
    html = list.map(m => {
      const mine = m.sender === myId();
      let inner;
      if (m.kind === 'image' && m.media_path) {
        const c = urlCache[m.media_path];
        const ok = c && c.exp > Date.now();
        inner = '<img class="pic" data-path="' + esc(m.media_path) + '" ' + (ok ? 'src="' + esc(c.url) + '" data-full="' + esc(c.url) + '"' : '') + ' alt="">';
      }
      else if (m.kind === 'file' && m.media_path) inner = '<div class="file" data-act="open-file" data-id="' + m.id + '">📄 <span>' + esc(m.file_name || 'file') + '</span></div>';
      else inner = esc(m.body || '');
      return '<div class="mrow ' + (mine ? 'mine' : '') + (U.selected.has(m.id) ? ' sel' : '') + '" data-mid="' + m.id + '">' +
        '<div class="bubble" data-mid="' + m.id + '">' + inner +
        '<div class="meta">' + (m.edited_at ? t('изм. ', 'edited ', 'bearb. ') : '') + timeOf(m.created_at) + (mine && m.read_at ? ' ✓✓' : '') + '</div>' +
        '<button class="dots" data-act="menu" data-id="' + m.id + '">⋯</button></div></div>';
    }).join('');
    setHTML($('#cerr'), U.error ? '<div class="err" style="padding:0 18px">' + esc(U.error) + '</div>' : '');
    setHTML($('#banner'), U.editing ? '<div class="banner"><span class="grow" style="flex:1">✏️ ' + t('Редактирование', 'Editing', 'Bearbeiten') + '</span><button data-act="edit-cancel">✕</button></div>' : '');
  }
  const changed = msgs._h !== html;
  setHTML(msgs, html);
  if (changed) {
    if (atBottom || msgs._first !== U.chat) { msgs.scrollTop = msgs.scrollHeight; msgs._first = U.chat; }
    hydrateImages(msgs);
  }
  const sb = $('#sendbtn');
  if (sb) sb.textContent = U.editing ? '✓' : '➤';
}
function hydrateImages(root) {
  root.querySelectorAll('img.pic[data-path]').forEach(img => {
    if (img.src) return;
    signedUrl(img.dataset.path).then(u => { img.src = u; img.dataset.full = u; }).catch(() => { });
  });
}

/* ---------- отправка ---------- */
async function doSend() {
  const inp = $('#inp');
  const text = inp.value.trim();
  if (!text) return;
  if (U.chat === 'ai') { inp.value = ''; inp.style.height = 'auto'; aiSend(text); return; }
  const to = U.chat;
  U.error = '';
  if (U.editing) {
    const ed = U.editing;
    try {
      if (text !== (ed.body || '')) await editMessage(ed.id, text);
      U.editing = null; inp.value = '';
    } catch (e) { U.error = friendly(e); }
    renderAll(); return;
  }
  inp.value = ''; inp.style.height = 'auto';
  try { await sendText(text, to); } catch (e) { inp.value = text; U.error = friendly(e); renderAll(); }
}
async function sendPicked(file, photo) {
  if (!U.chat || U.chat === 'ai') return;
  const to = U.chat;
  U.error = ''; U.busy = true; renderAll();
  try {
    if (photo) {
      const b = await compress(file);
      await sendMedia(b, 'image/jpeg', 'photo.jpg', 'image', to);
    } else {
      if (file.size > MAX_FILE) throw new Error(t('Файл больше 25 МБ', 'File is larger than 25 MB', 'Datei ist größer als 25 MB'));
      await sendMedia(file, file.type || 'application/octet-stream', file.name, 'file', to);
    }
  } catch (e) { U.error = friendly(e); }
  U.busy = false; renderAll();
}
async function sendAiPic() {
  openDialog(t('Картинка от ИИ', 'AI image', 'KI-Bild'),
    '<input class="field" id="d-prompt" placeholder="' + t('Что нарисовать?', 'What to draw?', 'Was zeichnen?') + '">',
    [['cancel', t('Отмена', 'Cancel', 'Abbrechen'), 'ghost'], ['ai-pic-go', t('Создать и отправить', 'Create and send', 'Erstellen und senden'), '']]);
  setTimeout(() => { const e = $('#d-prompt'); if (e) e.focus(); }, 30);
}

/* ---------- ИИ-чат ---------- */
function saveAI() {
  const keep = A.msgs.filter(m => !A.images[m.id]).slice(-60);
  lsSet('neirox.ai.history', JSON.stringify(keep));
}
async function aiSend(text) {
  if (A.busy) return;
  A.err = '';
  const um = { id: crypto.randomUUID(), role: 'user', text };
  A.msgs.push(um);
  A.busy = true; renderAll();
  try {
    if (U.aiImageMode) {
      const b = await aiImage(text);
      const m = { id: crypto.randomUUID(), role: 'assistant', text: '🖼' };
      A.images[m.id] = URL.createObjectURL(b);
      A.msgs.push(m);
    } else {
      const hist = A.msgs.filter(m => !A.images[m.id]).slice(-20).map(m => ({ role: m.role, content: m.text }));
      A.msgs.push({ id: crypto.randomUUID(), role: 'assistant', text: await aiText(hist) });
    }
    saveAI();
  } catch (e) {
    const m = String(e.message || '');
    A.err = m.includes('rate_limited') ? friendly(e) : t('ИИ сейчас не ответил, попробуй ещё раз', 'AI did not answer, try again', 'KI hat nicht geantwortet, versuche es erneut');
  }
  A.busy = false; renderAll();
}

/* ---------- друзья ---------- */
let searchT = null;
function renderFriends() {
  const page = $('#page');
  const focus = document.activeElement && document.activeElement.id === 'f-q';
  const rows = (p, right) => '<div class="card row">' + avatarHtml(p, 42) + '<div class="title grow" style="flex:1">' + esc(p.nick) + '</div>' + right + '</div>';
  let h = '<h2>' + t('Друзья', 'Friends', 'Freunde') + '</h2>' +
    '<input class="field" id="f-q" placeholder="' + t('Найти по нику', 'Search by nick', 'Nach Nick suchen') + '" value="' + esc(U.query) + '">' +
    (U.error ? '<div class="err">' + esc(U.error) + '</div>' : '');
  if (U.query) {
    h += '<div class="section">' + t('Результаты', 'Results', 'Ergebnisse') + '</div>';
    if (!U.results.length) h += '<div class="muted">' + t('Никого не найдено', 'Nobody found', 'Niemand gefunden') + '</div>';
    U.results.forEach(p => {
      const f = friendshipWith(p.id);
      h += rows(p, f ? '<span class="muted">' + (f.status === 'accepted' ? t('Друг', 'Friend', 'Freund') : t('Заявка', 'Pending', 'Anfrage')) + '</span>'
        : '<button class="btn sm" data-act="f-add" data-id="' + esc(p.id) + '">' + t('Добавить', 'Add', 'Hinzufügen') + '</button>');
    });
  }
  const inc = incoming();
  if (inc.length) {
    h += '<div class="section">' + t('Заявки в друзья', 'Friend requests', 'Freundschaftsanfragen') + '</div>';
    inc.forEach(f => { const p = D.profiles[f.requester]; if (p) h += rows(p, '<button class="btn sm" data-act="f-accept" data-fid="' + f.id + '">' + t('Принять', 'Accept', 'Annehmen') + '</button><button class="btn sm ghost" data-act="f-remove" data-fid="' + f.id + '">' + t('Отклонить', 'Decline', 'Ablehnen') + '</button>'); });
  }
  h += '<div class="section">' + t('Друзья', 'Friends', 'Freunde') + '</div>';
  const fr = friendIds().map(id => D.profiles[id]).filter(Boolean).sort((a, b) => a.nick.localeCompare(b.nick));
  if (!fr.length) h += '<div class="muted">' + t('Пока нет друзей. Найди человека по нику и отправь заявку.', 'No friends yet. Find someone by nick and send a request.', 'Noch keine Freunde. Suche jemanden per Nick und sende eine Anfrage.') + '</div>';
  fr.forEach(p => { const f = friendshipWith(p.id); h += rows(p, '<button class="btn sm ghost" data-act="f-chat" data-id="' + esc(p.id) + '">' + t('Написать', 'Message', 'Schreiben') + '</button>' + (f ? '<button class="btn sm ghost" data-act="f-remove" data-fid="' + f.id + '">' + t('Удалить', 'Remove', 'Entfernen') + '</button>' : '')); });
  const out = outgoing();
  if (out.length) {
    h += '<div class="section">' + t('Отправленные заявки', 'Sent requests', 'Gesendete Anfragen') + '</div>';
    out.forEach(f => { const p = D.profiles[f.addressee]; if (p) h += rows(p, '<button class="btn sm ghost" data-act="f-remove" data-fid="' + f.id + '">' + t('Отменить', 'Cancel', 'Abbrechen') + '</button>'); });
  }
  if (page._h === h) return;
  const q = document.getElementById('f-q');
  const pos = q ? q.selectionStart : 0;
  setHTML(page, h);
  if (focus) { const n = document.getElementById('f-q'); n.focus(); n.setSelectionRange(pos, pos); }
}
async function doSearch() {
  const clean = U.query.toLowerCase().replace(/[^a-z0-9_]/g, '');
  if (clean.length < 2) { U.results = []; renderAll(); return; }
  try { U.results = await sel('profiles', { nick: 'ilike.*' + clean + '*', id: 'neq.' + myId(), select: '*', limit: '20' }); } catch (e) { U.results = []; }
  U.results.forEach(p => { D.profiles[p.id] = p; });
  renderAll();
}
async function friendRun(fn) { U.error = ''; try { await fn(); await refresh(); } catch (e) { U.error = friendly(e); renderAll(); } }

/* ---------- плеер ---------- */
const aud = () => $('#aud');
function playTrack(i) {
  if (i < 0 || i >= P.tracks.length) return;
  P.cur = i; aud().src = P.tracks[i].url; aud().play().catch(() => { }); P.playing = true; renderAll();
}
function renderPlayer() {
  const cur = P.tracks[P.cur];
  let h = '<h2>' + t('Плеер', 'Player', 'Player') + '</h2>' +
    '<button class="btn" data-act="music-add">＋ ' + t('Добавить музыку', 'Add music', 'Musik hinzufügen') + '</button>';
  if (cur) {
    h += '<div class="card" style="text-align:center"><div class="title" style="font-size:18px;margin-bottom:10px">' + esc(cur.name) + '</div>' +
      '<input type="range" id="p-seek" min="0" max="1000" value="0">' +
      '<div class="row muted" style="justify-content:space-between;font-size:12px"><span id="p-cur">0:00</span><span id="p-dur">0:00</span></div>' +
      '<div class="ctrls"><button data-act="p-prev">⏮</button><button data-act="p-toggle">' + (P.playing ? '⏸' : '▶️') + '</button><button data-act="p-next">⏭</button></div></div>';
  }
  if (!P.tracks.length) h += '<div class="empty">' + t('Добавь музыкальные файлы с компьютера, и они появятся здесь.', 'Add music files from your computer and they will appear here.', 'Füge Musikdateien von deinem Computer hinzu.') + '</div>';
  P.tracks.forEach((tr, i) => { h += '<div class="track ' + (i === P.cur ? 'on' : '') + '" data-act="p-play" data-i="' + i + '">' + (i === P.cur && P.playing ? '🔊' : '🎵') + '<div class="grow" style="flex:1">' + esc(tr.name) + '</div></div>'; });
  const page = $('#page');
  if (page._h === h) return;
  setHTML(page, h);
  tickPlayer();
}
const fmt = s => { s = Math.floor(s || 0); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
function tickPlayer() {
  const a = aud(), sk = document.getElementById('p-seek');
  if (!sk) return;
  if (a.duration) sk.value = Math.round(a.currentTime / a.duration * 1000);
  const c = document.getElementById('p-cur'), d = document.getElementById('p-dur');
  if (c) c.textContent = fmt(a.currentTime);
  if (d) d.textContent = fmt(a.duration);
}

/* ---------- настройки ---------- */
function renderSettings() {
  const me = D.me;
  const seg = (key, opts) => '<div class="seg">' + opts.map(([v, l]) => '<button data-act="set" data-k="' + key + '" data-v="' + v + '" class="' + (S[key] === v ? 'on' : '') + '">' + esc(l) + '</button>').join('') + '</div>';
  let h = '<h2>' + t('Настройки', 'Settings', 'Einstellungen') + '</h2>' +
    '<div class="card row">' + avatarHtml(me, 64) + '<div class="grow" style="flex:1"><div class="title" style="font-size:18px">' + esc(me ? me.nick : '') + '</div><div class="muted" style="font-size:13px">' + esc(D.email || t('Почта не привязана', 'No email bound', 'Keine E-Mail verknüpft')) + '</div></div>' +
    '<button class="btn sm ghost" data-act="avatar">' + t('Сменить фото', 'Change photo', 'Foto ändern') + '</button></div>' +
    (U.error ? '<div class="err">' + esc(U.error) + '</div>' : '') +
    '<div class="card row"><div class="grow" style="flex:1">' + t('Ник', 'Nick', 'Nick') + '</div><button class="btn sm ghost" data-act="nick">' + t('Изменить', 'Change', 'Ändern') + '</button></div>' +
    (D.email ? '' : '<div class="card row"><div class="grow" style="flex:1">' + t('Почта для восстановления пароля', 'Recovery email', 'Wiederherstellungs-E-Mail') + '</div><button class="btn sm ghost" data-act="email">' + t('Привязать', 'Bind', 'Verknüpfen') + '</button></div>') +
    '<div class="section">' + t('Оформление', 'Look', 'Darstellung') + '</div>' +
    '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Язык', 'Language', 'Sprache') + '</div>' + seg('lang', [['ru', 'Русский'], ['en', 'English'], ['de', 'Deutsch']]) + '</div>' +
    '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Тема', 'Theme', 'Design') + '</div>' + seg('mode', [['dark', t('Тёмная', 'Dark', 'Dunkel')], ['black', t('Чёрная', 'Black', 'Schwarz')], ['light', t('Светлая', 'Light', 'Hell')]]) + '</div>' +
    '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Размер текста', 'Text size', 'Textgröße') + '</div>' + seg('size', [['small', t('Мелкий', 'Small', 'Klein')], ['medium', t('Средний', 'Medium', 'Mittel')], ['large', t('Крупный', 'Large', 'Groß')]]) + '</div>' +
    '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Цвет свечения', 'Accent color', 'Akzentfarbe') + '</div><div class="swatches">' +
    ACCENTS.map(c => '<button class="sw ' + (S.accent.toLowerCase() === c.toLowerCase() ? 'on' : '') + '" style="background:' + c + '" data-act="accent" data-v="' + c + '"></button>').join('') + '</div></div>' +
    '<div class="card row"><div class="grow" style="flex:1">' + t('Звук сообщений', 'Message sound', 'Nachrichtenton') + '</div><button class="switch ' + (S.sound ? 'on' : '') + '" data-act="sound"></button></div>' +
    '<div class="section">nox</div>' +
    '<div class="card"><div class="title">⚡ ' + t('Мой nox', 'My nox', 'Mein nox') + '</div><div class="muted" style="font-size:14px;margin-top:4px">' + t('Пока что данная механика nox находится в разработке', 'The nox mechanic is still in development', 'Die nox-Mechanik ist noch in Entwicklung') + '</div></div>' +
    '<button class="btn ghost" data-act="logout" style="margin-top:10px">' + t('Выйти из аккаунта', 'Sign out', 'Abmelden') + '</button>' +
    '<div class="muted" style="text-align:center;font-size:12px;margin-top:6px">neirox · v' + esc(VERSION) + '</div>';
  if ($('#page')._h === h) return;
  setHTML($('#page'), h);
}

/* ---------- диалоги и меню ---------- */
function openDialog(title, bodyHtml, buttons) {
  const m = $('#modal');
  m.innerHTML = '<div class="dlg"><h3>' + esc(title) + '</h3>' + bodyHtml + '<div class="acts">' +
    buttons.map(([act, label, cls, extra]) => '<button class="btn sm ' + (cls || '') + '" data-act="' + act + '" ' + (extra || '') + '>' + esc(label) + '</button>').join('') + '</div></div>';
  m.classList.remove('hidden');
}
function closeDialog() { $('#modal').classList.add('hidden'); $('#modal').innerHTML = ''; }
function selMsgs() { return D.messages.filter(m => U.selected.has(m.id)).sort((a, b) => a.created_at < b.created_at ? -1 : 1); }
function showCtx(id, x, y) {
  const m = D.messages.find(mm => mm.id === id);
  if (!m) return;
  const c = $('#ctx');
  const canEdit = m.sender === myId() && m.kind === 'text';
  c.innerHTML =
    '<button data-act="c-copy" data-id="' + id + '">📋 ' + t('Копировать', 'Copy', 'Kopieren') + '</button>' +
    (canEdit ? '<button data-act="c-edit" data-id="' + id + '">✏️ ' + t('Изменить', 'Edit', 'Bearbeiten') + '</button>' : '') +
    '<button data-act="c-forward" data-id="' + id + '">↪️ ' + t('Переслать', 'Forward', 'Weiterleiten') + '</button>' +
    '<button class="del" data-act="c-delete" data-id="' + id + '">🗑 ' + t('Удалить', 'Delete', 'Löschen') + '</button>' +
    '<button data-act="c-select" data-id="' + id + '">☑️ ' + t('Выделить', 'Select', 'Auswählen') + '</button>';
  c.classList.remove('hidden');
  const w = c.offsetWidth, h = c.offsetHeight;
  c.style.left = Math.max(6, Math.min(x, innerWidth - w - 6)) + 'px';
  c.style.top = Math.max(6, Math.min(y, innerHeight - h - 6)) + 'px';
}
const hideCtx = () => $('#ctx').classList.add('hidden');
function copyText(text) {
  const done = () => toast(t('Скопировано', 'Copied', 'Kopiert'));
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(done, () => fallbackCopy(text, done)); return; }
  } catch (e) { }
  fallbackCopy(text, done);
}
function fallbackCopy(text, done) {
  const ta = document.createElement('textarea'); ta.value = text; document.body.appendChild(ta); ta.select();
  try { document.execCommand('copy'); done(); } catch (e) { } ta.remove();
}
function copyMessages(list) {
  const parts = list.map(m => m.kind === 'text' ? m.body : (m.kind === 'file' ? m.file_name : null)).filter(Boolean);
  if (!parts.length) { toast(t('Нечего копировать', 'Nothing to copy', 'Nichts zu kopieren')); return false; }
  copyText(parts.join('\n')); return true;
}
function startEdit(m) {
  U.editing = m; U.selected = new Set();
  renderAll();
  const inp = $('#inp'); if (inp) { inp.value = m.body || ''; inp.focus(); }
}
function openForward(list) {
  const friends = friendIds().map(id => D.profiles[id]).filter(Boolean);
  window._fwd = list;
  openDialog(t('Переслать', 'Forward', 'Weiterleiten'),
    '<div class="pick" data-act="fwd-ai"><div class="avatar" style="width:36px;height:36px;font-size:18px;background:linear-gradient(135deg,var(--accent),var(--accent2))">✨</div><div>' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div></div>' +
    friends.map(p => '<div class="pick" data-act="fwd-to" data-id="' + esc(p.id) + '">' + avatarHtml(p, 36) + '<div>' + esc(p.nick) + '</div></div>').join(''),
    [['cancel', t('Отмена', 'Cancel', 'Abbrechen'), 'ghost']]);
}
function openDelete(list) {
  window._del = list;
  const allMine = list.length && list.every(m => m.sender === myId());
  openDialog(t('Удалить сообщения?', 'Delete messages?', 'Nachrichten löschen?'),
    '<div class="muted">' + (allMine ? t('Можно удалить у всех или только у себя.', 'Delete for everyone or only for you.', 'Für alle oder nur für dich löschen.') : t('Сообщения собеседника удалятся только у тебя.', 'Messages from the other person are deleted only for you.', 'Nachrichten des anderen werden nur bei dir gelöscht.')) + '</div>',
    [['cancel', t('Отмена', 'Cancel', 'Abbrechen'), 'ghost'], ['del-me', t('У меня', 'For me', 'Für mich'), ''], ...(allMine ? [['del-all', t('У всех', 'For everyone', 'Für alle'), 'danger']] : [])]);
}
function openView(url) {
  const v = $('#viewer'); v.innerHTML = '<img src="' + esc(url) + '" alt="">'; v.classList.remove('hidden');
}

/* ---------- события ---------- */
document.addEventListener('click', async e => {
  const hide = !e.target.closest('#ctx');
  if (hide) hideCtx();
  if (e.target.closest('#viewer')) { $('#viewer').classList.add('hidden'); return; }
  const modal = $('#modal');
  if (e.target === modal) { closeDialog(); return; }

  // клик по сообщению в режиме выделения
  const row = e.target.closest('.mrow[data-mid]');
  if (U.selected.size && row && !e.target.closest('[data-act="menu"]')) {
    const id = Number(row.dataset.mid);
    if (U.selected.has(id)) U.selected.delete(id); else U.selected.add(id);
    renderAll(); return;
  }
  const pic = e.target.closest('img.pic[data-full]');
  if (pic && !U.selected.size) { openView(pic.dataset.full); return; }
  const aiPic = e.target.closest('img.pic[data-act="view-url"]');
  if (aiPic) { openView(aiPic.src); return; }

  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act, v = el.dataset.v, id = el.dataset.id;
  const ids = el.dataset.id;

  switch (act) {
    case 'lang': S.lang = v; saveSettings(); renderAuth(); break;
    case 'auth-go': U.authScreen = v; U.authErr = ''; renderAuth(); break;
    case 'login': {
      const n = val('a-nick'), p = val('a-pass');
      if (!n || !p) return;
      await authAction(async () => { await signIn(n, p); await startApp(); }); break;
    }
    case 'register': {
      const n = val('a-nick'), p = val('a-pass'), m = val('a-mail');
      await authAction(async () => { await register(n, p, m); await signIn(n, p); await startApp(); }); break;
    }
    case 'recover-req': {
      const n = val('a-nick'); if (!n) return;
      U.recNick = n;
      await authAction(async () => { await raw('POST', '/functions/v1/recover', { json: { action: 'request', nick: n }, auth: false }); U.authScreen = 'recover2'; }); break;
    }
    case 'recover-ok': {
      const code = val('a-code'), p = val('a-pass');
      await authAction(async () => { await raw('POST', '/functions/v1/recover', { json: { action: 'confirm', nick: U.recNick, code, new_password: p }, auth: false }); await signIn(U.recNick, p); await startApp(); }); break;
    }
    case 'tab': U.tab = v; U.error = ''; renderAll(); break;
    case 'open': U.chat = v; U.selected = new Set(); U.editing = null; U.error = ''; renderAll(); markReadIfOpen(); break;
    case 'f-chat': U.tab = 'chats'; U.chat = id; renderAll(); markReadIfOpen(); break;
    case 'send': doSend(); break;
    case 'attach-photo': $('#pick-photo').click(); break;
    case 'attach-file': $('#pick-file').click(); break;
    case 'ai-pic': sendAiPic(); break;
    case 'ai-pic-go': {
      const p = val('d-prompt'); closeDialog(); if (!p || !U.chat || U.chat === 'ai') return;
      const to = U.chat; U.busy = true; U.error = '';
      try { await sendMedia(await aiImage(p), 'image/jpeg', 'ai.jpg', 'image', to); } catch (er) { U.error = friendly(er); }
      U.busy = false; renderAll(); break;
    }
    case 'ai-mode': U.aiImageMode = v === '1'; renderAll(); break;
    case 'ai-clear': A.msgs = []; A.images = {}; saveAI(); renderAll(); break;
    case 'cancel': closeDialog(); break;
    case 'menu': {
      const r = el.getBoundingClientRect(); showCtx(Number(id), r.left, r.bottom + 4); e.stopPropagation(); break;
    }
    case 'c-copy': hideCtx(); copyMessages(D.messages.filter(m => m.id === Number(id))); break;
    case 'c-edit': hideCtx(); startEdit(D.messages.find(m => m.id === Number(id))); break;
    case 'c-forward': hideCtx(); openForward(D.messages.filter(m => m.id === Number(id))); break;
    case 'c-delete': hideCtx(); openDelete(D.messages.filter(m => m.id === Number(id))); break;
    case 'c-select': hideCtx(); U.selected = new Set([Number(id)]); renderAll(); break;
    case 'sel-clear': U.selected = new Set(); renderAll(); break;
    case 'sel-edit': startEdit(selMsgs()[0]); break;
    case 'sel-copy': if (copyMessages(selMsgs())) { U.selected = new Set(); renderAll(); } break;
    case 'sel-forward': openForward(selMsgs()); break;
    case 'sel-delete': openDelete(selMsgs()); break;
    case 'edit-cancel': U.editing = null; { const i = $('#inp'); if (i) i.value = ''; } renderAll(); break;
    case 'fwd-to': {
      const list = (window._fwd || []).slice().sort((a, b) => a.created_at < b.created_at ? -1 : 1);
      closeDialog(); U.selected = new Set(); U.busy = true; U.error = ''; renderAll();
      try { for (const m of list) await forwardMsg(m, id); toast(t('Переслано', 'Forwarded', 'Weitergeleitet')); } catch (er) { U.error = friendly(er); }
      U.busy = false; renderAll(); break;
    }
    case 'fwd-ai': {
      const text = (window._fwd || []).filter(m => m.kind === 'text').map(m => m.body).join('\n');
      closeDialog();
      if (!text) { toast(t('В ИИ можно переслать только текст', 'Only text can be sent to AI', 'An die KI kann nur Text gesendet werden')); return; }
      U.selected = new Set(); U.chat = 'ai'; U.aiImageMode = false; renderAll(); aiSend(text); break;
    }
    case 'del-me': case 'del-all': {
      const list = window._del || []; closeDialog(); U.selected = new Set();
      try { act === 'del-all' ? await deleteForAll(list) : await deleteForMe(list); } catch (er) { U.error = friendly(er); renderAll(); }
      break;
    }
    case 'open-file': {
      const m = D.messages.find(mm => mm.id === Number(id));
      if (m && m.media_path) { try { window.open(await signedUrl(m.media_path)); } catch (er) { } }
      break;
    }
    case 'f-add': friendRun(() => ins('friendships', { requester: myId(), addressee: id, status: 'pending' })); break;
    case 'f-accept': friendRun(() => upd('friendships', { id: 'eq.' + el.dataset.fid }, { status: 'accepted' })); break;
    case 'f-remove': friendRun(() => del('friendships', { id: 'eq.' + el.dataset.fid })); break;
    case 'music-add': $('#pick-music').click(); break;
    case 'p-play': playTrack(Number(el.dataset.i)); break;
    case 'p-toggle': { const a = aud(); if (!a.src && P.tracks.length) playTrack(0); else if (a.paused) { a.play(); P.playing = true; } else { a.pause(); P.playing = false; } renderAll(); break; }
    case 'p-next': playTrack((P.cur + 1) % Math.max(1, P.tracks.length)); break;
    case 'p-prev': playTrack((P.cur - 1 + P.tracks.length) % Math.max(1, P.tracks.length)); break;
    case 'set': S[el.dataset.k] = v; saveSettings(); renderAll(); break;
    case 'accent': S.accent = v; saveSettings(); renderAll(); break;
    case 'sound': S.sound = !S.sound; saveSettings(); renderAll(); break;
    case 'avatar': $('#pick-avatar').click(); break;
    case 'nick':
      openDialog(t('Новый ник', 'New nick', 'Neuer Nick'), '<input class="field" id="d-nick" placeholder="' + t('Ник (a–z, цифры, _)', 'Nick (a–z, digits, _)', 'Nick (a–z, Ziffern, _)') + '">',
        [['cancel', t('Отмена', 'Cancel', 'Abbrechen'), 'ghost'], ['nick-go', t('Сохранить', 'Save', 'Speichern'), '']]);
      break;
    case 'nick-go': {
      const n = val('d-nick'); closeDialog(); if (!n) return; U.error = '';
      try { await raw('POST', '/functions/v1/account', { json: { action: 'change_nick', nick: n } }); await refresh(); } catch (er) { U.error = friendly(er); renderAll(); }
      break;
    }
    case 'email':
      openDialog(t('Почта для восстановления', 'Recovery email', 'Wiederherstellungs-E-Mail'), '<input class="field" id="d-mail" placeholder="name@mail.com">',
        [['cancel', t('Отмена', 'Cancel', 'Abbrechen'), 'ghost'], ['email-go', t('Привязать', 'Bind', 'Verknüpfen'), '']]);
      break;
    case 'email-go': {
      const m = val('d-mail').toLowerCase(); closeDialog(); if (!m) return; U.error = '';
      try { await ins('private_profiles', { user_id: myId(), recovery_email: m }); D.email = m; } catch (er) { U.error = friendly(er); }
      renderAll(); break;
    }
    case 'logout': logout(); break;
  }
});

document.addEventListener('contextmenu', e => {
  const b = e.target.closest('.bubble[data-mid]');
  if (!b || U.selected.size) return;
  e.preventDefault();
  showCtx(Number(b.dataset.mid), e.clientX, e.clientY);
});
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (!$('#viewer').classList.contains('hidden')) $('#viewer').classList.add('hidden');
    else if (!$('#modal').classList.contains('hidden')) closeDialog();
    else if (U.selected.size) { U.selected = new Set(); renderAll(); }
    else hideCtx();
  }
  if (e.key === 'Enter' && !$('#auth').classList.contains('hidden') && e.target.tagName === 'INPUT') {
    const b = $('#auth .btn'); if (b) b.click();
  }
  if (e.key === 'Enter' && !$('#modal').classList.contains('hidden') && e.target.tagName === 'INPUT') {
    const b = $('#modal .btn:last-child'); if (b) b.click();
  }
});
document.addEventListener('input', e => {
  if (e.target.id === 'f-q') {
    U.query = e.target.value;
    clearTimeout(searchT); searchT = setTimeout(doSearch, 300);
  }
});
$('#pick-photo').addEventListener('change', e => { Array.from(e.target.files).forEach(f => sendPicked(f, true)); e.target.value = ''; });
$('#pick-file').addEventListener('change', e => { Array.from(e.target.files).forEach(f => sendPicked(f, false)); e.target.value = ''; });
$('#pick-avatar').addEventListener('change', async e => {
  const f = e.target.files[0]; e.target.value = '';
  if (!f) return;
  try {
    const b = await compress(f);
    const path = myId() + '/avatar.jpg';
    await uploadFile('avatars', path, b, 'image/jpeg', true);
    await upd('profiles', { id: 'eq.' + myId() }, { avatar_url: publicUrl('avatars', path) + '?v=' + Date.now() });
    await refresh();
  } catch (er) { U.error = friendly(er); renderAll(); }
});
$('#pick-music').addEventListener('change', e => {
  Array.from(e.target.files).forEach(f => P.tracks.push({ name: f.name.replace(/\.[^.]+$/, ''), url: URL.createObjectURL(f) }));
  e.target.value = '';
  if (P.cur < 0 && P.tracks.length) playTrack(0); else renderAll();
});
const A_ = aud();
A_.addEventListener('timeupdate', tickPlayer);
A_.addEventListener('loadedmetadata', tickPlayer);
A_.addEventListener('ended', () => { if (P.tracks.length) playTrack((P.cur + 1) % P.tracks.length); });
document.addEventListener('change', e => {
  if (e.target.id === 'p-seek') { const a = aud(); if (a.duration) a.currentTime = a.duration * e.target.value / 1000; }
});

/* ---------- старт ---------- */
applyTheme();
if (session) startApp(); else showAuth();
