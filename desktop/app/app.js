'use strict';
/* neirox desktop — веб-клиент на том же Supabase, что и приложения для iPhone и Android */

const SB_URL = 'https://seimbpskeemozcibybsy.supabase.co';
const SB_KEY = 'sb_publishable_h5MfmS1nk907f6_1gwjm-Q_7JsUwDpI';
const VERSION = new URLSearchParams(location.search).get('v') || 'web';
const MAX_FILE = 50 * 1024 * 1024;


/* ---------- иконки (рисуются одинаково на любой системе, включая Windows 7) ---------- */
const IC = {
  chat: '<path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.5 8.5 0 0 1-3.8-.9L3 21l1.9-5.1A8.4 8.4 0 0 1 3 11.5 8.5 8.5 0 0 1 12 3a8.4 8.4 0 0 1 9 8.5z"/>',
  users: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
  music: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
  settings: '<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>',
  image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/>',
  clip: '<path d="M21.4 11.1l-9.2 9.2a6 6 0 0 1-8.5-8.5l9.2-9.2a4 4 0 0 1 5.7 5.7l-9.2 9.2a2 2 0 0 1-2.8-2.8l8.5-8.5"/>',
  sparkles: '<path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/><path d="M19 15l.7 1.8 1.8.7-1.8.7L19 20l-.7-1.8-1.8-.7 1.8-.7z"/>',
  send: '<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
  forward: '<polyline points="15 14 20 9 15 4"/><path d="M4 20v-7a4 4 0 0 1 4-4h12"/>',
  trash: '<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>',
  select: '<path d="M22 11.1V12a10 10 0 1 1-5.9-9.1"/><polyline points="22 4 12 14 9 11"/>',
  x: '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
  dots: '<circle cx="5" cy="12" r="1.6" fill="currentColor"/><circle cx="12" cy="12" r="1.6" fill="currentColor"/><circle cx="19" cy="12" r="1.6" fill="currentColor"/>',
  file: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>',
  play: '<polygon points="6 4 20 12 6 20 6 4" fill="currentColor"/>',
  pause: '<rect x="6" y="4" width="4" height="16" fill="currentColor"/><rect x="14" y="4" width="4" height="16" fill="currentColor"/>',
  prev: '<polygon points="19 20 9 12 19 4 19 20" fill="currentColor"/><line x1="5" y1="19" x2="5" y2="5"/>',
  next: '<polygon points="5 4 15 12 5 20 5 4" fill="currentColor"/><line x1="19" y1="5" x2="19" y2="19"/>',
  plus: '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
  bolt: '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>',
  volume: '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14"/>',
  checks: '<polyline points="1 13 5 17 12 8"/><polyline points="9 15 12 18 22 6"/>',
  check: '<polyline points="20 6 9 17 4 12"/>',
  user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  palette: '<circle cx="13.5" cy="6.5" r="1"/><circle cx="17.5" cy="10.5" r="1"/><circle cx="8.5" cy="7.5" r="1"/><circle cx="6.5" cy="12.5" r="1"/><path d="M12 2a10 10 0 0 0 0 20 2 2 0 0 0 1.6-3.2 2 2 0 0 1 1.6-3.3H18a4 4 0 0 0 4-4A10 10 0 0 0 12 2z"/>',
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
  info: '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>',
  smile: '<circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>',
  mic: '<path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/>',
  film: '<rect x="2" y="2" width="20" height="20" rx="2.2"/><line x1="7" y1="2" x2="7" y2="22"/><line x1="17" y1="2" x2="17" y2="22"/><line x1="2" y1="12" x2="22" y2="12"/>',
  phone: '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/>',
  phoneoff: '<path d="M10.7 13.3a16 16 0 0 0 3 2.4l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2v3a2 2 0 0 1-2.2 2A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9"/><line x1="23" y1="1" x2="1" y2="23"/>',
  micoff: '<line x1="1" y1="1" x2="23" y2="23"/><path d="M9 9v3a3 3 0 0 0 5.1 2.1M15 9.3V4a3 3 0 0 0-5.9-.7"/><path d="M19 10v2a7 7 0 0 1-.1 1.2M5 10v2a7 7 0 0 0 11.5 5.4"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>'
};
function icons(html) {
  return html.replace(/\{i:([a-z]+)\}/g, (all, n) => IC[n]
    ? '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + IC[n] + '</svg>'
    : all);
}

