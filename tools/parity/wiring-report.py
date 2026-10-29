#!/usr/bin/env python3
"""WIRING REPORT - the behaviour the line diff cannot see.

`module-report.py` compares the TEXT of shared code. A body can be byte-identical
and still be wired wrong: the same call with a different argument (a stop where
the drawn entry belongs), a call that exists but is never made (a flash that
never ages), a function whose every caller passes the wrong unit. All three
happened in this fork, and every one of them read as "ported" in the line diff.

This tool answers a different question: for each function defined in BOTH trees,
does MT5 call the SAME functions, with the SAME arguments, in the SAME places?

  * Both trees are parsed whole (MQL is one translation unit per entry), so the
    MT4 `_A/_B` file split cannot hide a caller.
  * A call is compared as `callee(normalized arguments)` - whitespace collapsed,
    comments dropped, everything else (identifiers, literals, order) kept.
  * Only callees that are DEFINED IN BOTH TREES are compared: platform calls
    (ObjectSetInteger, iHigh, MathMax ...) and one-sided helpers are out.

Usage:
  python tools/parity/wiring-report.py               # summary + worst rows
  python tools/parity/wiring-report.py --only BaseKnot_Plan.mqh
  python tools/parity/wiring-report.py --min 1 --quiet
"""
import argparse
import collections
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
MT5_REPO = os.path.dirname(os.path.dirname(HERE))
MT4_REPO = os.path.join(os.path.dirname(MT5_REPO), "Biotak-Trigger-TH3-mql4")

SIG = re.compile(
    r'^[ \t]*(?:static[ \t]+)?(?:void|bool|int|double|string|datetime|long|uint|'
    r'color|ushort|ENUM_[A-Za-z_]+)[ \t]+([A-Za-z_]\w*)[ \t]*\(', re.M)
CALL = re.compile(r'\b([A-Za-z_]\w*)\s*\(')
KEYWORDS = {
    "if", "for", "while", "switch", "return", "sizeof", "else", "do",
    "FOREACH", "TRUE", "FALSE", "NULL", "EMPTY_VALUE", "INVALID_HANDLE",
}


def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def strip_comments(src):
    out, i, n, q = [], 0, len(src), False
    while i < n:
        c = src[i]
        if c == '"':
            q = not q
            out.append(c)
            i += 1
            continue
        if not q and src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if not q and src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def functions(src):
    """name -> list of body texts (declarations without a body are skipped)."""
    src = strip_comments(src)
    out = collections.defaultdict(list)
    for m in SIG.finditer(src):
        name = m.group(1)
        i = src.find("(", m.end() - 1)
        depth, j = 0, i
        while j < len(src):
            if src[j] == "(":
                depth += 1
            elif src[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        k = j + 1
        while k < len(src) and src[k] in " \t\r\n":
            k += 1
        if k >= len(src) or src[k] != "{":
            continue
        depth, e = 0, k
        while e < len(src):
            if src[e] == "{":
                depth += 1
            elif src[e] == "}":
                depth -= 1
                if depth == 0:
                    break
            e += 1
        out[name].append(src[k:e + 1])
    return out


def tree_functions(root, exts=(".mqh", ".mq4", ".mq5")):
    merged = collections.defaultdict(list)
    parts = os.path.normpath(root).split(os.sep)
    for dp, _, fs in os.walk(root):
        rel = os.path.relpath(dp, root).split(os.sep)
        if any(p in ( ".git", "tests", "build-logs", "tools", "docs")
               for p in rel + parts[-1:]):
            continue
        for f in fs:
            if f.endswith(exts):
                for name, bodies in functions(read(os.path.join(dp, f))).items():
                    merged[name].extend(bodies)
    return merged


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


def calls_of(body):
    """callee(normalized args) for every call in the body."""
    out = []
    for m in CALL.finditer(body):
        name = m.group(1)
        if name in KEYWORDS:
            continue
        i = m.end() - 1
        depth, j = 0, i
        while j < len(body):
            if body[j] == "(":
                depth += 1
            elif body[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        out.append(name + "(" + norm(body[i + 1:j]) + ")")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--min", type=int, default=1)
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    f4 = tree_functions(MT4_REPO)
    f5 = tree_functions(MT5_REPO)
    shared = {n for n in f4 if n in f5 and (a.only is None or n in a.only)}

    rows = []
    for name in sorted(shared):
        c4 = collections.Counter()
        for b in f4[name]:
            c4.update(calls_of(b))
        c5 = collections.Counter()
        for b in f5[name]:
            c5.update(calls_of(b))
        # only callees that BOTH trees define: platform noise out
        keep = {k for k in set(c4) | set(c5)
                if (lambda kk: kk.split("(", 1)[0] in f4 and kk.split("(", 1)[0] in f5)(k)}
        miss = sorted(k for k in keep if c4[k] > c5.get(k, 0))
        extra = sorted(k for k in keep if c5[k] > c4.get(k, 0))
        if miss:
            rows.append((name, miss, extra))

    print("WIRING REPORT  mt4 calls that mt5 does not make (or makes with other arguments)")
    print("=" * 78)
    print("shared functions compared: %d   with a MISSING mt4 call: %d   (top %d shown)"
          % (len(shared), len(rows), min(a.top, len(rows))))
    if not a.quiet:
        for name, miss, extra in rows[:a.top]:
            print("\n%s" % name)
            for k in miss[:6]:
                print("   - %s" % k[:150])
            for k in extra[:6]:
                print("   + %s" % k[:150])
    total = sum(len(m) for _, m, _ in rows) + sum(len(e) for _, _, e in rows)
    print("\nDRIFT rows: %d" % total)


if __name__ == "__main__":
    main()
