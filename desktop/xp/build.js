// Сборка версии для Windows XP / Vista: переписывает приложение под Chromium 49
const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');
const postcss = require('postcss');

const src = path.join(__dirname, '..', 'app');
const out = path.join(__dirname, 'out', 'package.nw');
const app = path.join(out, 'app');
fs.rmSync(path.join(__dirname, 'out'), { recursive: true, force: true });
fs.mkdirSync(app, { recursive: true });

// 1) Babel переписывает современный JS (async/await, деструктуризация и т.д.) под Chromium 49
const babel = require('@babel/core');
const tmp = path.join(__dirname, 'tmp');
fs.mkdirSync(tmp, { recursive: true });
const res = babel.transformSync(fs.readFileSync(path.join(src, 'app.js'), 'utf8'), {
  babelrc: false, configFile: false, sourceType: 'script', compact: false,
  presets: [[require.resolve('@babel/preset-env'), { targets: { chrome: '49' }, bugfixes: false, modules: false }]]
});
fs.writeFileSync(path.join(tmp, 'app.es5.js'), res.code);
// 2) esbuild собирает всё в один файл вместе с полифилами (без дополнительных преобразований)
esbuild.buildSync({
  entryPoints: [path.join(__dirname, 'entry.js')],
  bundle: true,
  minify: false,
  target: ['es2020'],
  format: 'iife',
  outfile: path.join(app, 'app.js'),
  logLevel: 'warning'
});

for (const f of ['index.html', 'emoji-font.css']) fs.copyFileSync(path.join(src, f), path.join(app, f));
fs.cpSync(path.join(src, 'fonts'), path.join(app, 'fonts'), { recursive: true });

// CSS: gap -> отступы, inset -> top/right/bottom/left, min() -> обычные значения
let css = fs.readFileSync(path.join(src, 'style.css'), 'utf8');
css = css.replace('max-width:min(520px,75%)', 'max-width:75%').replace('width:min(420px,92vw)', 'width:420px;max-width:92vw');
const root = postcss.parse(css);
root.walkRules(rule => {
  if (rule.parent && rule.parent.type === 'atrule' && /keyframes/.test(rule.parent.name)) return;
  let gap = null, column = false, wrap = false, grid = false;
  rule.walkDecls(d => {
    if (d.prop === 'gap') gap = d;
    if (d.prop === 'flex-direction' && /column/.test(d.value)) column = true;
    if (d.prop === 'flex-wrap' && /wrap/.test(d.value)) wrap = true;
    if (d.prop === 'display' && /grid/.test(d.value)) grid = true;
    if (d.prop === 'inset' && d.value.trim() === '0') {
      d.cloneBefore({ prop: 'top', value: '0' }); d.cloneBefore({ prop: 'right', value: '0' });
      d.cloneBefore({ prop: 'bottom', value: '0' }); d.cloneBefore({ prop: 'left', value: '0' });
      d.remove();
    }
  });
  if (gap && !grid) {
    const parts = gap.value.trim().split(/\s+/);
    const row = parts[0], colv = parts[1] || parts[0];
    const sels = rule.selectors.map(s => s + '>*');
    if (wrap) rule.parent.insertAfter(rule, postcss.parse(sels.join(',') + '{margin:0 ' + colv + ' ' + row + ' 0}').first);
    else if (column) rule.parent.insertAfter(rule, postcss.parse(rule.selectors.map(s => s + '>*+*').join(',') + '{margin-top:' + row + '}').first);
    else rule.parent.insertAfter(rule, postcss.parse(rule.selectors.map(s => s + '>*+*').join(',') + '{margin-left:' + colv + '}').first);
  }
});
fs.writeFileSync(path.join(app, 'style.css'), root.toString() + '\n' + fs.readFileSync(path.join(__dirname, 'xp.css'), 'utf8'));

// проверка: в итоговом файле не осталось синтаксиса новее ES2015
require('acorn').parse(fs.readFileSync(path.join(app, 'app.js'), 'utf8'), { ecmaVersion: 2015 });
fs.writeFileSync(path.join(out, 'package.json'), JSON.stringify({
  name: 'neirox',
  main: 'app/index.html',
  window: { title: 'neirox', width: 1100, height: 740, min_width: 720, min_height: 520 },
  'chromium-args': '--disable-web-security --allow-file-access-from-files'
}, null, 2));
console.log('XP bundle ready:', out);
