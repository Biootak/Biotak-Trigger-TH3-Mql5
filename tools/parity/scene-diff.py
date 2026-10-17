#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Scene diff for the R-RENDER-ENGINE verification: the canvas picture (MT5)
against the object picture (MT4).  One question: does the engine DRAW what the
MT4 object path DREW?

Inputs are two dumps in the same row schema:

    type;name;price;color;style;width;size;font;text

    MT5  - written by RBridgeDumpCsv (compile with #define BTRS_SCENE_DUMP and
           set the global variable BTRS_DUMP=1 in the terminal):
           MQL5\\Files\\BTRS_scene_MT5.csv
    MT4  - written by tools/mt4-scene-dump.mq4 run on the mirrored chart:
           MQL4\\Files\\BTRS_scene_MT4.csv

Verdict rules (strict - the renderer must reproduce the object family):

  * L rows (lines): price, colour, style and width must all match.
  * T rows (labels): text, colour, size and font must match.  The row PRICE is
    informational only: its lift term ((font+6)*(hi-lo)/height) is a function
    of the chart's own height and the two terminals rarely share a pixel
    height; the level PRICE it was computed from is what the L row carries.
  * A name on one side only is a hole and fails the verdict.

By default the two most recently modified dumps under
%APPDATA%\\MetaQuotes\\Terminal\\*\\MQL{4,5}\\Files are picked up; override
with --mt5 / --mt4.

  python tools/parity/scene-diff.py
  python tools/parity/scene-diff.py --mt5 <csv> --mt4 <csv> --tol 1e-7
"""
import argparse
import glob
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def newest(pattern):
    hits = glob.glob(pattern)
    if not hits:
        return None
    return max(hits, key=os.path.getmtime)


def default_mt5():
    base = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal")
    return newest(os.path.join(base, "*", "MQL5", "Files", "BTRS_scene_MT5.csv"))


def default_mt4():
    base = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal")
    return newest(os.path.join(base, "*", "MQL4", "Files", "BTRS_scene_MT4.csv"))


def load(path):
    """-> (lines, texts, problems); each a dict name -> row tuple."""
    lines, texts, problems = {}, {}, []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for ln, raw in enumerate(fh, 1):
            raw = raw.strip()
            if not raw or raw.startswith("type;"):
                continue
            parts = raw.split(";")
            if len(parts) != 9:
                problems.append(f"{path}:{ln}: {len(parts)} fields, want 9: {raw[:80]}")
                continue
            typ, name = parts[0], parts[1]
            if not name:
                problems.append(f"{path}:{ln}: empty name")
                continue
            if typ == "L":
                try:
                    row = (float(parts[2]), parts[3].lower(),
                           int(parts[4]), int(parts[5]))
                except ValueError:
                    problems.append(f"{path}:{ln}: bad L row: {raw[:80]}")
                    continue
                if name in lines:
                    problems.append(f"{path}:{ln}: duplicate line name {name}")
                lines[name] = row
            elif typ == "T":
                try:
                    price = float(parts[2])
                    size = int(parts[6])
                except ValueError:
                    problems.append(f"{path}:{ln}: bad T row: {raw[:80]}")
                    continue
                row = (price, parts[3].lower(), size, parts[7], parts[8])
                if name in texts:
                    problems.append(f"{path}:{ln}: duplicate text name {name}")
                texts[name] = row
            else:
                problems.append(f"{path}:{ln}: unknown type {typ!r}")
    return lines, texts, problems


def diff_family(label, mt5, mt4, fields, tol, failures):
    """fields: list of (field_name, index_in_row, tolerance_or_None)."""
    only5 = sorted(set(mt5) - set(mt4))
    only4 = sorted(set(mt4) - set(mt5))
    mismatched = []
    for name in sorted(set(mt5) & set(mt4)):
        a, b = mt5[name], mt4[name]
        for fname, idx, ftol in fields:
            va, vb = a[idx], b[idx]
            if ftol is not None:
                try:
                    if abs(float(va) - float(vb)) <= ftol:
                        continue
                except (TypeError, ValueError):
                    pass
            if va != vb:
                mismatched.append((name, fname, va, vb))

    print(f"--- {label}: MT5 {len(mt5)} / MT4 {len(mt4)}")
    if only5:
        failures.append(f"{label}: {len(only5)} drawn on MT5, missing on MT4")
        for n in only5[:20]:
            print(f"  MISSING IN MT4 : {n}")
        if len(only5) > 20:
            print(f"  ... and {len(only5) - 20} more")
    if only4:
        failures.append(f"{label}: {len(only4)} exist on MT4, not drawn on MT5")
        for n in only4[:20]:
            print(f"  MISSING IN MT5 : {n}")
        if len(only4) > 20:
            print(f"  ... and {len(only4) - 20} more")
    if mismatched:
        failures.append(f"{label}: {len(mismatched)} field mismatches")
        for name, fname, va, vb in mismatched[:40]:
            print(f"  MISMATCH {name}: {fname} MT5={va} MT4={vb}")
        if len(mismatched) > 40:
            print(f"  ... and {len(mismatched) - 40} more")
    if not (only5 or only4 or mismatched):
        print("  identical")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--mt5", default=None, help="MT5 dump csv (default: newest under terminal folders)")
    ap.add_argument("--mt4", default=None, help="MT4 dump csv (default: newest under terminal folders)")
    ap.add_argument("--tol", type=float, default=1e-7,
                    help="absolute price tolerance for L rows (default 1e-7)")
    args = ap.parse_args()

    mt5_path = args.mt5 or default_mt5()
    mt4_path = args.mt4 or default_mt4()
    if not mt5_path or not os.path.isfile(mt5_path):
        print(f"MT5 dump not found (looked for BTRS_scene_MT5.csv); pass --mt5")
        return 2
    if not mt4_path or not os.path.isfile(mt4_path):
        print(f"MT4 dump not found (looked for BTRS_scene_MT4.csv); pass --mt4")
        return 2
    print(f"MT5: {mt5_path}")
    print(f"MT4: {mt4_path}")

    l5, t5, p5 = load(mt5_path)
    l4, t4, p4 = load(mt4_path)
    for p in p5 + p4:
        print(f"WARN {p}")

    failures = []
    diff_family("LINES", l5, l4,
                [("price", 0, args.tol), ("color", 1, None),
                 ("style", 2, None), ("width", 3, None)],
                args.tol, failures)
    diff_family("LABELS", t5, t4,
                [("text", 3, None), ("color", 1, None),
                 ("size", 2, None), ("font", 4, None)],
                args.tol, failures)

    # informational: label row prices (lift depends on the chart's own height)
    moved = [n for n in sorted(set(t5) & set(t4))
             if t5[n][0] != t4[n][0]]
    if moved:
        print(f"note: {len(moved)} label row prices differ (lift is chart-height "
              f"dependent; not part of the verdict)")

    print()
    if failures:
        print("VERDICT: FAIL")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("VERDICT: PASS - the canvas draws the same family the object path drew")
    return 0


if __name__ == "__main__":
    sys.exit(main())
