// Подстройка под Chromium 49 (Windows XP / Vista, NW.js 0.14)
(function () {
  try { history.replaceState(null, '', location.pathname + '?v=0.0.1%20trapped%20build'); } catch (e) { }
  if (!window.crypto) window.crypto = {};
  if (!crypto.randomUUID) {
    crypto.randomUUID = function () {
      var b = new Uint8Array(16);
      if (crypto.getRandomValues) crypto.getRandomValues(b); else for (var i = 0; i < 16; i++) b[i] = Math.floor(Math.random() * 256);
      b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
      var h = Array.prototype.map.call(b, function (x) { return (x + 256).toString(16).slice(1); }).join('');
      return h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20);
    };
  }
  // ссылки открываем в обычном браузере
  var nwShell = null;
  try { nwShell = (window.nw || require('nw.gui')).Shell; } catch (e) { }
  var origOpen = window.open;
  window.open = function (u) {
    if (nwShell && /^https?:\/\//i.test(u)) { nwShell.openExternal(u); return null; }
    return origOpen ? origOpen.apply(window, arguments) : null;
  };
})();
