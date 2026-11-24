import re, glob

def shrink_font(n):
    n = int(n)
    if n <= 12: return n
    if n <= 20: return n - 2
    return max(9, round(n * 0.8))

def shrink_dim(n):
    n = int(n)
    if n <= 20: return n
    if n > 60: return n
    return max(16, round(n * 0.88))

files = glob.glob('android/app/src/main/java/app/neirox/*.kt')
total = 0
for f in files:
    with open(f, encoding='utf-8') as fh:
        src = fh.read()
    orig = src

    src = re.sub(r'fontSize\s*=\s*(\d+)\.sp', lambda m: f'fontSize = {shrink_font(m.group(1))}.sp', src)
    src = re.sub(r'\.(height|size|width)\((\d+)\.dp\)', lambda m: f'.{m.group(1)}({shrink_dim(m.group(2))}.dp)', src)
    src = re.sub(r'padding\(horizontal\s*=\s*(\d+)\.dp\)', lambda m: f'padding(horizontal = {shrink_dim(m.group(1))}.dp)', src)
    src = re.sub(r'padding\(vertical\s*=\s*(\d+)\.dp\)', lambda m: f'padding(vertical = {shrink_dim(m.group(1))}.dp)', src)
    src = re.sub(r'padding\((\d+)\.dp\)', lambda m: f'padding({shrink_dim(m.group(1))}.dp)', src)

    if src != orig:
        total += 1
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(src)
        print('changed', f)
print('files changed:', total)
