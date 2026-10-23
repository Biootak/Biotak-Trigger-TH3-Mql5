#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit the OTHER blind spot: the declared MODULE_PATCHES (one-sided blocks).

module-report.py proves the trees are the same code by comparing line multisets.
A declared patch is a block that legally exists on ONE side only (an MQL5 API
adaptation, a perf rewrite, an engine hook). The checker therefore never asks
what the replacement DOES - and a patch that quietly drops a call is exactly
how the LAST OBJECT bridge went missing in this fork.

WHAT IT REPORTS
    For every patch: the call set of the MT4 text the patch REPLACES vs the call
    set of the MT5 text it PUTS THERE. A call only MT4 makes is a behaviour the
    patch dropped; a call only MT5 makes is behaviour the patch added. Both are
    review items, not verdicts: an added `RBridge*` is the sanctioned mask, and a
    dropped `ObjectDelete` may be a documented `ObjectsDeleteAll` sweep.

  python tools/parity/patch-audit.py                    # every patch
  python tools/parity/patch-audit.py --only LevelPipeline.mqh
  python tools/parity/patch-audit.py --gaps             # only the flagged ones
  python tools/parity/patch-audit.py --calls            # print full call sets

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

RE_CALL = re.compile(r"(?<![\w.])([A-Za-z_]\w*)\s*\(")
KEYWORDS = {
    'if', 'for', 'while', 'switch', 'return', 'sizeof', 'else', 'do', 'case',
    'catch', 'new', 'delete', 'static_cast', 'dynamic_cast', 'const_cast',
    'reinterpret_cast',
}
RE_COMMENT_LINE = re.compile(r"//.*$")
RE_COMMENT_BLOCK = re.compile(r"/\*.*?\*/", re.S)


def calls(text):
    text = RE_COMMENT_BLOCK.sub("", text)
    text = "\n".join(RE_COMMENT_LINE.sub("", ln) for ln in text.splitlines())
    return {m.group(1) for m in RE_CALL.finditer(text)
            if m.group(1) not in KEYWORDS}


def load_patches():
    spec = importlib.util.spec_from_file_location(
        "rm", os.path.join(HERE, "_retired", "resync-module.py"))
    rm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rm)
    return rm.MODULE_PATCHES


def mt4_text(module, pat):
    """The MT4 text one patch replaces.

    The generator inlined split parts, so a pattern can match text that lives in
    no single MT4 file: the module's reference build is tried first, then every
    .mqh in the tree (the same rule module-report uses for consumed lines).
    """
    ref = os.path.join(MR.MT4_BIOTAK, module)
    pools = []
    if os.path.exists(ref):
        pools.append("\n".join(MR.build_ref(ref)))
    for base, _dirs, files in os.walk(MR.MT4_REPO):
        for fn in files:
            if fn.endswith(".mqh") or fn.endswith(".mq4"):
                p = os.path.join(base, fn)
                if p == ref:
                    continue
                try:
                    pools.append("\n".join(MR.read(p)))
                except Exception:
                    pass
    for text in pools:
        m = pat.search(text)
        if m:
            return m.group(0)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--gaps", action="store_true")
    ap.add_argument("--calls", action="store_true")
    a = ap.parse_args()

    patches = load_patches()
    total = flagged = unmatched = 0
    for module in sorted(patches):
        if a.only and not any(o in module for o in a.only):
            continue
        print("=" * 78)
        print("%s   (%d declared patches)" % (module, len(patches[module])))
        print("=" * 78)
        for i, (pat, repl, why) in enumerate(patches[module], 1):
            total += 1
            before = mt4_text(module, pat)
            if before is None:
                unmatched += 1
                print("  [%02d] pattern matches no MT4 text - %s" % (i, why))
                continue
            c4, c5 = calls(before), calls(repl)
            only4, only5 = sorted(c4 - c5), sorted(c5 - c4)
            if not only4 and not only5:
                if a.calls:
                    print("  [%02d] same call set - %s" % (i, why))
                continue
            flagged += 1
            if a.gaps or True:
                print("  [%02d] %s" % (i, why))
                if only4:
                    print("       MT4 had, the patch dropped: %s" % ", ".join(only4[:16]))
                if only5:
                    print("       the patch added: %s" % ", ".join(only5[:16]))
                if a.calls:
                    print("       mt4: %s" % ", ".join(sorted(c4)))
                    print("       mt5: %s" % ", ".join(sorted(c5)))
        print()

    print("-" * 78)
    print("declared patches: %d   with a call-set change: %d   unmatched: %d"
          % (total, flagged, unmatched))
    return 0


if __name__ == "__main__":
    sys.exit(main())