const $ = (s, r) => (r || document).querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"'{]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;', '{': '&#123;' }[c]));
const lsGet = (k, d) => { try { const v = localStorage.getItem(k); return v == null ? d : v; } catch (e) { return d; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch (e) { } };

/* ---------- настройки ---------- */
function linkify(text) {
  const src = String(text == null ? '' : text);
  const re = /(?:https?:\/\/|www\.)[^\s<>"']+/gi;
  let out = '', last = 0, m;
  while ((m = re.exec(src))) {
    let u = m[0], tail = '';
    while (/[.,!?;:)\]}»"']$/.test(u)) { tail = u.slice(-1) + tail; u = u.slice(0, -1); }
    if (u.length < 5) continue;
    const href = /^www\./i.test(u) ? 'https://' + u : u;
    out += esc(src.slice(last, m.index)) + '<a class="lnk" href="' + esc(href) + '" data-url="' + esc(href) + '">' + esc(u) + '</a>';
    last = m.index + u.length;
    re.lastIndex = last;
  }
  return out + esc(src.slice(last));
}
const attsOf = m => (m && Array.isArray(m.attachments) ? m.attachments : []);
const EMO = [
  ['😀', '😀 😃 😄 😁 😆 😅 😂 🤣 🙂 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝 🤗 🤭 🤔 🤨 😐 😑 😶 🙄 😏 😴 😌 😔 😪 🤤 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 💀 💩 🤡 👻 👽 🤖'],
  ['👍', '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤝 🙏 💪 👏 🙌 👐 🤲 ✍️ 💅 🧠 👀 👅 👄 🙋 🤦 🤷 💃 🕺 🚶 🏃'],
  ['❤️', '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 ✨ ⭐ 🌟 💫 🔥 💥 💯 ✅ ❌ ❓ ❗ ⚡ 🎉 🎊 🎁 🏆 🥇 🎵 🎶 💤 💢 💬'],
  ['🐶', '🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🐺 🐴 🦄 🐝 🦋 🐌 🐞 🐢 🐍 🐙 🦀 🐠 🐬 🐳 🌸 🌹 🌻 🌷 🌲 🌴 🍀 🍁 🌈 ☀️ 🌙 ☁️ ❄️ 🌊'],
  ['🍕', '🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🧀 🍳 🥞 🥓 🍔 🍟 🍕 🌭 🌮 🍝 🍣 🍜 🍦 🍩 🍪 🎂 🍰 🍫 🍬 🍭 ☕ 🍵 🥤 🍺 🍷 🥂'],
  ['⚽', '⚽ 🏀 🏈 ⚾ 🎾 🏐 🎱 🏓 🎮 🎲 🎯 🎸 🎹 🎤 🎧 📱 💻 ⌨️ 📷 🎬 📚 ✏️ 📌 📎 🔑 🔒 💡 💰 💳 🚗 ✈️ 🚀 🏠']
].map(c => ({ icon: c[0], list: c[1].split(' ') }));
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
          const body = preview(fresh[0]);
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
async function uploadAtt(blob, mime, fileName) {
  const ext = (fileName.split('.').pop() || '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8);
  const path = myId() + '/' + crypto.randomUUID() + (ext && ext !== fileName ? '.' + ext : '');
  await uploadFile('chat-media', path, blob, mime, false);
  return path;
}
async function sendAlbum(items, caption, to) {
  const atts = [];
  for (const it of items) {
    let blob = it.blob || it.file, mime = it.mime || blob.type || 'application/octet-stream', name = it.name;
    if (it.type === 'image' && !it.raw) { blob = await compress(blob); mime = 'image/jpeg'; name = 'photo.jpg'; }
    if (blob.size > MAX_FILE) throw new Error(t('Файл больше 50 МБ', 'File is larger than 50 MB', 'Datei ist größer als 50 MB'));
    const path = await uploadAtt(blob, mime, name);
    atts.push({ path, name, type: it.type, mime, size: blob.size });
  }
  await ins('messages', { sender: myId(), receiver: to, kind: 'album', body: caption || null, attachments: atts });
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
    attsOf(m).forEach(a => raw('DELETE', '/storage/v1/object/chat-media/' + a.path).catch(() => { }));
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
  if (m.kind === 'album') {
    const out = [];
    for (const a of attsOf(m)) {
      const blob = await (await fetch(await signedUrl(a.path))).blob();
      out.push({ blob, mime: a.mime || blob.type, name: a.name, type: a.type, raw: true });
    }
    await sendAlbum(out, m.body || '', to); return;
  }
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
  el.innerHTML = icons(html);
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
  callStartPolling();
}
function logout() {
  callReset();
  setSession(null);
  Object.assign(D, { me: null, friendships: [], profiles: {}, messages: [], hidden: new Set(), email: null, loaded: false });
  U.chat = null; U.tab = 'chats'; U.selected = new Set(); U.editing = null;
  U.authScreen = 'login'; U.authErr = '';
  showAuth();
}

/* ---------- каркас ---------- */
function buildShell() { renderRail(); renderContent(true); }
function renderRail() {
  const tabs = [['chats', '{i:chat}', t('Чаты', 'Chats', 'Chats')], ['friends', '{i:users}', t('Друзья', 'Friends', 'Freunde')], ['player', '{i:music}', t('Плеер', 'Player', 'Player')], ['settings', '{i:settings}', t('Настройки', 'Settings', 'Einstellungen')]];
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
  if (m.kind === 'image') return pre + t('Фото', 'Photo', 'Foto');
  if (m.kind === 'file') return pre + (m.file_name || '');
  if (m.kind === 'album') {
    const a = attsOf(m);
    let x;
    if (a.length && a.every(q => q.type === 'voice')) x = t('Голосовое сообщение', 'Voice message', 'Sprachnachricht');
    else if (a.length && a.every(q => q.type === 'image')) x = t('Фото', 'Photo', 'Foto') + (a.length > 1 ? ' (' + a.length + ')' : '');
    else if (a.length && a.every(q => q.type === 'video')) x = t('Видео', 'Video', 'Video') + (a.length > 1 ? ' (' + a.length + ')' : '');
    else x = t('Вложения', 'Attachments', 'Anhänge') + ' (' + a.length + ')';
    return pre + x + (m.body ? ': ' + m.body : '');
  }
  return pre + (m.body || '');
}
function renderList() {
  const friends = friendIds().map(id => D.profiles[id]).filter(Boolean);
  friends.sort((a, b) => {
    const la = (thread(a.id).slice(-1)[0] || {}).created_at || '', lb = (thread(b.id).slice(-1)[0] || {}).created_at || '';
    return la !== lb ? (la < lb ? 1 : -1) : a.nick.localeCompare(b.nick);
  });
  let h = '<div class="chat-item ' + (U.chat === 'ai' ? 'on' : '') + '" data-act="open" data-v="ai">' +
    '<div class="avatar" style="width:46px;height:46px;font-size:22px;background:linear-gradient(135deg,var(--accent),var(--accent2))">{i:sparkles}</div>' +
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
  if (REC.on && REC.to !== U.chat) cancelRec();
  pane.innerHTML = icons(
    '<div class="chead" id="chead"></div>' +
    '<div class="msgs" id="msgs"></div>' +
    '<div id="cerr"></div>' +
    '<div id="banner"></div>' +
    '<div id="tray"></div>' +
    '<div id="emoji" class="hidden"></div>' +
    '<div class="composer" id="composer">' +
    (ai ? '<div class="seg" id="aimode"></div>' :
      '<button class="icon-btn" data-act="attach-photo" title="' + t('Фото и видео', 'Photos and videos', 'Fotos und Videos') + '">{i:image}</button>' +
      '<button class="icon-btn" data-act="attach-file" title="' + t('Файл', 'File', 'Datei') + '">{i:clip}</button>' +
      '<button class="icon-btn" data-act="ai-pic" title="' + t('Картинка от ИИ', 'AI image', 'KI-Bild') + '">{i:sparkles}</button>') +
    '<button class="icon-btn" data-act="emoji" title="' + t('Смайлики', 'Emoji', 'Emojis') + '">{i:smile}</button>' +
    '<textarea id="inp" rows="1" placeholder="' + t('Сообщение', 'Message', 'Nachricht') + '"></textarea>' +
    (ai ? '' : '<button class="icon-btn" data-act="rec-start" title="' + t('Голосовое сообщение', 'Voice message', 'Sprachnachricht') + '">{i:mic}</button>') +
    '<button class="icon-btn send" id="sendbtn" data-act="send">{i:send}</button>' +
    '<div id="recbar"><span class="recdot"></span><span id="rec-t">0:00</span><span class="grow" style="flex:1"></span>' +
    '<button class="icon-btn" data-act="rec-cancel" title="' + t('Отмена', 'Cancel', 'Abbrechen') + '">{i:trash}</button>' +
    '<button class="icon-btn send" data-act="rec-send" title="' + t('Отправить', 'Send', 'Senden') + '">{i:send}</button></div></div>');
  const inp = $('#inp');
  inp.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); doSend(); } });
  inp.addEventListener('input', () => { inp.style.height = 'auto'; inp.style.height = Math.min(140, inp.scrollHeight) + 'px'; });
  if (!ai) {
    pane.ondragover = e => { e.preventDefault(); pane.classList.add('drop'); };
    pane.ondragleave = () => pane.classList.remove('drop');
    pane.ondrop = e => {
      e.preventDefault(); pane.classList.remove('drop');
      addPending(Array.from(e.dataTransfer.files || []), 'auto');
    };
  } else { pane.ondragover = pane.ondragleave = pane.ondrop = null; }
  const mb = $('#msgs');
  mb.addEventListener('scroll', () => { mb._stick = mb.scrollHeight - mb.scrollTop - mb.clientHeight < 80; });
  mb.addEventListener('load', () => { if (mb._stick) mb.scrollTop = mb.scrollHeight; }, true);
  mb.addEventListener('loadedmetadata', () => { if (mb._stick) mb.scrollTop = mb.scrollHeight; }, true);
  if (REC.on) $('#composer').classList.add('rec');
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
    head = '<button class="icon-btn" data-act="sel-clear">{i:x}</button><div class="title grow" style="flex:1">' + U.selected.size + '</div>' +
      (one && one.sender === myId() && one.kind === 'text' ? '<button class="icon-btn" data-act="sel-edit" title="' + t('Изменить', 'Edit', 'Bearbeiten') + '">{i:edit}</button>' : '') +
      '<button class="icon-btn" data-act="sel-copy" title="' + t('Копировать', 'Copy', 'Kopieren') + '">{i:copy}</button>' +
      '<button class="icon-btn" data-act="sel-forward" title="' + t('Переслать', 'Forward', 'Weiterleiten') + '">{i:forward}</button>' +
      '<button class="icon-btn" data-act="sel-delete" title="' + t('Удалить', 'Delete', 'Löschen') + '">{i:trash}</button>';
  } else if (ai) {
    head = '<div class="avatar" style="width:40px;height:40px;font-size:20px;background:linear-gradient(135deg,var(--accent),var(--accent2))">{i:sparkles}</div><div class="title" style="flex:1">' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div><button class="icon-btn" data-act="ai-clear" title="' + t('Очистить', 'Clear', 'Leeren') + '">{i:trash}</button>';
  } else {
    head = avatarHtml(p, 40) + '<div class="title" style="flex:1">' + esc(p ? p.nick : '') + '</div>' +
      (CALL_OK ? '<button class="icon-btn" data-act="call-start" title="' + t('Позвонить', 'Call', 'Anrufen') + '">{i:phone}</button>' : '');
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
    html = null;
    setHTML($('#cerr'), U.error ? '<div class="err" style="padding:0 18px">' + esc(U.error) + '</div>' : '');
    setHTML($('#banner'), U.editing ? '<div class="banner"><span class="grow" style="flex:1">{i:edit} ' + t('Редактирование', 'Editing', 'Bearbeiten') + '</span><button data-act="edit-cancel">{i:x}</button></div>' :
      (U.sending ? '<div class="banner"><span class="grow" style="flex:1">{i:clip} ' + t('Отправка…', 'Sending…', 'Senden…') + '</span></div>' : ''));
    setHTML($('#tray'), trayHtml());
  }
  if (ai) setHTML($('#tray'), '');
  const emo = $('#emoji');
  if (emo) { emo.classList.toggle('hidden', !U.emoji); setHTML(emo, U.emoji ? emojiHtml() : ''); }
  let changed;
  if (ai) {
    if (msgs._kind !== 'ai') { msgs.innerHTML = ''; msgs._rows = null; msgs._kind = 'ai'; msgs._h = undefined; }
    changed = msgs._h !== html;
    setHTML(msgs, html);
  } else {
    changed = syncMsgs(msgs, thread(U.chat));
  }
  if (changed) {
    if (atBottom || msgs._first !== U.chat) { msgs.scrollTop = msgs.scrollHeight; msgs._first = U.chat; msgs._stick = true; }
    hydrateImages(msgs);
  }
  const sb = $('#sendbtn');
  if (sb) sb.innerHTML = icons(U.editing ? '{i:check}' : '{i:send}');
}
function hydrateImages(root) {
  root.querySelectorAll('[data-path]').forEach(el => {
    if (el.getAttribute('src')) return;
    signedUrl(el.dataset.path).then(u => { el.src = u; if (el.tagName === 'IMG') el.dataset.full = u; }).catch(() => { });
  });
}
function srcAttr(path, withFull) {
  const c = urlCache[path];
  return c && c.exp > Date.now() ? ' src="' + esc(c.url) + '"' + (withFull ? ' data-full="' + esc(c.url) + '"' : '') : '';
}
function msgContent(m) {
  if (m.kind === 'image' && m.media_path) return '<img class="pic" data-path="' + esc(m.media_path) + '"' + srcAttr(m.media_path, true) + ' alt="">';
  if (m.kind === 'file' && m.media_path) return '<div class="file" data-act="open-file" data-id="' + m.id + '">{i:file} <span>' + esc(m.file_name || 'file') + '</span></div>';
  if (m.kind === 'album') {
    const a = attsOf(m).map((x, i) => ({ x, i }));
    const vis = a.filter(o => o.x.type === 'image' || o.x.type === 'video');
    let h = '';
    if (vis.length) {
      h += '<div class="album n' + Math.min(vis.length, 4) + '">' + vis.map(o => o.x.type === 'image'
        ? '<img class="pic" data-path="' + esc(o.x.path) + '"' + srcAttr(o.x.path, true) + ' alt="">'
        : '<video class="vid" controls preload="metadata" playsinline data-path="' + esc(o.x.path) + '"' + srcAttr(o.x.path) + '></video>').join('') + '</div>';
    }
    a.filter(o => o.x.type === 'voice').forEach(o => { h += '<audio class="voice" controls preload="metadata" data-path="' + esc(o.x.path) + '"' + srcAttr(o.x.path) + '></audio>'; });
    a.filter(o => o.x.type === 'file').forEach(o => { h += '<div class="file" data-act="open-att" data-id="' + m.id + '" data-i="' + o.i + '">{i:file} <span>' + esc(o.x.name || 'file') + '</span></div>'; });
    if (m.body) h += '<div class="cap">' + linkify(m.body) + '</div>';
    return h;
  }
  return linkify(m.body || '');
}
function msgMeta(m, mine) {
  return (m.edited_at ? t('изм. ', 'edited ', 'bearb. ') : '') + timeOf(m.created_at) + (mine && m.read_at ? ' {i:checks}' : '');
}
function syncMsgs(box, list) {
  if (box._kind !== 'chat' || box._mode !== U.chat) { box.innerHTML = ''; box._rows = {}; box._kind = 'chat'; box._mode = U.chat; box._h = undefined; }
  const rows = box._rows;
  let changed = false;
  const keep = new Set();
  let prev = null;
  list.forEach(m => {
    keep.add(m.id);
    let r = rows[m.id];
    if (!r) {
      r = document.createElement('div');
      r.dataset.mid = m.id;
      r.innerHTML = icons('<div class="bubble" data-mid="' + m.id + '"><div class="bc"></div><div class="meta"></div><button class="dots" data-act="menu" data-id="' + m.id + '">{i:dots}</button></div>');
      rows[m.id] = r; changed = true;
    }
    const mine = m.sender === myId();
    const cls = 'mrow' + (mine ? ' mine' : '') + (U.selected.has(m.id) ? ' sel' : '');
    if (r.className !== cls) r.className = cls;
    const bc = r.firstChild.children[0], meta = r.firstChild.children[1];
    const ch = msgContent(m);
    if (bc._h !== ch) { bc._h = ch; bc.innerHTML = icons(ch); changed = true; }
    const mh = msgMeta(m, mine);
    if (meta._h !== mh) { meta._h = mh; meta.innerHTML = icons(mh); }
    const want = prev ? prev.nextSibling : box.firstChild;
    if (want !== r) { box.insertBefore(r, want); changed = true; }
    prev = r;
  });
  Object.keys(rows).forEach(k => { if (!keep.has(Number(k))) { rows[k].remove(); delete rows[k]; changed = true; } });
  return changed;
}

