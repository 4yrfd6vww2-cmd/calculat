import re, glob, sys

def shrink_font(n):
    n = int(n)
    if n <= 12: return n
    if n <= 20: return n - 2
    return max(9, round(n * 0.8))

def shrink_dim(n):
    n = int(n)
    if n <= 20: return n
    if n > 60: return n  # leave big content sizes (avatars/thumbnails/call screens) alone
    return max(16, round(n * 0.88))

files = glob.glob('Sources/**/*.swift', recursive=True)
total_changes = 0
for f in files:
    with open(f, encoding='utf-8') as fh:
        src = fh.read()
    orig = src

    def font_sub(m):
        return '.font(.system(size: ' + str(shrink_font(m.group(1)))
    src = re.sub(r'\.font\(\.system\(size:\s*(\d+)', font_sub, src)

    def size_sub(m):
        return 'size: ' + str(shrink_dim(m.group(1))) + ')'
    src = re.sub(r'(?<!\.system\()size:\s*(\d+)\)', size_sub, src)

    def h_sub(m):
        return 'frame(height: ' + str(shrink_dim(m.group(1))) + ')'
    src = re.sub(r'frame\(height:\s*(\d+)\)', h_sub, src)

    def wh_sub(m):
        return 'frame(width: ' + str(shrink_dim(m.group(1))) + ', height: ' + str(shrink_dim(m.group(2))) + ')'
    src = re.sub(r'frame\(width:\s*(\d+),\s*height:\s*(\d+)\)', wh_sub, src)

    def ph_sub(m):
        return '.padding(.horizontal, ' + str(shrink_dim(m.group(1))) + ')'
    src = re.sub(r'\.padding\(\.horizontal,\s*(\d+)\)', ph_sub, src)

    def pv_sub(m):
        return '.padding(.vertical, ' + str(shrink_dim(m.group(1))) + ')'
    src = re.sub(r'\.padding\(\.vertical,\s*(\d+)\)', pv_sub, src)

    def pb_sub(m):
        return '.padding(' + str(shrink_dim(m.group(1))) + ')'
    src = re.sub(r'\.padding\((\d+)\)', pb_sub, src)

    if src != orig:
        total_changes += 1
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(src)
        print('changed', f)

print('files changed:', total_changes)
