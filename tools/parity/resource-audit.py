#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit the THIRD blind spot: the preprocessor lines nobody compares.

module-report.py compares the multiset of CODE lines and drops every line that
starts with '#', because include guards and #include architecture legitimately
differ between the two trees. `#resource` rides along in that exclusion, and it
is not architecture: it is what EMBEDS a raster into the .ex5.

    `OBJPROP_BMPFILE` with a "::Files\\Icons\\x.bmp" path resolves ONLY for a
    file the compiling unit `#resource`d. The .bmp existing in Files/Icons is
    not enough - it is embedded, not loaded from disk.

MEASURED 2026-10-23: MT4's DrawStrip_Head.mqh carries `#resource` for
bk_anchor_on/off.bmp; the MT5 module carries neither, only the runtime path, so
the LAST OBJECT cell in the strip painted no art while every check read GREEN -
the compiler had the file on disk and the line comparison had thrown the
directive away.

WHAT IT REPORTS
    Per module: resources MT4 embeds and MT5 does not (a blank cell), resources
    MT5 embeds and MT4 does not (an extra to justify), and any embedded file
    that is missing from Files/Icons (a build that would fail, or worse, one
    that silently paints nothing).

  python tools/parity/resource-audit.py
  python tools/parity/resource-audit.py --only DrawStrip.mqh
  python tools/parity/resource-audit.py --quiet

Read-only. Never writes.
"""
import argparse
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "module_report", os.path.join(HERE, "module-report.py"))
MR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MR)

RE_RES = re.compile(r'^\s*#resource\s+"([^"]+)"', re.I)


def resources(lines):
    out = set()
    for ln in lines:
        m = RE_RES.match(ln)
        if m:
            out.add(m.group(1).replace("\\\\", "\\").replace("/", "\\"))
    return out


def basename(res):
    return res.split("\\")[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    icon_dir = os.path.join(MR.MT5_REPO, "Files", "Icons")
    have_on_disk = {n for n in os.listdir(icon_dir)} if os.path.isdir(icon_dir) else set()

    missing_total = extra_total = broken_total = 0
    for label, p4, p5 in MR.modules():
        if a.only and not any(o in label for o in a.only):
            continue
        r4 = resources(MR.build_ref(p4))
        r5 = resources(MR.read(p5))
        missing = sorted(r4 - r5)
        extra = sorted(r5 - r4)
        broken = sorted(x for x in r5 if basename(x) not in have_on_disk)
        if not missing and not extra and not broken:
            if not a.quiet:
                print("%-40s %3d resources, identical" % (label, len(r4)))
            continue
        missing_total += len(missing)
        extra_total += len(extra)
        broken_total += len(broken)
        print("%-40s mt4=%3d mt5=%3d  MISSING=%d  extra=%d  absent=%d"
              % (label, len(r4), len(r5), len(missing), len(extra), len(broken)))
        for x in missing:
            print("    MT4 embeds, MT5 does not: %s" % x)
        for x in extra:
            print("    MT5 embeds, MT4 does not: %s" % x)
        for x in broken:
            print("    MT5 embeds a file that is NOT in Files/Icons: %s" % x)

    print()
    print("-" * 78)
    print("resources missing from MT5: %d   extra: %d   embedded-but-absent: %d"
          % (missing_total, extra_total, broken_total))
    return 0 if not (missing_total or broken_total) else 1


if __name__ == "__main__":
    sys.exit(main())