/* ---------- вложения, смайлики, голосовые ---------- */
const PEND = {};
let pendSeq = 0;
const pend = () => (PEND[U.chat] || (PEND[U.chat] = []));
function addPending(files, mode) {
  if (!U.chat || U.chat === 'ai') return;
  const list = pend();
  files.forEach(f => {
    if (list.length >= 20) { U.error = t('Не больше 20 вложений в одном сообщении', 'Up to 20 attachments per message', 'Höchstens 20 Anhänge pro Nachricht'); return; }
    if (f.size > MAX_FILE) { U.error = t('Файл больше 50 МБ: ', 'File is larger than 50 MB: ', 'Datei ist größer als 50 MB: ') + f.name; return; }
    const type = mode === 'file' ? 'file' : (f.type.startsWith('image/') ? 'image' : (f.type.startsWith('video/') ? 'video' : 'file'));
    list.push({ id: ++pendSeq, file: f, type, name: f.name || 'file', url: type === 'file' ? '' : URL.createObjectURL(f) });
  });
  renderAll();
}
function trayHtml() {
  const list = PEND[U.chat] || [];
  if (!list.length) return '';
  return '<div class="tray">' + list.map((p, i) => {
    const x = '<button class="px" data-act="pend-del" data-i="' + i + '">{i:x}</button>';
    if (p.type === 'image') return '<div class="pt"><img src="' + esc(p.url) + '" alt="">' + x + '</div>';
    if (p.type === 'video') return '<div class="pt"><video src="' + esc(p.url) + '#t=0.1" preload="metadata" muted></video><span class="vb">{i:film}</span>' + x + '</div>';
    return '<div class="pt f">{i:file}<span>' + esc(p.name) + '</span>' + x + '</div>';
  }).join('') + '</div>';
}
function emojiHtml() {
  const c = EMO[U.emojiCat || 0] || EMO[0];
  return '<div class="emo-tabs">' + EMO.map((g, i) => '<button data-act="emo-cat" data-i="' + i + '" class="' + (i === (U.emojiCat || 0) ? 'on' : '') + '">' + g.icon + '</button>').join('') + '</div>' +
    '<div class="emo-grid">' + c.list.map(e => '<button data-act="emo" data-e="' + e + '">' + e + '</button>').join('') + '</div>';
}
function insertEmoji(e) {
  const i = $('#inp'); if (!i) return;
  const a = i.selectionStart == null ? i.value.length : i.selectionStart, b = i.selectionEnd == null ? a : i.selectionEnd;
  i.value = i.value.slice(0, a) + e + i.value.slice(b);
  const p = a + e.length;
  try { i.setSelectionRange(p, p); } catch (er) { }
  i.focus();
  i.dispatchEvent(new Event('input'));
}
const REC = { on: false, to: null, ctx: null, stream: null, node: null, src: null, chunks: [], rate: 44100, t0: 0, tm: null };
async function startRec() {
  if (REC.on || !U.chat || U.chat === 'ai' || U.editing) return;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const src = ctx.createMediaStreamSource(stream);
    const node = ctx.createScriptProcessor(4096, 1, 1);
    const mute = ctx.createGain(); mute.gain.value = 0;
    REC.chunks = [];
    node.onaudioprocess = e => { REC.chunks.push(new Float32Array(e.inputBuffer.getChannelData(0))); };
    src.connect(node); node.connect(mute); mute.connect(ctx.destination);
    Object.assign(REC, { on: true, to: U.chat, ctx, stream, node, src, rate: ctx.sampleRate, t0: Date.now() });
    const c = $('#composer'); if (c) c.classList.add('rec');
    const tt = $('#rec-t'); if (tt) tt.textContent = '0:00';
    REC.tm = setInterval(() => {
      const sec = Math.floor((Date.now() - REC.t0) / 1000);
      const el = $('#rec-t'); if (el) el.textContent = fmt(sec);
      if (sec >= 300) finishRec();
    }, 250);
  } catch (e) {
    U.error = t('Нет доступа к микрофону', 'No access to the microphone', 'Kein Zugriff auf das Mikrofon'); renderAll();
  }
}
function stopRecHw() {
  clearInterval(REC.tm);
  try { REC.node.disconnect(); REC.src.disconnect(); } catch (e) { }
  try { REC.stream.getTracks().forEach(x => x.stop()); } catch (e) { }
  try { REC.ctx.close(); } catch (e) { }
  REC.on = false;
  const c = $('#composer'); if (c) c.classList.remove('rec');
}
function cancelRec() { if (!REC.on) return; stopRecHw(); REC.chunks = []; }
function encodeWav(chunks, rate, target) {
  let n = 0; chunks.forEach(c => { n += c.length; });
  const all = new Float32Array(n); let o = 0;
  chunks.forEach(c => { all.set(c, o); o += c.length; });
  const ratio = rate / target, len = Math.floor(n / ratio);
  const buf = new ArrayBuffer(44 + len * 2), dv = new DataView(buf);
  const w = (p, str) => { for (let i = 0; i < str.length; i++) dv.setUint8(p + i, str.charCodeAt(i)); };
  w(0, 'RIFF'); dv.setUint32(4, 36 + len * 2, true); w(8, 'WAVE'); w(12, 'fmt ');
  dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true);
  dv.setUint32(24, target, true); dv.setUint32(28, target * 2, true); dv.setUint16(32, 2, true); dv.setUint16(34, 16, true);
  w(36, 'data'); dv.setUint32(40, len * 2, true);
  for (let i = 0; i < len; i++) {
    const a = Math.floor(i * ratio), b = Math.min(n, Math.max(a + 1, Math.floor((i + 1) * ratio)));
    let sum = 0; for (let j = a; j < b; j++) sum += all[j];
    let v = Math.max(-1, Math.min(1, sum / (b - a)));
    dv.setInt16(44 + i * 2, v < 0 ? v * 0x8000 : v * 0x7fff, true);
  }
  return new Blob([buf], { type: 'audio/wav' });
}
async function finishRec() {
  if (!REC.on) return;
  const chunks = REC.chunks, rate = REC.rate, to = REC.to, dur = Date.now() - REC.t0;
  stopRecHw(); REC.chunks = [];
  if (dur < 700 || !chunks.length) { toast(t('Слишком короткое сообщение', 'Too short', 'Zu kurz')); return; }
  U.sending = true; U.error = ''; renderAll();
  try { await sendAlbum([{ blob: encodeWav(chunks, rate, 16000), mime: 'audio/wav', name: 'voice.wav', type: 'voice' }], '', to); } catch (e) { U.error = friendly(e); }
  U.sending = false; renderAll();
}

