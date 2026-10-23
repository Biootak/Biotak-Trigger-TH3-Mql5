#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""The last two STATIC blind spots: #define values and object-property writes.

module-report.py drops every preprocessor line (include guards and #include
architecture legitimately differ) - which also throws away `#define NAME value`.
And it compares whole lines, so a property write MOVED between two symbols, or
one that exists on only one side inside an otherwise-equal line set, can hide in
the noise of a large module.

Two questions, both cheap, both answered per module:

  --defines   Every `#define NAME` with its value, MT4 vs MT5. A constant that
              carries a different NUMBER is a silently different picture: no
              line comparison sees it because the line differs only in a token
              the preprocessor swallowed.

  --props     Every `OBJPROP_*` a module writes (ObjectSetInteger /
              ObjectSetDouble / ObjectSetString), counted per side. A property
              MT4 writes and MT5 never does is behaviour the mirror dropped -
              MEASURED 2026-10-23: this is the shape the BaseKnot selection bug
              would have taken had the property been absent rather than
              re-applied by the platform differently.

  python tools/parity/property-audit.py --defines
  python tools/parity/property-audit.py --props
  python tools/parity/property-audit.py --props --only DrawStrip.mqh --show

Read-only. Never writes.
"""
import argparse
import collections
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

RE_DEFINE = re.compile(r"^\s*#define\s+([A-Za-z_]\w*)(?:\s+(.*?))?\s*$")
RE_PROP = re.compile(r"OBJPROP_([A-Z_]+)")
# a define with no value is an include guard or a bare marker, not a constant
GUARDISH = re.compile(r"(_MQH|_H|_INCLUDED)$")
# The ONE file whose whole purpose is to differ: build_hash embedded by
# tools/gen-build-hash.js from that tree's own sources.
SKIP_DEFINES = {"Biotak/BuildHash.mqh"}
SKIP_DEFINE_NAMES = {"TH3_BUILD_TAG"}   # the generated stamp, re-exported


def side_lines(path, is4):
    return MR.build_ref(path) if is4 else MR.read(path)


def defines(lines):
    out = {}
    for ln in lines:
        if ln.lstrip().startswith("//"):
            continue
        m = RE_DEFINE.match(ln)
        if not m:
            continue
        name, val = m.group(1), (m.group(2) or "").strip()
        val = val.split("//")[0].strip()   # the trailing comment is not the value
        if not val:
            continue
        out.setdefault(name, val)
    return out


def resolve(val, table, depth=6):
    """Expand a value through the SAME side's #define table.

    MT4 writes `DSTRIP_GEAR_COL  PNL_WEL`, MT5 writes `DSTRIP_GEAR_COL  312`.
    Same number, different spelling - and a bare string compare calls that a
    drift, which is how a real gate loses its audience. Expands only a value
    that IS a bare identifier (possibly in parens); anything compound is left
    alone, so a genuinely different expression still shows.
    """
    seen = set()
    while depth > 0:
        s = val.strip()
        while s.startswith("(") and s.endswith(")"):
            s = s[1:-1].strip()
        if not re.match(r"^[A-Za-z_]\w*$", s) or s in seen or s not in table:
            return s
        seen.add(s)
        val = table[s]
        depth -= 1
    return val.strip()


def props(lines):
    c = collections.Counter()
    for ln in lines:
        code = ln.split("//")[0]
        for m in RE_PROP.finditer(code):
            c["OBJPROP_" + m.group(1)] += 1
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--defines", action="store_true")
    ap.add_argument("--props", action="store_true")
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--show", action="store_true")
    a = ap.parse_args()
    if not (a.defines or a.props):
        a.defines = a.props = True

    mods = [m for m in MR.modules()
            if not a.only or any(o in m[0] for o in a.only)]
    # Every module's defines, per side, so a name defined in ONE file (CardMetrics)
    # can be resolved when a DIFFERENT file writes it symbolically.
    all4, all5 = {}, {}
    for label, p4, p5 in mods:
        all4.update(defines(side_lines(p4, True)))
        all5.update(defines(side_lines(p5, False)))

    bad_def = bad_prop = 0
    for label, p4, p5 in mods:
        l4, l5 = side_lines(p4, True), side_lines(p5, False)
        notes = []

        if a.defines and label not in SKIP_DEFINES:
            d4, d5 = defines(l4), defines(l5)
            for name in sorted(set(d4) & set(d5)):
                if GUARDISH.search(name) or name in SKIP_DEFINE_NAMES:
                    continue
                v4 = resolve(d4[name], all4)
                v5 = resolve(d5[name], all5)
                if v4 != v5:
                    notes.append("  #define %-34s MT4=%s (%s) | MT5=%s (%s)"
                                 % (name, v4[:34], d4[name][:24],
                                    v5[:34], d5[name][:24]))
                    bad_def += 1
            if a.show:
                for name in sorted(set(d4) - set(d5)):
                    notes.append("  #define %-34s MT4 only (%s)" % (name, d4[name][:40]))
                for name in sorted(set(d5) - set(d4)):
                    notes.append("  #define %-34s MT5 only (%s)" % (name, d5[name][:40]))

        if a.props:
            p4c, p5c = props(l4), props(l5)
            for name in sorted(set(p4c) | set(p5c)):
                n4, n5 = p4c.get(name, 0), p5c.get(name, 0)
                if n4 and not n5:
                    notes.append("  %-30s MT4 writes it %dx, MT5 NEVER" % (name, n4))
                    bad_prop += 1
                elif a.show and n4 != n5:
                    notes.append("  %-30s MT4 %dx | MT5 %dx" % (name, n4, n5))

        if notes:
            print("=" * 78)
            print(label)
            print("=" * 78)
            for n in notes:
                print(n)

    print()
    print("-" * 78)
    print("define values that differ: %d    properties MT5 never writes: %d"
          % (bad_def, bad_prop))
    return 0 if not (bad_def or bad_prop) else 1


if __name__ == "__main__":
    sys.exit(main())
