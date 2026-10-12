"""One-time fork: rewrite GENERATED MIRROR headers to OWNED.

For every Biotak/*.mqh that carries the resync header, replace it with an
ownership header that keeps the MT4 source reference and the applied-patch
list, but drops the `regenerate` command. After this, nothing rewrites these
files; module-report.py (read-only) remains the drift detector.
"""
import io, os, re, sys

HERE = os.path.abspath(__file__)                      # <root>/tools/parity/_fork.py
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
BIO = os.path.join(ROOT, 'Biotak')

HDR_START = '// ============================================================================\n'
HDR_GEN = '// GENERATED MIRROR of the MetaTrader 4 source'

NEW_TOP = ('// ============================================================================\n'
           '// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.\n')

NEW_MID = ('//\n'
           '// MT4 remains the LOGIC reference and tools/parity/module-report.py flags\n'
           '// any drift, but nothing regenerates this file: MT5-only changes live here\n'
           '// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.\n')


def split_header(text):
    """Return (header_lines, rest) if the file starts with the mirror header."""
    lines = text.split('\n')
    if not lines or lines[0] != HDR_START.rstrip('\n'):
        return None
    if len(lines) < 3 or HDR_GEN not in lines[1] + lines[2]:
        return None
    for i in range(2, min(len(lines), 30)):
        if lines[i].startswith('// ==='):
            return lines[:i + 1], lines[i + 1:]
    return None


def main():
    changed, skipped = [], []
    for base, _d, files in os.walk(BIO):
        for fn in sorted(files):
            if not fn.endswith('.mqh'):
                continue
            p = os.path.join(base, fn)
            with io.open(p, encoding='utf-8-sig') as fh:
                text = fh.read().replace('\r\n', '\n')
            got = split_header(text)
            if not got:
                skipped.append(os.path.relpath(p, ROOT))
                continue
            hdr, rest = got
            src = [l for l in hdr if 'MT4 source' in l]
            patches = [l for l in hdr if l.strip().startswith('//   *')]
            new_hdr = [NEW_TOP.rstrip('\n')]
            new_hdr += src
            new_hdr += NEW_MID.rstrip('\n').split('\n')
            if patches:
                new_hdr += ['//', '// MT5-only changes this file already carries:']
                new_hdr += patches
            new_hdr += ['// ============================================================================']
            out = '\n'.join(new_hdr) + '\n' + '\n'.join(rest)
            with io.open(p, 'rb') as fh:
                raw = fh.read()
            had_bom = raw.startswith(b'\xef\xbb\xbf')
            out = '\n'.join(new_hdr) + '\n' + '\n'.join(rest)
            data = out.replace('\n', '\r\n').encode('utf-8')
            with io.open(p, 'wb') as fh:
                fh.write((b'\xef\xbb\xbf' if had_bom else b'') + data)
            changed.append(os.path.relpath(p, ROOT))
    print(f'rewritten: {len(changed)}')
    for c in changed:
        print('  +', c)
    print(f'skipped (no mirror header): {len(skipped)}')
    for s in skipped:
        print('  -', s)


if __name__ == '__main__':
    main()