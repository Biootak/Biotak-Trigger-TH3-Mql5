#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dead-doors.py - functions that exist in MT5 but that nothing calls.

A port can carry a whole subsystem and forget the DOOR that reaches it. The
knot-sample capture (P-BK-124) is the proven case: the shot, the 38-key sample
and the one-second flash were ported on 2026-10-27 and `BaseKnotCaptureSample()`
kept ZERO call sites until 2026-10-28 - the 'K' key the user presses did
nothing, and no compile, no line count and no module report could see it.

So: for every function DEFINED in the MT5 product/engine modules, count how
many times its name is CALLED anywhere in the MT5 tree (comments and string
literals excluded). Zero call sites = no door.
  * MT4 calls it  -> LOST DOOR: a real parity defect.
  * MT4 does not  -> DEAD CODE: cleanup, not a parity question.

  python tools/parity/dead-doors.py                # both tables
  python tools/parity/dead-doors.py --lost         # only what MT4 reaches
  python tools/parity/dead-doors.py --module TH3Tool.mqh

Read-only. Never writes.
"""
import argparse
import importlib.util
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

_spec = importlib.util.spec_from_file_location(
    "module_report", os.path.join(HERE, "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)

IDENT = re.compile(r"^[A-Za-z_]\w*$")
ANY_CALL = re.compile(r"\b([A-Za-z_]\w*)\s*\(")

# Entry points the TERMINAL calls, not us. A zero count here is correct.
EVENTS = {
    "OnInit", "OnDeinit", "OnCalculate", "OnTimer", "OnChartEvent", "OnTick",
    "OnStart", "OnTester", "OnTesterInit", "OnTesterPass", "OnTesterDeinit",
    "OnTrade", "OnTradeTransaction", "OnBookEvent", "OnDragStart", "OnDrag",
    "OnDragEnd", "OnMouseMove", "OnKeyDown", "OnKeyUp", "OnNavigate",
    "OnRemote", "OnClick", "OnMQL5", "OnActivate", "OnClose", "OnPrint",
    "OnTradeRequest", "OnPositionClose",
}


def code_text(path):
    """The file as one comment-free string, strings kept (a name in a string is
    still not a call, but stripping strings would eat `"a" + name(...)`)."""
    with open(path, "r", encoding="utf-8-sig", errors="replace", newline="") as fh:
        raw = fh.read()
    out, i, n = [], 0, len(raw)
    in_block = False
    while i < n:
        c = raw[i]
        if in_block:
            if c == "*" and i + 1 < n and raw[i + 1] == "/":
                in_block = False
                i += 2
            else:
                i += 1
            continue
        if c == "/" and i + 1 < n and raw[i + 1] == "*":
            in_block = True
            i += 2
            continue
        if c == "/" and i + 1 < n and raw[i + 1] == "/":
            while i < n and raw[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def modules(base, patterns=("*.mqh", "*.mq5")):
    found = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames
                       if d.lower() not in ("_retired", "build-logs", ".git",
                                            ".agent-tmp", "__pycache__")]
        for fn in filenames:
            if any(fn.endswith(p[1:]) for p in patterns):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def definitions(files):
    """(name, file) for every FUNCTION this tree defines.

    `#define` names are skipped: a macro is not a callable door, and treating one as
    a function buried the real findings under ~1900 constants on the first run."""
    out = []
    for path in files:
        lines = MR.read(path)
        for name, body in MR.chunks(lines):
            if not IDENT.match(name) or name in EVENTS:
                continue
            if body and body[0].lstrip().startswith("#"):
                continue
            # a struct/enum/class is not a door: its header line has no `name(`
            if not body or not re.search(r"\b%s\s*\(" % re.escape(name), body[0]):
                continue
            out.append((name, path))
    return out


def call_tally(text):
    """name -> how many times the name is followed by '(' in this text."""
    out = {}
    for m in ANY_CALL.finditer(text):
        n = m.group(1)
        out[n] = out.get(n, 0) + 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lost", action="store_true", help="only functions MT4 reaches")
    ap.add_argument("--module", default=None, help="one module basename")
    ap.add_argument("--limit", type=int, default=0, help="cap rows per table")
    a = ap.parse_args()

    mt5_files = modules(os.path.join(ROOT, "Biotak")) \
        + modules(os.path.join(ROOT, "Engine")) \
        + modules(os.path.join(ROOT, "MT5Compat")) \
        + modules(ROOT)
    mt5_files = sorted(set(os.path.normcase(p) for p in mt5_files))
    mt5_files = [p for p in mt5_files
                 if os.sep + "tools" + os.sep not in p and os.sep + "docs" + os.sep not in p]

    mt4_root = getattr(MR, "MT4_BIOTAK", None)
    if not mt4_root or not os.path.isdir(mt4_root):
        sys.exit("MT4 reference tree not found (module-report.MT4_BIOTAK)")
    mt4_files = modules(os.path.dirname(os.path.normpath(mt4_root)))
    mt4_tally = call_tally("\n".join(code_text(p) for p in mt4_files))
    mt4_defs = {}
    for name, _path in definitions(mt4_files):
        mt4_defs[name] = mt4_defs.get(name, 0) + 1

    mt5_tally = call_tally("\n".join(code_text(p) for p in mt5_files))

    defs = definitions(mt5_files)
    if a.module:
        defs = [d for d in defs if os.path.basename(d[1]).lower() == a.module.lower()]

    dups = {}
    for name, path in defs:
        dups.setdefault(name, []).append(path)

    lost, dead = [], []
    for name, paths in sorted(dups.items()):
        n = mt5_tally.get(name, 0) - len(paths)   # the definition itself matches
        if n > 0:
            continue
        rel = os.path.relpath(paths[0], ROOT)
        row = (name, rel, len(paths),
               max(0, mt4_tally.get(name, 0) - mt4_defs.get(name, 0)))
        (lost if row[3] > 0 else dead).append(row)

    def table(rows, title):
        print("=" * 78)
        print(title)
        print("=" * 78)
        if not rows:
            print("  (none)")
            print()
            return
        print("%-40s %-26s %4s %4s" % ("function", "defined in", "defs", "MT4"))
        print("-" * 78)
        shown = rows if not a.limit else rows[:a.limit]
        for name, rel, nd, n4 in shown:
            print("%-40s %-26s %4d %4d" % (name, rel, nd, n4))
        if a.limit and len(rows) > a.limit:
            print("... %d more" % (len(rows) - a.limit))
        print("-" * 78)
        print("%d function%s\n" % (len(rows), "" if len(rows) == 1 else "s"))

    table(lost, "LOST DOORS - MT5 defines it, nothing in MT5 calls it, MT4 DOES")
    if not a.lost:
        table(dead, "DEAD CODE - nothing calls it on either side (cleanup, not parity)")

    print("VERDICT: %d lost door(s), %d dead function(s)" % (len(lost), len(dead)))
    return 0 if not lost else 1


if __name__ == "__main__":
    sys.exit(main())
