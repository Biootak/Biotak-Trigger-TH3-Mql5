#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Symbol-level unified diff: MT4 reference vs MT5 module, one symbol at a time.

gap-report.py says WHICH symbol drifted and how many lines.  This tool shows the
lines, so a human can decide whether the drift is a platform idiom or a lost fix.

  python tools/parity/sym-diff.py TradePlanFormulas.mqh
  python tools/parity/sym-diff.py BiotakPanels.mqh --sym PnlRowY
  python tools/parity/sym-diff.py DrawStrip.mqh --sym DrawStripAnchorOwner --context 6

Read-only.  Never writes.
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


def side_lines(path, is_mt4):
    if is_mt4:
        return MR.build_ref(path)
    return MR.read(path)


def symbols(lines):
    out = {}
    for name, body in MR.chunks(lines):
        out.setdefault(name, []).append(body)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("module")
    ap.add_argument("--sym", default=None, help="substring filter on the symbol name")
    ap.add_argument("--context", type=int, default=3)
    ap.add_argument("--all", action="store_true", help="print identical symbols too")
    ap.add_argument("--scan", action="store_true",
                    help="no bodies: classify EVERY symbol and rank by change size. "
                         "SAME means identical after norm_body (comments/whitespace aside); "
                         "DRIFT means the code itself differs.")
    a = ap.parse_args()

    p4 = os.path.join(MR.MT4_BIOTAK, a.module)
    p5 = os.path.join(MR.MT5_BIOTAK, a.module)
    if not os.path.exists(p4) or not os.path.exists(p5):
        print("not on both sides: %s" % a.module)
        return 2

    s4 = symbols(side_lines(p4, True))
    s5 = symbols(side_lines(p5, False))
    names = list(s4.keys()) + [n for n in s5.keys() if n not in s4]

    if a.scan:
        rows = []
        for name in names:
            if a.sym and a.sym.lower() not in name.lower():
                continue
            b4 = s4.get(name, [[]])[0]
            b5 = s5.get(name, [[]])[0]
            if b4 and b5 and MR.norm_body("\n".join(b4)) == MR.norm_body("\n".join(b5)):
                rows.append((0, name, len(b4), len(b5), "SAME"))
                continue
            raw = list(difflib.unified_diff(b4, b5, lineterm="", n=0))
            adds = sum(1 for l in raw if l.startswith("+") and not l.startswith("+++"))
            dels = sum(1 for l in raw if l.startswith("-") and not l.startswith("---"))
            tag = "EXTRA" if not b4 else ("MISSING" if not b5 else "DRIFT")
            rows.append((adds + dels, name, len(b4), len(b5),
                         "+%d/-%d %s" % (adds, dels, tag)))
        rows.sort(reverse=True)
        print("%-44s %5s %5s  %s" % ("symbol", "MT4", "MT5", "change"))
        print("-" * 78)
        for _, name, l4, l5, tag in rows:
            if tag == "SAME" and not a.all:
                continue
            print("%-44s %5d %5d  %s" % (name, l4, l5, tag))
        print("-" * 78)
        same = sum(1 for r in rows if r[4] == "SAME")
        print("%d symbols: %d SAME, %d changed" % (len(rows), same, len(rows) - same))
        return 0

    rc = 0
    for name in names:
        if a.sym and a.sym.lower() not in name.lower():
            continue
        b4 = s4.get(name, [[]])[0]
        b5 = s5.get(name, [[]])[0]
        if b4 and b5 and MR.norm_body("\n".join(b4)) == MR.norm_body("\n".join(b5)):
            if a.all:
                print("== %-44s SAME" % name)
            continue
        rc = 1
        tag = "MISSING(MT4 only)" if not b5 else ("EXTRA(MT5 only)" if not b4 else "DRIFT")
        print("=" * 78)
        print("== %s   [%s]  mt4=%d lines  mt5=%d lines" % (name, tag, len(b4), len(b5)))
        print("=" * 78)
        for ln in difflib.unified_diff(b4, b5, fromfile="MT4", tofile="MT5",
                                       n=a.context, lineterm=""):
            print(ln)
        print()
    return rc


if __name__ == "__main__":
    sys.exit(main())
