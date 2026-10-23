#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compact triage of every drifted symbol: the changed lines only, side by side.

sym-diff.py prints a unified diff per symbol (good for one symbol, long for 181).
This prints one block per drifted symbol with just the -/+ lines, so a reviewer
can classify a whole module in one screen:

    - <line only in MT4>      + <line only in MT5>

Read-only.
"""
import argparse
import difflib
import importlib.util
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "module_report", os.path.join(HERE, "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)


def syms(lines):
    out = {}
    for name, body in MR.chunks(lines):
        out.setdefault(name, []).append(body)
    return out


def code(lines):
    return [x for x in (MR.norm_line(l) for l in lines) if x]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("modules", nargs="*")
    ap.add_argument("--max", type=int, default=6, help="max changed lines per side")
    a = ap.parse_args()

    mods = a.modules or sorted(
        f for f in os.listdir(MR.MT5_BIOTAK)
        if f.endswith(".mqh") and os.path.exists(os.path.join(MR.MT4_BIOTAK, f)))
    total = 0
    for mod in mods:
        p4 = os.path.join(MR.MT4_BIOTAK, mod)
        p5 = os.path.join(MR.MT5_BIOTAK, mod)
        if not (os.path.exists(p4) and os.path.exists(p5)):
            continue
        s4 = syms(MR.build_ref(p4))
        s5 = syms(MR.read(p5))
        rows = []
        for name in list(s4.keys()) + [n for n in s5 if n not in s4]:
            b4 = s4.get(name, [[]])[0]
            b5 = s5.get(name, [[]])[0]
            if b4 and b5 and MR.norm_body("\n".join(b4)) == MR.norm_body("\n".join(b5)):
                continue
            rows.append((name, b4, b5))
        if not rows:
            continue
        print("#### %s   (%d symbols)" % (mod, len(rows)))
        for name, b4, b5 in rows:
            total += 1
            m4 = [l for l in difflib.unified_diff(code(b4), code(b5), n=0, lineterm="")
                  if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))]
            print("  %-40s %s" % (name, "" if (b4 and b5) else ("MT5-only" if not b4 else "MT4-only")))
            shown = 0
            for l in m4:
                if shown >= a.max * 2:
                    print("      ... %d more" % (len(m4) - shown))
                    break
                print("      " + l)
                shown += 1
    print("\nDRIFTED SYMBOLS: %d" % total)


if __name__ == "__main__":
    main()