/* ---------- отправка ---------- */
async function doSend() {
  const inp = $('#inp');
  const text = inp.value.trim();
  const queued = U.chat === 'ai' ? [] : (PEND[U.chat] || []);
  if (!text && !queued.length) return;
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
  if (queued.length) {
    if (U.sending) return;
    const list = queued.slice();
    inp.value = ''; inp.style.height = 'auto';
    U.sending = true; renderAll();
    try {
      await sendAlbum(list, text, to);
      PEND[to] = (PEND[to] || []).filter(x => !list.includes(x));
      list.forEach(x => { if (x.url) URL.revokeObjectURL(x.url); });
    } catch (e) { U.error = friendly(e); if (U.chat === to && !inp.value) inp.value = text; }
    U.sending = false; renderAll(); return;
  }
  inp.value = ''; inp.style.height = 'auto';
  try { await sendText(text, to); } catch (e) { inp.value = text; U.error = friendly(e); renderAll(); }
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
      const m = { id: crypto.randomUUID(), role: 'assistant', text: '…' };
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
    '<button class="btn" data-act="music-add">{i:plus} ' + t('Добавить музыку', 'Add music', 'Musik hinzufügen') + '</button>';
  if (cur) {
    h += '<div class="card" style="text-align:center"><div class="title" style="font-size:18px;margin-bottom:10px">' + esc(cur.name) + '</div>' +
      '<input type="range" id="p-seek" min="0" max="1000" value="0">' +
      '<div class="row muted" style="justify-content:space-between;font-size:12px"><span id="p-cur">0:00</span><span id="p-dur">0:00</span></div>' +
      '<div class="ctrls"><button data-act="p-prev">{i:prev}</button><button data-act="p-toggle">' + (P.playing ? '{i:pause}' : '{i:play}') + '</button><button data-act="p-next">{i:next}</button></div></div>';
  }
  if (!P.tracks.length) h += '<div class="empty">' + t('Добавь музыкальные файлы с компьютера, и они появятся здесь.', 'Add music files from your computer and they will appear here.', 'Füge Musikdateien von deinem Computer hinzu.') + '</div>';
  P.tracks.forEach((tr, i) => { h += '<div class="track ' + (i === P.cur ? 'on' : '') + '" data-act="p-play" data-i="' + i + '">' + (i === P.cur && P.playing ? '{i:volume}' : '{i:music}') + '<div class="grow" style="flex:1">' + esc(tr.name) + '</div></div>'; });
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
  if (U.picking) return;
  const me = D.me;
  const tab = U.setTab || 'profile';
  const tabs = [['profile', 'user', t('Профиль', 'Profile', 'Profil')], ['look', 'palette', t('Оформление', 'Look', 'Darstellung')],
    ['notify', 'bell', t('Уведомления', 'Notifications', 'Benachrichtigungen')], ['nox', 'bolt', 'nox'], ['about', 'info', t('О программе', 'About', 'Info')]];
  const seg = (key, opts) => '<div class="seg">' + opts.map(([v, l]) => '<button data-act="set" data-k="' + key + '" data-v="' + v + '" class="' + (S[key] === v ? 'on' : '') + '">' + esc(l) + '</button>').join('') + '</div>';
  let h = '<h2>' + t('Настройки', 'Settings', 'Einstellungen') + '</h2>' +
    '<div class="tabs">' + tabs.map(([id, ic, name]) => '<button class="tab ' + (tab === id ? 'on' : '') + '" data-act="set-tab" data-v="' + id + '">{i:' + ic + '} ' + esc(name) + '</button>').join('') + '</div>' +
    (U.error ? '<div class="err">' + esc(U.error) + '</div>' : '');
  if (tab === 'profile') {
    h += '<div class="card row">' + avatarHtml(me, 64) + '<div class="grow" style="flex:1"><div class="title" style="font-size:18px">' + esc(me ? me.nick : '') + '</div><div class="muted" style="font-size:13px">' + esc(D.email || t('Почта не привязана', 'No email bound', 'Keine E-Mail verknüpft')) + '</div></div>' +
      '<button class="btn sm ghost" data-act="avatar">{i:image} ' + t('Сменить фото', 'Change photo', 'Foto ändern') + '</button></div>' +
      '<div class="card row"><div class="grow" style="flex:1">' + t('Ник', 'Nick', 'Nick') + '</div><button class="btn sm ghost" data-act="nick">{i:edit} ' + t('Изменить', 'Change', 'Ändern') + '</button></div>' +
      (D.email ? '' : '<div class="card row"><div class="grow" style="flex:1">' + t('Почта для восстановления пароля', 'Recovery email', 'Wiederherstellungs-E-Mail') + '</div><button class="btn sm ghost" data-act="email">' + t('Привязать', 'Bind', 'Verknüpfen') + '</button></div>') +
      '<button class="btn ghost" data-act="logout" style="margin-top:10px;align-self:flex-start">{i:logout} ' + t('Выйти из аккаунта', 'Sign out', 'Abmelden') + '</button>';
  } else if (tab === 'look') {
    const known = ACCENTS.some(c => c.toLowerCase() === S.accent.toLowerCase());
    h += '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Язык', 'Language', 'Sprache') + '</div>' + seg('lang', [['ru', 'Русский'], ['en', 'English'], ['de', 'Deutsch']]) + '</div>' +
      '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Тема', 'Theme', 'Design') + '</div>' + seg('mode', [['dark', t('Тёмная', 'Dark', 'Dunkel')], ['black', t('Чёрная', 'Black', 'Schwarz')], ['light', t('Светлая', 'Light', 'Hell')]]) + '</div>' +
      '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Размер текста', 'Text size', 'Textgröße') + '</div>' + seg('size', [['small', t('Мелкий', 'Small', 'Klein')], ['medium', t('Средний', 'Medium', 'Mittel')], ['large', t('Крупный', 'Large', 'Groß')]]) + '</div>' +
      '<div class="card"><div class="muted" style="margin-bottom:8px">' + t('Цвет свечения', 'Accent color', 'Akzentfarbe') + '</div><div class="swatches">' +
      ACCENTS.map(c => '<button class="sw ' + (S.accent.toLowerCase() === c.toLowerCase() ? 'on' : '') + '" style="background:' + c + '" data-act="accent" data-v="' + c + '"></button>').join('') +
      '<label class="sw custom ' + (known ? '' : 'on') + '" title="' + t('Свой цвет', 'Custom color', 'Eigene Farbe') + '"><input type="color" id="accent-custom" value="' + esc(S.accent) + '">{i:plus}</label></div>' +
      '<div class="muted" style="font-size:12px;margin-top:8px">' + t('Кнопка «+» открывает палитру: выбери любой цвет.', 'The “+” button opens a palette: pick any color.', 'Die „+“-Taste öffnet eine Palette: wähle eine beliebige Farbe.') + '</div></div>';
  } else if (tab === 'notify') {
    h += '<div class="card row"><div class="grow" style="flex:1">' + t('Звук сообщений', 'Message sound', 'Nachrichtenton') + '</div><button class="switch ' + (S.sound ? 'on' : '') + '" data-act="sound"></button></div>';
  } else if (tab === 'nox') {
    h += '<div class="card"><div class="title">{i:bolt} ' + t('Мой nox', 'My nox', 'Mein nox') + '</div><div class="muted" style="font-size:14px;margin-top:4px">' + t('Пока что данная механика nox находится в разработке', 'The nox mechanic is still in development', 'Die nox-Mechanik ist noch in Entwicklung') + '</div></div>';
  } else {
    h += '<div class="card"><div class="title">neirox · ' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div><div class="muted" style="margin-top:4px">' + t('Версия', 'Version', 'Version') + ' ' + esc(VERSION) + '</div></div>';
  }
  if ($('#page')._h === h) return;
  setHTML($('#page'), h);
}

