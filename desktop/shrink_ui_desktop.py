import re

def shrink_font(n):
    n = int(n)
    if n <= 12:
        return n
    if n <= 20:
        return n - 2
    return max(9, round(n * 0.8))

def shrink_dim(n):
    n = int(n)
    if n <= 20:
        return n
    if n > 60:
        return n
    return max(16, round(n * 0.88))

FONT_PROPS = ('font-size',)
DIM_PROPS = ('padding', 'margin', 'gap', 'width', 'height', 'min-width', 'min-height')

def make_css_sub(props, fn):
    pattern = re.compile(r'\b(' + '|'.join(props) + r'):\s*(\d+)px')
    def repl(m):
        return m.group(1) + ':' + str(fn(int(m.group(2)))) + 'px'
    return pattern, repl

def shrink_css(text):
    for props, fn in ((FONT_PROPS, shrink_font), (DIM_PROPS, shrink_dim)):
        pattern, repl = make_css_sub(props, fn)
        text = pattern.sub(repl, text)
    return text

for path in ['app/style.css']:
    s = open(path, encoding='utf-8').read()
    s2 = shrink_css(s)
    open(path, 'w', encoding='utf-8').write(s2)
    print(path, 'changed' if s2 != s else 'unchanged')

# app.js: only inline style="..." strings, same property set
def shrink_inline_styles(text):
    def repl(m):
        style = m.group(1)
        style2 = shrink_css(style)
        return 'style="' + style2 + '"' if m.group(0).startswith('style="') else "style='" + style2 + "'"
    text = re.sub(r'style="([^"]*)"', lambda m: 'style="' + shrink_css(m.group(1)) + '"', text)
    text = re.sub(r"style='([^']*)'", lambda m: "style='" + shrink_css(m.group(1)) + "'", text)
    return text

for path in ['app/app.js']:
    s = open(path, encoding='utf-8').read()
    s2 = shrink_inline_styles(s)
    open(path, 'w', encoding='utf-8').write(s2)
    print(path, 'changed' if s2 != s else 'unchanged')
