#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Regenerate an MT5 module as the exact MT4 source (parts inlined) + patches.

POLICY (user, 2026-10-03)

    "exactly like MT4 - nothing less, nothing more; remove MT5's extras too"

MT4 is the single source of truth.  For a module that exists in both trees this
tool writes the MT5 file as:

    MT4 shell
      + every MT4 part file it includes, inlined (MT4-only files)
      + the include lines that point at modules both trees own (kept, path
        recomputed so it resolves from the generated file's location)
      + PATCHES: the minimum set of MQL5 platform adaptations, each with a
        reason.  They change no arithmetic.

Nothing MT5-only survives: no ribbon, no ChartTools palette, no CardCover, no
third view-lock, no TH mode 3, no grouping, no price-note kind, no diag hooks.

  python tools/parity/resync-module.py --list                 # RED modules
  python tools/parity/resync-module.py BiotakMenu.mqh         # dry: show summary
  python tools/parity/resync-module.py --write BiotakMenu.mqh # write it
  python tools/parity/resync-module.py --write --all
  python tools/parity/resync-module.py --verify BiotakMenu.mqh
"""
import argparse
import collections
import io
import importlib.util
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
MT5_REPO = os.path.dirname(os.path.dirname(HERE))
MT4_REPO = os.path.join(os.path.dirname(MT5_REPO), "Biotak-Trigger-TH3-mql4")
MT4_BIOTAK = os.path.join(MT4_REPO, "Biotak")
MT5_BIOTAK = os.path.join(MT5_REPO, "Biotak")

INC = re.compile(r'^(\s*)#include\s+[<"]([^>"]+)[>"]\s*(?://.*)?$')

# ---------------------------------------------------------------------------
# Platform patches: MQL5 API adaptation only.  Keep this list SHORT and put a
# reason on every entry; anything else means the compile must prove it.
# ---------------------------------------------------------------------------
PATCHES = [
    (re.compile(r'ObjectCreate\(\s*0\s*,\s*(\w+)\s*,\s*type\s*,'),
     r'ObjectCreate(0, \1, (ENUM_OBJECT)type,',
     "MQL5 ObjectCreate needs an explicit ENUM_OBJECT cast"),
    (re.compile(r'CopyTime\(Symbol\(\)\s*,\s*\(ENUM_TIMEFRAMES\)\s*(\w+)\s*,'),
     r'CopyTime(Symbol(), CompatTF(\1),',
     "MQL5 CopyTime takes ENUM_TIMEFRAMES; MT4 passed a raw timeframe number"),
    (re.compile(r'(?<![\w.])Bars\s*\('),
     r'iBars(',
     "MQL4 Bars(symbol,timeframe) is MQL5 iBars(...) - same call, same result"),
]

HEADER = """// ============================================================================
// GENERATED MIRROR of the MetaTrader 4 source - MT4 is the single source of
// truth.  Do not add anything here that MT4 does not have: with MT4 there is
// "nothing less, nothing more".
//
//   MT4 source : Biotak/{rel34}
//   regenerate : python tools/parity/resync-module.py --write {name}
//
// The MT4 part files are inlined (MT5 has no such parts), includes of modules
// both trees own are kept, and only these platform patches are applied:
{patches}
// ============================================================================
"""


# ---------------------------------------------------------------------------
# ENTRY (the .mq5 shells): same law - MT4's text + declared platform blocks.
# ---------------------------------------------------------------------------
PLOT_PROPERTY = '''
// MT5-ONLY PLATFORM PROPERTY: MQL5 warns when an indicator declares no plot;
// MQL4 never needed to say it. The indicator draws objects, not buffers.
#property indicator_plots 0
'''

PLATFORM_INCLUDE = '''
// MT5-ONLY PLATFORM LAYER - MQL4 API shims (Symbol/Digits/Point/Bid/Ask,
// MarketInfo, value iATR, the Time[]..Close[]/Bars series emulation, the MQL4
// object-call forms and ObjectSetText). It must precede every shared module.
// It adds NO feature: it is what lets the MT4 source compile and behave as MT4.
#include "MT5Compat\\MQL5Compat.mqh"
'''

PLATFORM_INIT = '''
    // MT5-ONLY PLATFORM CALL, AND IT MUST BE THE FIRST STATEMENT.
    // MQL4 fills the predefined series arrays (Bars, Time[]..Close[]) before
    // OnInit is entered; MQL5 has no such arrays, so MT5Compat emulates them and
    // something has to fill them. The shared modules read those values during
    // init (ZoneFactory's safeBars, ExtendedDrawingFunctions' startTime,
    // BaseKnotTool's span, ATRCalculations' effective bars), so refreshing here
    // is what makes the first paint match MT4 exactly.
    CompatRefreshChartData();
'''

PLATFORM_CALC = '''
    // MT5-ONLY PLATFORM CALLS - MQL4 always hands these arrays over as
    // timeseries (index 0 = current bar) and there is no first-bar race; MQL5
    // makes no such promise, so the direction is forced and the emulated series
    // arrays are refilled before the shared handler reads them.
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(tick_volume, true);
    ArraySetAsSeries(real_volume, true);
    ArraySetAsSeries(spread, true);
    CompatRefreshChartData();
'''

PLATFORM_TIMER = '''
    // MT5-ONLY PLATFORM CALL - keep the emulated MQL4 series arrays live on a
    // chart that is not ticking (MQL4's arrays always were).
    CompatRefreshChartData();
'''

# (anchor regex, text inserted AFTER the anchor, reason).  The insertion is
# applied with a callback so backslashes in the text stay literal.
ENTRY_INSERTS = [
    (re.compile(r'^#property indicator_chart_window[ \t]*$', re.M),
     PLOT_PROPERTY, "MQL5: declare an object-only indicator"),
    (re.compile(r'^#include "Biotak\\Logger\.mqh"[ \t]*$', re.M),
     PLATFORM_INCLUDE, "MT5Compat platform layer include"),
    (re.compile(r'^int OnInit\(\)\s*\n\{\s*\n', re.M),
     PLATFORM_INIT, "OnInit: fill the MQL4 series emulation"),
    (re.compile(r'^int OnCalculate\([^)]*\n(?:[^\n]*\n)*?\{\s*\n', re.M),
     PLATFORM_CALC, "OnCalculate: timeseries direction + emulation"),
    (re.compile(r'^void OnTimer\(\)\s*\n\{\s*\n', re.M),
     PLATFORM_TIMER, "OnTimer: keep the emulation live"),
]

ENTRY_PAIRS = [
    ("Biotak Trigger TH3.mq4", "Biotak Trigger TH3.mq5"),
    ("Biotak Trigger TH3 Lite.mq4", "Biotak Trigger TH3 Lite.mq5"),
]


def generate_entry(mr, mt4_name, mt5_name, write=False):
    p4 = os.path.join(mr.MT4_REPO, mt4_name)
    p5 = os.path.join(mr.MT5_REPO, mt5_name)
    text, _, _ = read_text(p4)
    text = text.replace("\r\n", "\n")
    applied = []
    for pat, ins, why in ENTRY_INSERTS:
        text, n = pat.subn(lambda mm, ins=ins: mm.group(0) + ins, text, count=1)
        applied.append((why, n))
    header = ("// ========================================================================\n"
              "// GENERATED MIRROR of " + mt4_name + " - MT4 is the source of truth.\n"
              "// regenerate: python tools/parity/resync-module.py --entry\n"
              "// Only the declared MT5 platform blocks below are added (MQL4 series\n"
              "// arrays + MQL5 timeseries direction); nothing else is MT5-specific.\n"
              "// ========================================================================\n")
    result = header + text
    if write:
        old, bom, crlf = read_text(p5)
        data = (result + "\n").replace("\n", "\r\n" if crlf else "\n").encode("utf-8")
        if bom:
            data = b"\xef\xbb\xbf" + data
        with io.open(p5, "wb") as fh:
            fh.write(data)
    return dict(name=mt5_name, applied=applied, bytes=len(result))


def load_report():
    spec = importlib.util.spec_from_file_location(
        "mr", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "module-report.py"))
    mr = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mr)
    return mr


def read_text(path):
    with io.open(path, "rb") as fh:
        raw = fh.read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    crlf = text.count("\r\n") >= max(1, text.count("\n") // 2)
    return text, bom, crlf


def rel_to_mt5(inc_path, from_file):
    """Resolve an MT4 include target, return the MT5 counterpart path or None."""
    tgt = inc_path.replace("\\", "/")
    cand = os.path.normpath(os.path.join(os.path.dirname(from_file), tgt))
    if not os.path.exists(cand):
        top = os.path.normpath(os.path.join(MT4_REPO, tgt.lstrip("/")))
        if os.path.exists(top):
            cand = top
    if not os.path.exists(cand):
        return None
    rel = os.path.relpath(cand, MT4_REPO)
    counter = os.path.normpath(os.path.join(MT5_REPO, rel))
    return counter if os.path.isfile(counter) else None


def flatten(src, out_lines, seen, out_dir, inlined):
    """Inline MT4-only parts; keep includes of dual modules (path rewritten)."""
    key = os.path.normcase(src)
    if key in seen:
        return
    seen.add(key)
    text, _, _ = read_text(src)
    for raw in text.splitlines():
        m = INC.match(raw)
        if not m:
            out_lines.append(raw.rstrip("\r\n"))
            continue
        inc = m.group(2)
        tail = raw.split(">")[-1].split('"')[-1] if (">" in raw or '"' in raw) else ""
        counter = rel_to_mt5(inc, src)
        if counter:
            rel = os.path.relpath(counter, out_dir).replace("\\", "/")
            out_lines.append("%s#include \"%s\"%s" % (m.group(1), rel, tail))
        else:
            cand = os.path.normpath(os.path.join(
                os.path.dirname(src), inc.replace("\\", "/")))
            if not os.path.exists(cand):
                cand = os.path.normpath(os.path.join(MT4_REPO, inc.lstrip("/")))
            if os.path.exists(cand):
                inlined.append(os.path.relpath(cand, MT4_REPO).replace("\\", "/"))
                flatten(cand, out_lines, seen, out_dir, inlined)
            else:
                out_lines.append(raw.rstrip("\r\n"))   # e.g. <Trade\Trade.mqh>


def generate(mr, label, p4, p5, write=False):
    name = os.path.basename(p4)
    out_dir = os.path.dirname(p5)
    out, inlined = [], []
    flatten(p4, out, set(), out_dir, inlined)
    text = "\n".join(out)

    applied = []
    for pat, repl, why in PATCHES:
        text, n = pat.subn(repl, text)
        if n:
            applied.append((why, n))
    plist = "\n".join("//   * %s  (%d substitution%s)"
                      % (why, n, "" if n == 1 else "s") for why, n in applied) \
        or "//   * none"
    rel34 = os.path.relpath(p4, MT4_REPO).replace("\\", "/")
    header = HEADER.format(rel34=rel34, name=name, patches=plist)
    result = header + text

    # real churn: what changes in the MT5 file on disk (code lines only)
    old_text, _, _ = read_text(p5)
    c1 = collections.Counter(l for l in mr.norm_body(old_text) if not mr.is_arch(l))
    c2 = collections.Counter(l for l in mr.norm_body(result) if not mr.is_arch(l))
    extra = list((c2 - c1).elements())      # lines the rewrite ADDS
    missing = list((c1 - c2).elements())    # lines the rewrite REMOVES

    if write:
        old_text, bom, crlf = read_text(p5)
        new = result + "\n"
        if crlf:
            new = new.replace("\n", "\r\n")
        data = new.encode("utf-8")
        if bom:
            data = b"\xef\xbb\xbf" + data
        with io.open(p5, "wb") as fh:
            fh.write(data)

    return dict(name=name, inlined=inlined, patched=applied,
                extra=extra, missing=missing, bytes=len(result))


def red_modules(mr):
    out = []
    for label, p4, p5 in mr.modules():
        if label.startswith("ENTRY"):
            continue
        r = mr.compare_module(p4, p5)
        if (r["bad4"] or r["bad5"] or r["sym4_only"]
                or r["inc4_only"] or r["inc5_only"]):
            out.append((label, p4, p5))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", help="module file names, e.g. BiotakMenu.mqh")
    ap.add_argument("--all", action="store_true", help="every RED module")
    ap.add_argument("--list", action="store_true", help="list RED modules and stop")
    ap.add_argument("--entry", action="store_true",
                    help="regenerate the .mq5 shells from the MT4 entries")
    ap.add_argument("--refresh", action="store_true",
                    help="re-apply the platform patches to EVERY dual module")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    mr = load_report()
    red = red_modules(mr)

    if args.entry:
        for m4, m5 in ENTRY_PAIRS:
            info = generate_entry(mr, m4, m5, write=args.write)
            print("%-32s <- %-28s %s" % (m5, m4,
                                         "[WRITTEN]" if args.write else "(dry)"))
            for why, n in info["applied"]:
                print("      %s  x%d%s" % (why, n, "" if n else "  !! ANCHOR MISSED"))
        return 0

    if args.refresh:
        # patches changed: every module must be re-emitted, then we report which
        # ones actually changed on disk (this is how a new platform patch reaches
        # modules that were already in sync).
        changed = written = 0
        for label, p4, p5 in mr.modules():
            if label.startswith("ENTRY") or not os.path.isfile(p4):
                continue
            before, _, _ = read_text(p5)
            info = generate(mr, label, p4, p5, write=args.write)
            after, _, _ = read_text(p5)
            if after != before:
                changed += 1
                print("  %-40s %s" % (label, "[REWRITTEN]" if args.write else "(would change)"))
                for why, n in info["patched"]:
                    print("        patch: %s x%d" % (why, n))
        print("%d of %d modules changed%s"
              % (changed, len(mr.modules()) - 2,
                 "" if args.write else "  (dry run: add --write)"))
        return 0

    if args.list or (not args.names and not args.all):
        print("RED modules (need to become exactly MT4):")
        for label, p4, p5 in red:
            print("   %-40s %s" % (label, os.path.basename(p5)))
        print("\nENTRY (.mq5 shells) is generated by --entry.")
        return 0

    todo = []
    for label, p4, p5 in red:
        if args.all or os.path.basename(p5) in args.names or label in args.names:
            todo.append((label, p4, p5))
    if not args.all:
        missing = [n for n in args.names
                   if not any(os.path.basename(p5) == n for _, _, p5 in todo)]
        if missing:
            print("!! not a RED module (or unknown): %s" % ", ".join(missing))

    for label, p4, p5 in todo:
        info = generate(mr, label, p4, p5, write=args.write)
        print("%-40s parts-inlined=%2d patches=%d  adds=%4d removes=%4d%s"
              % (label, len(info["inlined"]), len(info["patched"]),
                 len(info["extra"]), len(info["missing"]),
                 "   [WRITTEN]" if args.write else ""))
        for why, n in info["patched"]:
            print("      patch: %s (%d)" % (why, n))
        for ln in info["extra"][:8]:
            print("      + %s" % ln[:104])
        for ln in info["missing"][:8]:
            print("      - %s" % ln[:104])

    if args.verify and not args.write:
        print("\n(--verify implies checking the file on disk: run with --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