/* ---------- диалоги и меню ---------- */
function openDialog(title, bodyHtml, buttons) {
  const m = $('#modal');
  m.innerHTML = icons('<div class="dlg"><h3>' + esc(title) + '</h3>' + bodyHtml + '<div class="acts">' +
    buttons.map(([act, label, cls, extra]) => '<button class="btn sm ' + (cls || '') + '" data-act="' + act + '" ' + (extra || '') + '>' + esc(label) + '</button>').join('') + '</div></div>');
  m.classList.remove('hidden');
}
function closeDialog() { $('#modal').classList.add('hidden'); $('#modal').innerHTML = ''; }
function selMsgs() { return D.messages.filter(m => U.selected.has(m.id)).sort((a, b) => a.created_at < b.created_at ? -1 : 1); }
function showCtx(id, x, y) {
  const m = D.messages.find(mm => mm.id === id);
  if (!m) return;
  const c = $('#ctx');
  const canEdit = m.sender === myId() && m.kind === 'text';
  c.innerHTML = icons(
    '<button data-act="c-copy" data-id="' + id + '">{i:copy} ' + t('Копировать', 'Copy', 'Kopieren') + '</button>' +
    (canEdit ? '<button data-act="c-edit" data-id="' + id + '">{i:edit} ' + t('Изменить', 'Edit', 'Bearbeiten') + '</button>' : '') +
    '<button data-act="c-forward" data-id="' + id + '">{i:forward} ' + t('Переслать', 'Forward', 'Weiterleiten') + '</button>' +
    '<button class="del" data-act="c-delete" data-id="' + id + '">{i:trash} ' + t('Удалить', 'Delete', 'Löschen') + '</button>' +
    '<button data-act="c-select" data-id="' + id + '">{i:select} ' + t('Выделить', 'Select', 'Auswählen') + '</button>');
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
  const parts = list.map(m => m.kind === 'text' ? m.body : (m.kind === 'file' ? m.file_name : (m.kind === 'album' ? (m.body || attsOf(m).filter(a => a.type === 'file').map(a => a.name).join('\n')) : null))).filter(Boolean);
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
    '<div class="pick" data-act="fwd-ai"><div class="avatar" style="width:36px;height:36px;font-size:18px;background:linear-gradient(135deg,var(--accent),var(--accent2))">{i:sparkles}</div><div>' + t('Умный Чат', 'Smart Chat', 'Smarter Chat') + '</div></div>' +
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
  if (U.emoji && !e.target.closest('#emoji') && !e.target.closest('[data-act="emoji"]')) { U.emoji = false; renderAll(); }
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
  const lnk = e.target.closest('a.lnk');
  if (lnk) { e.preventDefault(); if (!U.selected.size) { window.open(lnk.dataset.url); return; } }
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
    case 'emoji': U.emoji = !U.emoji; renderAll(); break;
    case 'emo-cat': U.emojiCat = Number(el.dataset.i); renderAll(); break;
    case 'emo': insertEmoji(el.dataset.e); break;
    case 'pend-del': {
      const l = pend(), p = l[Number(el.dataset.i)];
      if (p) { if (p.url) URL.revokeObjectURL(p.url); l.splice(Number(el.dataset.i), 1); }
      renderAll(); break;
    }
    case 'rec-start': startRec(); break;
    case 'rec-cancel': cancelRec(); renderAll(); break;
    case 'rec-send': finishRec(); break;
    case 'open-att': {
      const m = D.messages.find(mm => mm.id === Number(id)), a = attsOf(m)[Number(el.dataset.i)];
      if (a) { try { window.open(await signedUrl(a.path)); } catch (er) { } }
      break;
    }
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
    case 'set-tab': U.setTab = v; U.error = ''; renderAll(); break;
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
    case 'call-start': callStart(U.chat); break;
    case 'call-accept': callAccept(); break;
    case 'call-decline': callDecline(); break;
    case 'call-hang': callHang(); break;
    case 'call-mute': callMute(); break;
    case 'upd-go': updGo(); break;
    case 'upd-skip': updHide(); break;
    case 'upd-desk': updDesk(); break;
    case 'upd-no': updDone(false); break;
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
    else if (U.emoji) { U.emoji = false; renderAll(); }
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
  if (e.target.id === 'accent-custom') { U.picking = true; S.accent = e.target.value; applyTheme(); lsSet('s.accent', S.accent); return; }
  if (e.target.id === 'f-q') {
    U.query = e.target.value;
    clearTimeout(searchT); searchT = setTimeout(doSearch, 300);
  }
});
$('#pick-photo').addEventListener('change', e => { addPending(Array.from(e.target.files), 'auto'); e.target.value = ''; });
$('#pick-file').addEventListener('change', e => { addPending(Array.from(e.target.files), 'file'); e.target.value = ''; });
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
  if (e.target.id === 'accent-custom') { U.picking = false; S.accent = e.target.value; saveSettings(); renderAll(); return; }
  if (e.target.id === 'p-seek') { const a = aud(); if (a.duration) a.currentTime = a.duration * e.target.value / 1000; }
});


