#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unguarded division by a counted variable.

The P-BE-05 class: `int segW=(W-(n-1)*gap)/n;` where `n` is a row/spec count that
is zero for an empty list. Integer division by zero in MQL is UB (the terminal
answers a garbage value or dies), so every such site needs a guard or a proven
non-zero divisor.

METHOD. Every `/ name` (and `% name`) whose divisor is an identifier — not a
literal, not a #define constant — is a candidate. A guard is accepted when the
same function contains, before the site, any of:
    if(name > 0) / if(name != 0) / if(name <= 0) return / MathMax(1, name)
    (name > 0 ? ... ) / name = MathMax(name, 1)
Constants in ALL_CAPS are skipped (they are #defines with a known value).

  python tools/bughunt/div-guard.py            # whole tree
  python tools/bughunt/div-guard.py --only BiotakPanels.mqh
"""
import argparse
import importlib.util
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
_spec = importlib.util.spec_from_file_location("module_report",
                                               os.path.join(ROOT, "tools", "parity", "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)

DIV = re.compile(r"[^/*]/\s*([A-Za-z_]\w*)|\bmod\s+([A-Za-z_]\w*)")
GUARDS = [
    # `if(x > 0)`, `if(!(x > 0))`, `if(!(x > 0.0) || ...)`, `if(x >= 1)`
    r"if\s*\(\s*!?\s*\(?\s*{n}\s*>",
    r"if\s*\(\s*{n}\s*!=\s*0", r"if\s*\(\s*{n}\s*<=\s*0",
    r"if\s*\(\s*{n}\s*<\s*1", r"if\s*\(\s*!\s*{n}\s*\)",
    r"if\s*\(\s*0\s*==\s*{n}", r"if\s*\(\s*{n}\s*==\s*0",
    r"MathMax\s*\(\s*{n}\s*,", r"MathMax\s*\(\s*1\s*,\s*{n}",
    r"{n}\s*>\s*0\s*\?", r"{n}\s*==\s*0",
    # the project's own two zero tests: an epsilon compare and a finite-first gate
    r"IsZero\s*\(\s*{n}\b", r"MathIsValidNumber\s*\(\s*{n}\b",
    r"MathAbs\s*\(\s*{n}\s*\)\s*>",
]


def scan(path):
    lines = MR.read(path)
    out = []
    for fn, body in MR.chunks(lines):
        if fn in ("#decls", "(block)") or body[0].lstrip().startswith(("#", "struct ", "class ", "enum ")):
            continue
        text = "\n".join(body)
        for i, raw in enumerate(body):
            code = raw.split("//")[0]
            if "/" not in code and "mod" not in code:
                continue
            for m in DIV.finditer(code):
                name = m.group(1) or m.group(2)
                if not name or name.isupper() or name[0].isupper():
                    continue
                if name in ("2", "10", "100", "1000"):
                    continue
                head = "\n".join(body[:i])
                guarded = any(re.search(g.format(n=re.escape(name)), head) for g in GUARDS)
                if not guarded:
                    out.append((fn, name, raw.strip()))
    return out


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
        if hits:
            print("## %s" % f)
            for fn, name, line in hits:
                total += 1
                print("   %-40s /%-14s %s" % (fn, name, line[:100]))
    print("\nUNGUARDED DIVISIONS: %d" % total)


if __name__ == "__main__":
    main()
