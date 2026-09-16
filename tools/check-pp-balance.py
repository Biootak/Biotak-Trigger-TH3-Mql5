import re, sys

path = sys.argv[1]
src = open(path, encoding='utf-8-sig', errors='replace').read()

# Strip block comments, then line comments. Keep line numbering intact.
out = []
i = 0
in_block = False
for line in src.split('\n'):
    res = []
    j = 0
    while j < len(line):
        if in_block:
            k = line.find('*/', j)
            if k == -1:
                j = len(line)
            else:
                in_block = False
                j = k + 2
        else:
            k2 = line.find('/*', j)
            k3 = line.find('//', j)
            if k2 != -1 and (k3 == -1 or k2 < k3):
                res.append(line[j:k2])
                in_block = True
                j = k2 + 2
            elif k3 != -1:
                res.append(line[j:k3])
                j = len(line)
            else:
                res.append(line[j:])
                j = len(line)
    out.append(''.join(res))

depth = 0
stack = []
for n, line in enumerate(out, 1):
    s = line.strip()
    m = re.match(r'#\s*(ifdef|ifndef|if)\b', s)
    if m:
        depth += 1
        stack.append((n, s[:70]))
        continue
    if re.match(r'#\s*endif\b', s):
        if depth == 0:
            print(f'EXTRA #endif at line {n}')
        else:
            depth -= 1
            stack.pop()

print(f'final depth = {depth}')
for n, txt in stack:
    print(f'  UNCLOSED line {n}: {txt}')
