#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Dead local detector: a local built and never read.

WHY THIS EXISTS. The user's complaint is «محاسبات الکی» — arithmetic that costs a
frame and changes nothing. The compiler does not warn on an unused *initialised*
local in MQL5, so these live for years: `double oldBasePrice = g_basePriceCached;`,
`datetime serverTime = TimeCurrent();` (a syscall per call), `int headBot = …`.

METHOD. Every function body is cut out by the same chunker the parity tools use.
Inside it, a name that occurs EXACTLY ONCE is either the declaration itself or a
write target. Both are dead: nothing reads it. Names that are function calls,
struct fields, array subscripts of globals, or `&`-out parameters are excluded by
requiring the declaration shape `type name = …;` / `type name;` at statement start
and by counting identifier occurrences (not substrings).

False positives are possible where a name is used only inside a string or a
comment; the report prints the declaration line so a human can confirm in one look.

  python tools/bughunt/dead-locals.py              # whole Biotak tree
  python tools/bughunt/dead-locals.py --only DrawStrip.mqh
"""
import argparse
import importlib.util
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PARITY = os.path.join(ROOT, "tools", "parity")
_spec = importlib.util.spec_from_file_location("module_report", os.path.join(PARITY, "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)

TYPES = r"(?:int|uint|long|ulong|short|ushort|char|uchar|bool|double|float|string|color|datetime|void)"
DECL = re.compile(r"^\s*(?:static\s+|const\s+)*" + TYPES + r"\s+([A-Za-z_]\w*)\s*(?:=|;|\[)")
IDENT = re.compile(r"\b[A-Za-z_]\w*\b")


def strip_comments(line):
    i = line.find("//")
    if i >= 0:
        line = line[:i]
    return line


def scan(path):
    lines = MR.read(path)
    hits = []
    for name, body in MR.chunks(lines):
        head = body[0].lstrip() if body else ""
        # a struct/class/enum body is a TYPE, not a function: its "locals" are fields
        if head.startswith(("struct ", "class ", "enum ", "union ", "typedef ")):
            continue
        if head.startswith("#"):
            continue
        # a file-scope declaration run is not a function body
        if name in ("#decls", "(block)"):
            continue
        text = "\n".join(strip_comments(b) for b in body)
        counts = {}
        for tok in IDENT.findall(text):
            counts[tok] = counts.get(tok, 0) + 1
        depth = 0
        for raw in body:
            s = strip_comments(raw)
            if depth >= 1:                       # inside the function's braces
                m = DECL.match(s)
                if m:
                    var = m.group(1)
                    if counts.get(var, 0) <= 1:
                        hits.append((name, var, raw.strip()))
            depth += s.count("{") - s.count("}")
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    a = ap.parse_args()
    base = os.path.join(ROOT, "Biotak")
    files = a.only or sorted(f for f in os.listdir(base) if f.endswith(".mqh"))
    total = 0
    for f in files:
        p = os.path.join(base, f)
        if not os.path.exists(p):
            continue
        hits = scan(p)
        if not hits:
            continue
        print("## %s" % f)
        for fn, var, decl in hits:
            total += 1
            print("   %-42s %-22s %s" % (fn, var, decl))
    print("\nDEAD LOCALS: %d" % total)


if __name__ == "__main__":
    main()
