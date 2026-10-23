#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""The FOURTH blind spot: a property written through the WRONG accessor.

`ObjectSetInteger(0, name, OBJPROP_PRICE, p)` does not fail on MT5. It returns
false, sets nothing, raises no error and prints nothing - the object simply
never moves. The same is true of `ObjectGetDouble(..., OBJPROP_SELECTED)`
(it answers 0.0 whatever the object is doing) and of `ObjectSetString` on a
numeric property. No line comparison can see this: both trees write the same
line, both compile clean, and the behaviour is the MT5 accessor table.

So the check is a TABLE, not a diff: for every ObjectSet/Get call in the MT5
build, compare the accessor's type with the property's real type, and report
the calls that would silently do nothing.

  python tools/parity/objprop-audit.py
  python tools/parity/objprop-audit.py --only BaseKnotTool.mqh --show

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

# MQL5's property table, split by the accessor that can actually reach it.
# OBJPROP_TIME is NOT here on purpose: an MQL5 time coordinate is a datetime,
# and datetime is read and written through ObjectGet/SetInteger. A table that
# puts it under Double reports 161 "bugs" that are all correct code - which is
# exactly how a gate stops being read.
DOUBLE_PROPS = {
    "OBJPROP_PRICE", "OBJPROP_SCALE", "OBJPROP_ANGLE",
    "OBJPROP_DEVIATION", "OBJPROP_LEVELVALUE",
}
STRING_PROPS = {
    "OBJPROP_TEXT", "OBJPROP_TOOLTIP", "OBJPROP_BMPFILE", "OBJPROP_FONT",
    "OBJPROP_LEVELTEXT", "OBJPROP_SYMBOL",
}
# Everything else OBJPROP_* is integer/long (COLOR, WIDTH, STYLE, SELECTED,
# SELECTABLE, TIMEFRAMES, ZORDER, ANCHOR, FONT SIZE, CORNER, distances, ...).

CALL = re.compile(
    r"\bObject(Set|Get)(Integer|Double|String)\s*\(\s*[^,]+,\s*[^,]+,\s*"
    r"(OBJPROP_[A-Z_]+)")

EXPECT = {
    "Integer": "int", "Double": "double", "String": "string",
}


def kind(prop):
    if prop in DOUBLE_PROPS:
        return "double"
    if prop in STRING_PROPS:
        return "string"
    return "int"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--show", action="store_true")
    a = ap.parse_args()

    bad = 0
    for label, _p4, p5 in MR.modules():
        if a.only and not any(o in label for o in a.only):
            continue
        lines = MR.read(p5)
        hits = []
        for i, ln in enumerate(lines, 1):
            code = ln.split("//")[0]
            for m in CALL.finditer(code):
                op, acc, prop = m.group(1), m.group(2), m.group(3)
                want = kind(prop)
                if want == "int" and acc == "Integer":
                    continue
                if want == acc.lower():
                    continue
                hits.append("  %s:%-5d Object%s%s on %s (needs %s)"
                            % (label, i, op, acc, prop,
                               "Integer" if want == "int" else
                               ("Double" if want == "double" else "String")))
        if hits:
            bad += len(hits)
            print("=" * 78)
            print(label)
            print("=" * 78)
            for h in hits:
                print(h)
        elif a.show:
            print("%-40s accessors agree" % label)

    print()
    print("-" * 78)
    print("calls through the wrong accessor: %d" % bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