/* ---------- звонки (только голос) ---------- */
const CALL_OK = typeof RTCPeerConnection !== 'undefined' && !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
const ICE = [
  { urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] },
  { urls: ['turn:openrelay.metered.ca:80', 'turn:openrelay.metered.ca:443', 'turn:openrelay.metered.ca:443?transport=tcp'], username: 'openrelayproject', credential: 'openrelayproject' }
];
const CALL = { st: 'idle', peer: null, id: '', pc: null, stream: null, ice: [], remote: false, muted: false, secs: 0, last: -1, poll: null, polling: false, tmo: null, tick: null, ring: null, msg: '', chain: Promise.resolve() };

function callUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); });
}
function callStartPolling() {
  if (!CALL_OK || CALL.poll) return;
  CALL.last = -1;
  CALL.poll = setInterval(callPoll, 1000);
}
function callReset() {
  if (CALL.st !== 'idle') callEnd(true, '');
  if (CALL.poll) { clearInterval(CALL.poll); CALL.poll = null; }
  CALL.last = -1;
}
function callSend(call, peer, type, payload, onFail) {
  const row = { call_id: call, receiver: peer, type };
  if (payload) row.payload = payload;
  CALL.chain = CALL.chain.then(() => ins('call_signals', row)).catch(() => { if (onFail) onFail(); });
}
async function callPoll() {
  if (!session || CALL.polling) return;
  CALL.polling = true;
  try {
    const rows = await sel('call_signals', { receiver: 'eq.' + myId(), id: 'gt.' + CALL.last, order: 'id.asc', limit: '100', select: '*' });
    for (const r of rows) {
      if (r.id > CALL.last) CALL.last = r.id;
      try { await callHandle(r); } catch (e) { }
    }
    if (rows.length) del('call_signals', { id: 'in.(' + rows.map(r => r.id).join(',') + ')' }).catch(() => { });
  } catch (e) { }
  CALL.polling = false;
}
async function callHandle(r) {
  const p = r.payload || {};
  if (r.type === 'invite') {
    if (Date.now() - new Date(r.created_at).getTime() > 40000) return;
    if (CALL.st !== 'idle') { if (r.call_id !== CALL.id) callSend(r.call_id, r.sender, 'decline'); return; }
    CALL.id = r.call_id; CALL.peer = r.sender; CALL.st = 'incoming'; CALL.msg = '';
    callRingStart();
    clearTimeout(CALL.tmo);
    CALL.tmo = setTimeout(() => { if (CALL.st === 'incoming') callEnd(false, ''); }, 45000);
    if (!document.hasFocus()) {
      try {
        if (window.nxDesktop) nxDesktop.attention();
        const pr = D.profiles[r.sender];
        if ('Notification' in window && Notification.permission === 'granted') new Notification(pr ? pr.nick : 'neirox', { body: t('Входящий звонок', 'Incoming call', 'Eingehender Anruf') });
      } catch (e) { }
    }
    renderCall();
    return;
  }
  if (r.call_id !== CALL.id || CALL.st === 'idle') return;
  if (r.type === 'accept') {
    if (CALL.st !== 'outgoing') return;
    clearTimeout(CALL.tmo);
    CALL.st = 'connecting'; renderCall();
    await callMakePc();
    const offer = await CALL.pc.createOffer();
    await CALL.pc.setLocalDescription(offer);
    callSend(CALL.id, CALL.peer, 'offer', { sdp: offer.sdp });
  } else if (r.type === 'offer') {
    if (!CALL.pc || !p.sdp) return;
    await CALL.pc.setRemoteDescription({ type: 'offer', sdp: p.sdp });
    CALL.remote = true; callFlushIce();
    const ans = await CALL.pc.createAnswer();
    await CALL.pc.setLocalDescription(ans);
    callSend(CALL.id, CALL.peer, 'answer', { sdp: ans.sdp });
  } else if (r.type === 'answer') {
    if (!CALL.pc || !p.sdp) return;
    await CALL.pc.setRemoteDescription({ type: 'answer', sdp: p.sdp });
    CALL.remote = true; callFlushIce();
  } else if (r.type === 'ice') {
    if (!p.sdp) return;
    const c = { candidate: p.sdp, sdpMid: p.mid || null, sdpMLineIndex: p.idx || 0 };
    if (CALL.pc && CALL.remote) CALL.pc.addIceCandidate(c).catch(() => { }); else CALL.ice.push(c);
  } else if (r.type === 'end' || r.type === 'decline') {
    callEnd(false, '');
  }
}
function callFlushIce() {
  if (!CALL.pc) return;
  CALL.ice.forEach(c => CALL.pc.addIceCandidate(c).catch(() => { }));
  CALL.ice = [];
}
async function callGetMic() {
  CALL.stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true } });
  CALL.stream.getAudioTracks().forEach(tr => { tr.enabled = !CALL.muted; });
}
async function callMakePc() {
  if (!CALL.stream) await callGetMic();
  CALL.remote = false; CALL.ice = [];
  const pc = new RTCPeerConnection({ iceServers: ICE });
  CALL.pc = pc;
  CALL.stream.getTracks().forEach(tr => pc.addTrack(tr, CALL.stream));
  pc.onicecandidate = e => {
    if (e.candidate) callSend(CALL.id, CALL.peer, 'ice', { sdp: e.candidate.candidate, mid: e.candidate.sdpMid || '', idx: e.candidate.sdpMLineIndex || 0 });
  };
  pc.ontrack = e => {
    const a = $('#call-audio');
    if (a) { a.srcObject = e.streams[0] || new MediaStream([e.track]); a.play().catch(() => { }); }
  };
  pc.oniceconnectionstatechange = () => {
    const st = pc.iceConnectionState;
    if ((st === 'connected' || st === 'completed') && CALL.st === 'connecting') {
      clearTimeout(CALL.tmo);
      CALL.st = 'active'; CALL.secs = 0;
      clearInterval(CALL.tick);
      CALL.tick = setInterval(() => { CALL.secs++; const el = $('#call-st'); if (el) el.textContent = callStatus(); }, 1000);
      renderCall();
    } else if (st === 'failed') {
      callEnd(true, t('Нет соединения', 'Connection failed', 'Keine Verbindung'));
    }
  };
}
async function callStart(peer) {
  if (!CALL_OK || CALL.st !== 'idle' || !peer || peer === 'ai') return;
  try { await callGetMic(); } catch (e) { toast(t('Нет доступа к микрофону', 'No access to the microphone', 'Kein Zugriff auf das Mikrofon')); return; }
  CALL.id = callUuid(); CALL.peer = peer; CALL.st = 'outgoing'; CALL.msg = ''; CALL.muted = false;
  const mine = CALL.id;
  callSend(mine, peer, 'invite', null, () => { if (CALL.id === mine && CALL.st === 'outgoing') callEnd(false, t('Не удалось позвонить', 'Could not place the call', 'Anruf fehlgeschlagen')); });
  clearTimeout(CALL.tmo);
  CALL.tmo = setTimeout(() => { if (CALL.st === 'outgoing') callEnd(true, t('Нет ответа', 'No answer', 'Keine Antwort')); }, 45000);
  renderCall();
}
async function callAccept() {
  if (CALL.st !== 'incoming') return;
  callRingStop();
  clearTimeout(CALL.tmo);
  try { await callGetMic(); } catch (e) { toast(t('Нет доступа к микрофону', 'No access to the microphone', 'Kein Zugriff auf das Mikrofon')); callDecline(); return; }
  CALL.st = 'connecting'; renderCall();
  await callMakePc();
  callSend(CALL.id, CALL.peer, 'accept');
  CALL.tmo = setTimeout(() => { if (CALL.st === 'connecting') callEnd(true, t('Нет соединения', 'Connection failed', 'Keine Verbindung')); }, 30000);
}
function callDecline() { if (CALL.st === 'incoming') callEnd(true, '', true); }
function callHang() { if (CALL.st !== 'idle') callEnd(true, ''); }
function callMute() {
  CALL.muted = !CALL.muted;
  if (CALL.stream) CALL.stream.getAudioTracks().forEach(tr => { tr.enabled = !CALL.muted; });
  renderCall();
}
function callEnd(notify, msg, decline) {
  if (notify && CALL.peer && CALL.st !== 'idle') callSend(CALL.id, CALL.peer, decline ? 'decline' : 'end');
  callRingStop();
  clearTimeout(CALL.tmo); clearInterval(CALL.tick); CALL.tick = null;
  try { if (CALL.pc) CALL.pc.close(); } catch (e) { }
  try { if (CALL.stream) CALL.stream.getTracks().forEach(tr => tr.stop()); } catch (e) { }
  const a = $('#call-audio'); if (a) a.srcObject = null;
  CALL.pc = null; CALL.stream = null; CALL.ice = []; CALL.remote = false;
  CALL.st = 'idle'; CALL.peer = null; CALL.secs = 0;
  renderCall();
  if (msg) toast(msg);
}
function callRingStart() {
  callRingStop();
  if (S.sound) beep();
  CALL.ring = setInterval(() => { if (S.sound) beep(); }, 1500);
}
function callRingStop() { if (CALL.ring) { clearInterval(CALL.ring); CALL.ring = null; } }
function callStatus() {
  if (CALL.st === 'outgoing') return t('Вызов…', 'Calling…', 'Anruf…');
  if (CALL.st === 'incoming') return t('Входящий звонок', 'Incoming call', 'Eingehender Anruf');
  if (CALL.st === 'connecting') return t('Соединение…', 'Connecting…', 'Verbindung…');
  return Math.floor(CALL.secs / 60) + ':' + String(CALL.secs % 60).padStart(2, '0');
}
function renderCall() {
  const el = $('#call');
  if (!el) return;
  if (CALL.st === 'idle') { el.classList.add('hidden'); el.innerHTML = ''; return; }
  const p = D.profiles[CALL.peer];
  const btns = CALL.st === 'incoming'
    ? '<button class="cbtn red" data-act="call-decline" title="' + t('Отклонить', 'Decline', 'Ablehnen') + '">{i:phoneoff}</button><button class="cbtn green" data-act="call-accept" title="' + t('Принять', 'Accept', 'Annehmen') + '">{i:phone}</button>'
    : '<button class="cbtn ' + (CALL.muted ? 'on' : '') + '" data-act="call-mute" title="' + t('Микрофон', 'Microphone', 'Mikrofon') + '">' + (CALL.muted ? '{i:micoff}' : '{i:mic}') + '</button><button class="cbtn red" data-act="call-hang" title="' + t('Завершить', 'Hang up', 'Auflegen') + '">{i:phoneoff}</button>';
  el.innerHTML = icons('<div class="call-box">' + avatarHtml(p, 120) + '<div class="call-nick">' + esc(p ? p.nick : '') + '</div><div class="call-st" id="call-st">' + callStatus() + '</div><div class="call-btns">' + btns + '</div></div>');
  el.classList.remove('hidden');
}

