#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit the parity checker's OWN blind spots: the declared symbol rewrites.

WHY THIS EXISTS
    module-report.py proves the two trees are the same code by comparing the
    MULTISET OF LINES per module. Two things are excluded from that verdict by
    design, and both are places where real behaviour can hide:

      * DECLARED_SYMBOL_REWRITES - a symbol whose MT5 body is allowed to differ
        (e.g. MT4's strip-local ask/take became MT5's RequestUISync). The tool
        treats the rewrite AS the implementation, so it never asks whether the
        replacement DOES the same thing.
      * MODULE_PATCHES - a declared one-sided block, justified line by line.

    MEASURED 2026-10-23: the LAST OBJECT switch flipped its flag in MT5 and
    never re-ran the ATR/label/level/plan pass, because the press asked
    `RequestUISync` (whose drain paints the ring light and the open card only)
    where MT4 asks a bridge drained as `RefreshDisplay(REFRESH_ALL)` in the same
    event. Both trees read GREEN: the difference sits inside two rewritten
    symbols. This tool is the check that would have caught it.

WHAT IT REPORTS
    For every declared rewrite, the CALL SET of each side (function names the
    body invokes). A name only MT4 calls is a behaviour whose MT5 replacement
    does something else - the review list. Pure formatting never shows up here,
    because names, not lines, are compared.

  python tools/parity/rewrite-audit.py                 # every declared rewrite
  python tools/parity/rewrite-audit.py --only DrawStrip.mqh
  python tools/parity/rewrite-audit.py --calls         # print the call sets too
  python tools/parity/rewrite-audit.py --gaps          # only the flagged ones

Read-only. Never writes.
"""
import argparse
import importlib.util
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "module_report", os.path.join(HERE, "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)

# A call is `name(` that is not a declaration ( `type name(` ) and not a keyword.
RE_CALL = re.compile(r"(?<![\w.])([A-Za-z_]\w*)\s*\(")
KEYWORDS = {
    'if', 'for', 'while', 'switch', 'return', 'sizeof', 'else', 'do', 'case',
    'catch', 'new', 'delete', 'static_cast', 'dynamic_cast', 'const_cast',
    'reinterpret_cast',
}
# Declarations read as calls in a naive scan; drop the ones this project uses.
RE_STRIP_COMMENT = re.compile(r"//.*$")
RE_STRIP_BLOCK = re.compile(r"/\*.*?\*/", re.S)


def calls(body):
    text = RE_STRIP_BLOCK.sub("", "\n".join(body))
    text = "\n".join(RE_STRIP_COMMENT.sub("", ln) for ln in text.splitlines())
    out = set()
    for m in RE_CALL.finditer(text):
        n = m.group(1)
        if n not in KEYWORDS:
            out.add(n)
    return out


def bodies_of(lines):
    """name -> list of bodies (a symbol can appear more than once)."""
    out = {}
    for name, body in MR.chunks(lines):
        out.setdefault(name, []).append(body)
    return out


def reachable(name, graph, seen=None):
    """A symbol's TRANSITIVE call set, inside the same module.

    A call the MT4 body makes is not lost just because the MT5 body moved it
    into a helper it now calls (measured: MT5's OnInitHandler delegates the
    label upgrade / pattern restore / TH3 step to AttachToolRestoreLegacy).
    Only a call that no path from the MT5 body reaches is a real gap, so the
    comparison runs on the closure, not on one body's own text.
    """
    if seen is None:
        seen = set()
    if name in seen:
        return set()
    seen.add(name)
    direct = graph.get(name)
    if not direct:
        return set()
    out = set(direct)
    for callee in direct:
        if callee in graph:
            out |= reachable(callee, graph, seen)
    return out


def graph_of(bodies):
    """name -> direct call set, for the names this module DEFINES."""
    return {n: calls(b[0]) for n, b in bodies.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--calls", action="store_true")
    ap.add_argument("--gaps", action="store_true")
    a = ap.parse_args()

    total = flagged = 0
    for mod, decl in sorted(MR.DECLARED_SYMBOL_REWRITES.items()):
        if a.only and not any(o in mod for o in a.only):
            continue
        p4 = os.path.join(MR.MT4_BIOTAK, mod)
        p5 = os.path.join(MR.MT5_BIOTAK, mod)
        if not (os.path.exists(p4) and os.path.exists(p5)):
            print("!! %-28s not on both sides" % mod)
            continue
        s4 = bodies_of(MR.build_ref(p4))
        s5 = bodies_of(MR.read(p5))
        g4 = graph_of(s4)
        g5 = graph_of(s5)

        print("=" * 78)
        print("%s   (%d declared rewrite symbols)" % (mod, len(decl)))
        print("=" * 78)
        for name in sorted(decl):
            total += 1
            b4 = s4.get(name)
            b5 = s5.get(name)
            if b4 is None:
                print("  MISSING in MT4 reference: %s" % name)
                continue
            if b5 is None:
                print("  %-42s MT4 only - no MT5 body at all" % name)
                flagged += 1
                continue
            c4 = reachable(name, g4)
            c5 = reachable(name, g5)
            only4 = sorted(c4 - c5)
            only5 = sorted(c5 - c4)
            if not only4 and not only5:
                if a.calls:
                    print("  %-42s same call set (%d)" % (name, len(c4)))
                continue
            flagged += 1
            if a.gaps or True:
                print("  %-42s mt4=%3d mt5=%3d lines" % (name, len(b4[0]), len(b5[0])))
                if only4:
                    print("      MT4 calls MT5 never does: %s" % ", ".join(only4[:14]))
                if only5:
                    print("      MT5 calls MT4 never does: %s" % ", ".join(only5[:14]))
                if a.calls:
                    print("      mt4 calls: %s" % ", ".join(sorted(c4)))
                    print("      mt5 calls: %s" % ", ".join(sorted(c5)))
        print()

    print("-" * 78)
    print("declared rewrite symbols checked: %d   with a call-set gap: %d"
          % (total, flagged))
    return 0


if __name__ == "__main__":
    sys.exit(main())
