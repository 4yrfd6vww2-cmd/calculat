// Подстройка под Chromium 49 (Windows XP / Vista, NW.js 0.14)
(function () {
  try { history.replaceState(null, '', location.pathname + '?v=0.0.4%20trapped%20build'); } catch (e) { }
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
  // обновления (в NW.js нет Electron-моста, делаем то же через Node)
  try {
    var fs = require('fs'), https = require('https'), path = require('path'), urlm = require('url');
    var CUR = '0.0.4', PREFIX = 'https://github.com/4yrfd6vww2-cmd/calculat/releases/download/';
    var pending = null, lastFile = null, progressCb = null;
    var home = process.env.USERPROFILE || process.env.HOME || '.';
    var newer = function (a, b) {
      var x = String(a).split('.'), y = String(b).split('.');
      for (var i = 0; i < 3; i++) { var p = Number(x[i] || 0), q = Number(y[i] || 0); if (p !== q) return p > q; }
      return false;
    };
    var getBuf = function (u, onP, n) {
      return new Promise(function (resolve, reject) {
        https.get(u, { headers: { 'User-Agent': 'neirox-xp' } }, function (res) {
          if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && (n || 0) < 5) {
            res.resume();
            return getBuf(urlm.resolve(u, res.headers.location), onP, (n || 0) + 1).then(resolve, reject);
          }
          if (res.statusCode !== 200) { res.resume(); return reject(new Error('HTTP ' + res.statusCode)); }
          var total = Number(res.headers['content-length'] || 0), got = 0, chunks = [];
          res.on('data', function (c) { chunks.push(c); got += c.length; if (onP && total) onP(Math.floor(got * 100 / total)); });
          res.on('end', function () { resolve(Buffer.concat(chunks)); });
          res.on('error', reject);
        }).on('error', reject);
      });
    };
    var firstDir = function (list) {
      for (var i = 0; i < list.length; i++) { try { if (fs.statSync(list[i]).isDirectory()) return list[i]; } catch (e) { } }
      return null;
    };
    window.nxDesktop = {
      checkUpdate: function () {
        return getBuf('https://4yrfd6vww2-cmd.github.io/calculat/version.json?t=' + Date.now()).then(function (b) {
          var e = JSON.parse(b.toString('utf8')).legacy_xp;
          if (!e || !e.url || e.url.indexOf(PREFIX) !== 0 || !newer(e.version, CUR)) return null;
          pending = e;
          return { version: e.version };
        }).catch(function () { return null; });
      },
      downloadUpdate: function () {
        if (!pending) return Promise.resolve({ error: 'no_update' });
        return getBuf(pending.url, function (p) { if (progressCb) progressCb(p); }).then(function (buf) {
          var dir = firstDir([path.join(home, 'Downloads'), path.join(home, 'Загрузки')]);
          if (!dir) { dir = path.join(home, 'Downloads'); try { fs.mkdirSync(dir); } catch (e) { } }
          var name = path.basename(urlm.parse(pending.url).pathname);
          var ext = path.extname(name);
          var dest = path.join(dir, name.slice(0, name.length - ext.length) + '-' + pending.version + ext);
          fs.writeFileSync(dest, buf);
          lastFile = dest;
          return { path: dest };
        }).catch(function (err) { return { error: String(err && err.message || err) }; });
      },
      copyToDesktop: function () {
        if (!lastFile) return Promise.resolve({ error: 'no_file' });
        var dir = firstDir([path.join(home, 'Desktop'), path.join(home, 'Рабочий стол')]);
        if (!dir) return Promise.resolve({ error: 'no_desktop' });
        try { var dest = path.join(dir, path.basename(lastFile)); fs.writeFileSync(dest, fs.readFileSync(lastFile)); return Promise.resolve({ path: dest }); }
        catch (err) { return Promise.resolve({ error: String(err && err.message || err) }); }
      },
      showDownloaded: function () {
        try { (window.nw || require('nw.gui')).Shell.showItemInFolder(lastFile); } catch (e) { }
        return Promise.resolve(true);
      },
      onProgress: function (cb) { progressCb = cb; },
      attention: function () { }
    };
  } catch (e) { }
  // ссылки открываем в обычном браузере
  var nwShell = null;
  try { nwShell = (window.nw || require('nw.gui')).Shell; } catch (e) { }
  var origOpen = window.open;
  window.open = function (u) {
    if (nwShell && /^https?:\/\//i.test(u)) { nwShell.openExternal(u); return null; }
    return origOpen ? origOpen.apply(window, arguments) : null;
  };
})();