/* ---------- обновления приложения (Electron) ---------- */
let UPD = null;
function updShow(info) {
  UPD = info;
  const el = $('#upd'); if (!el) return;
  el.innerHTML = '<div class="upd-box"><div class="upd-t">' + t('Доступно новое обновление ', 'A new update is available ', 'Neues Update verfügbar ') + esc(info.version) + '</div>' +
    '<div class="upd-b"><button class="btn sm" data-act="upd-go">' + t('Установить', 'Install', 'Installieren') + '</button><button class="btn sm ghost" data-act="upd-skip">' + t('Не устанавливать', 'Not now', 'Nicht jetzt') + '</button></div></div>';
  el.classList.remove('hidden');
}
function updHide() { const el = $('#upd'); if (el) { el.classList.add('hidden'); el.innerHTML = ''; } }
async function updGo() {
  const el = $('#upd'); if (!el || !UPD) return;
  el.innerHTML = '<div class="upd-box"><div class="upd-t" id="upd-p">' + t('Скачивание…', 'Downloading…', 'Herunterladen…') + ' 0%</div></div>';
  const r = await nxDesktop.downloadUpdate();
  updHide();
  if (!r || r.error) { toast(t('Не удалось скачать обновление', 'Could not download the update', 'Update konnte nicht geladen werden')); return; }
  openDialog(t('Обновление скачано', 'Update downloaded', 'Update geladen'),
    '<div class="muted" style="margin-bottom:12px">' + t('Новая версия сохранена в папку «Загрузки». Положить её ещё и на рабочий стол?', 'The new version is saved in Downloads. Also put it on the desktop?', 'Die neue Version liegt in Downloads. Auch auf den Desktop legen?') + '</div>',
    [['upd-no', t('Нет', 'No', 'Nein'), 'ghost'], ['upd-desk', t('Да, на рабочий стол', 'Yes, on the desktop', 'Ja, auf den Desktop'), '']]);
}
async function updDesk() {
  closeDialog();
  const r = await nxDesktop.copyToDesktop();
  if (r && r.error) toast(t('Не удалось скопировать на рабочий стол', 'Could not copy to the desktop', 'Kopieren auf den Desktop fehlgeschlagen'));
  updDone(true);
}
function updDone() {
  closeDialog();
  nxDesktop.showDownloaded();
  toast(t('Закрой приложение и запусти новый файл', 'Close the app and run the new file', 'App schließen und neue Datei starten'));
}
if (window.nxDesktop) {
  nxDesktop.onProgress(p => { const el = $('#upd-p'); if (el) el.textContent = t('Скачивание…', 'Downloading…', 'Herunterladen…') + ' ' + p + '%'; });
  setTimeout(() => { nxDesktop.checkUpdate().then(info => { if (info) updShow(info); }).catch(() => { }); }, 1500);
}

/* ---------- старт ---------- */
applyTheme();
if (session) startApp(); else showAuth();
