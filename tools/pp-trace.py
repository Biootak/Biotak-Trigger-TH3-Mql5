import re, sys

path = sys.argv[1]
src = open(path, encoding='utf-8-sig', errors='replace').read()

lines = []
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
                res.append(line[j:k2]); in_block = True; j = k2 + 2
            elif k3 != -1:
                res.append(line[j:k3]); j = len(line)
            else:
                res.append(line[j:]); j = len(line)
    lines.append(''.join(res))

depth = 0
events = []
for n, line in enumerate(lines, 1):
    s = line.strip()
    if re.match(r'#\s*(ifdef|ifndef|if)\b', s):
        depth += 1
        events.append((n, 'OPEN', depth, s[:60]))
    elif re.match(r'#\s*endif\b', s):
        events.append((n, 'CLOSE', depth, s[:60]))
        depth -= 1

prev = None
for n, k, d, txt in events:
    flag = ''
    if prev and prev[1] == 'OPEN' and k == 'OPEN' and prev[2] == d:
        flag = '   <== consecutive OPEN at same level'
    print('%6d %-6s d%d %s%s' % (n, k, d, txt, flag))
    prev = (n, k, d)
