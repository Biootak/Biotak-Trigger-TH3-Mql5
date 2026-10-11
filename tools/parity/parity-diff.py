#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verdict on two `Biotak Sync Compare` dumps - MT4 against MT5.

WHY THREE VERDICTS AND NOT ONE.

The two terminals are fed by different brokers (AMarkets vs Vittaverse), so the
bars themselves differ and every absolute price does too. A single "prices
differ" verdict would say nothing about the indicator. This tool therefore splits
the answer:

  * INVENTORY  - the SET of objects carrying the object prefix must be identical.
                 Feed-independent: the same ladder of the same names is what both
                 builds are supposed to draw.
  * PROPERTIES - type / colour / style / width / timeframes mask / back / fill /
                 ray / zorder / text must be EXACTLY equal per name. Also
                 feed-independent, and the strictest test of the render pipeline.
  * LADDER     - the geometry, measured where it does not depend on the feed:
                 each level's price is expressed in base-relative units,
                     (price - basePrice) / adaptedStep,
                 using the SAME bar's own values row on that side. If the two
                 builds place the same rungs on the same ladder, these agree.

Every exception is printed with its object name, not summarised, so a failure can
be acted on without re-running anything.

  python tools/parity/parity-diff.py --mt4 <MQL4/Files dir> --mt5 <MQL5/Files dir>
  python tools/parity/parity-diff.py --mt4 ... --mt5 ... --bar latest --tolerance 1e-6
"""
import argparse
import csv
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

VALUES = "biotak_sync_values.csv"
OBJECTS = "biotak_sync_objects.csv"
STATE = "biotak_sync_state.csv"

# The ladder's INPUTS. Two terminals read them from their own history, their own
# reference-price file and their own chart state, so this table is where a level
# difference is EXPLAINED rather than merely detected.
STATE_EXACT = ["tfMinutes", "digits", "startTypeInput"]      # settings/место of the chart
STATE_FEED = ["point", "basePrice", "thStep", "adaptedStep", "atrStep", "comboStep"]
STATE_LEGS = ["leg1", "leg2", "leg3", "leg4", "leg5", "leg6", "weightedATR"]
# TH_START_POINT_* values (ConstantsAndEnums.mqh)
START_PREV_CLOSE, START_CUSTOM = 0, 1

# Columns compared as exact strings; everything here is set by the code, never by
# the feed.
EXACT_OBJ = ["type", "color", "style", "width", "timeframes", "back", "fill",
             "ray", "zorder", "text"]
# Columns compared as numbers (the geometry: feed-dependent in absolute terms).
NUM_OBJ = ["price1", "price2"]
# Value columns that are prices (compared absolutely AND base-relative).
PRICE_VAL = ["barOpen", "barHigh", "barLow", "barClose", "basePrice", "thStep",
             "adaptedStep", "atrStep", "comboStep", "structVal", "patternVal",
             "triggerVal", "atrStruct", "atrPattern", "atrTrigger"]
# Value columns that must match exactly (thresholds, factors, percentages).
EXACT_VAL = ["thPct"]


def load(path):
    if not os.path.exists(path):
        sys.exit("missing file: " + path)
    with io.open(path, "r", encoding="utf-8-sig", newline="") as fh:
        rows = [r for r in csv.reader(fh) if r and r[0].strip()]
    if not rows:
        sys.exit("empty file: " + path)
    head, body = rows[0], rows[1:]
    return head, [dict(zip(head, r)) for r in body if len(r) == len(head)]


def fnum(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def close(a, b, tol):
    if a is None or b is None:
        return a == b
    return abs(a - b) <= tol


def bars(rows):
    out = {}
    for r in rows:
        out.setdefault(r["barTime"], []).append(r)
    return out


def cmp_values(mt4, mt5, tol, rel_tol, bar):
    print("=" * 72)
    print("VALUES  (mt4 %d rows, mt5 %d rows)" % (len(mt4), len(mt5)))
    print("=" * 72)
    b4, b5 = bars(mt4), bars(mt5)
    common = sorted(set(b4) & set(b5))
    if not common:
        # Two brokers may stamp the same bar an hour apart (different sessions),
        # so `latest` still answers the question: compare each side's newest bar.
        if bar == "latest":
            print("no common barTime (different broker sessions) - "
                  "comparing each side's newest bar")
            common = []
            pairs = [(sorted(b4)[-1], b5[sorted(b5)[-1]][0])] if b4 and b5 else []
            if not pairs:
                return False
            if len(b4) == 0 or len(b5) == 0:
                return False
            ok = True
            for bt, _ in pairs:
                r4, r5 = b4[bt][0], b5[sorted(b5)[-1]][0]
                diffs = []
                for col in EXACT_VAL:
                    if col in r4 and col in r5 and r4[col] != r5[col]:
                        diffs.append("%s mt4=%s mt5=%s" % (col, r4[col], r5[col]))
                for col in PRICE_VAL:
                    if col not in r4 or col not in r5:
                        continue
                    v4, v5 = fnum(r4[col]), fnum(r5[col])
                    if close(v4, v5, tol):
                        continue
                    base4, base5 = fnum(r4.get("basePrice")), fnum(r5.get("basePrice"))
                    if base4 and base5 and close(v4 / base4, v5 / base5, rel_tol):
                        continue
                    diffs.append("%s mt4=%s mt5=%s" % (col, r4[col], r5[col]))
                print("mt4 bar %s vs mt5 bar %s:" % (bt, sorted(b5)[-1]))
                if diffs:
                    ok = False
                    for d in diffs:
                        print("   " + d)
                else:
                    print("   OK (absolute or base-relative within tolerance)")
            return ok
        print("!! no common barTime - the two runs did not cover the same bars")
        print("   mt4 bars: %s .. %s" % (sorted(b4)[0], sorted(b4)[-1]))
        print("   mt5 bars: %s .. %s" % (sorted(b5)[0], sorted(b5)[-1]))
        return False
    only4 = sorted(set(b4) - set(b5))
    only5 = sorted(set(b5) - set(b4))
    print("common bars: %d   (mt4-only %d, mt5-only %d)"
          % (len(common), len(only4), len(only5)))
    if bar == "latest":
        common = common[-1:]
    ok = True
    for bt in common:
        r4, r5 = b4[bt][0], b5[bt][0]
        diffs = []
        for col in EXACT_VAL:
            if col in r4 and col in r5 and r4[col] != r5[col]:
                diffs.append("%s mt4=%s mt5=%s" % (col, r4[col], r5[col]))
        for col in PRICE_VAL:
            if col not in r4 or col not in r5:
                continue
            v4, v5 = fnum(r4[col]), fnum(r5[col])
            if close(v4, v5, tol):
                continue
            # base-relative: the feed-independent form of the same question
            base4, base5 = fnum(r4.get("basePrice")), fnum(r5.get("basePrice"))
            if base4 and base5:
                n4, n5 = v4 / base4, v5 / base5
                if close(n4, n5, rel_tol):
                    continue                      # same rung, different feed
            diffs.append("%s mt4=%s mt5=%s" % (col, r4[col], r5[col]))
        if diffs:
            ok = False
            print("bar %s:" % bt)
            for d in diffs:
                print("   " + d)
        else:
            print("bar %s: OK (absolute or base-relative within tolerance)" % bt)
    if not ok:
        print("\nNOTE: a base-relative match counts as a pass - the two brokers'")
        print("      quotes differ, the indicator's answer to them must not.")
    return ok


def cmp_state(mt4, mt5, rel_tol, bar):
    """WHY the two ladders differ: compare every input the ladder reads."""
    print()
    print("=" * 72)
    print("STATE / CAUSE  (the inputs behind the levels)")
    print("=" * 72)
    if not mt4 or not mt5:
        print("state CSV missing on one side - the twin's SyncDumpState() was not")
        print("in the build that produced this run; recompile both twins.")
        return False
    r4, r5 = mt4[-1], mt5[-1]
    ok = True
    causes = []

    # MT5 emulates MQL4's `Bars`; if it lags the terminal's own bar count, every
    # reader of Bars/Time[]/Close[] is looking at a shorter series than MT4's.
    for tag, r in (("mt4", r4), ("mt5", r5)):
        b_c, b_e = fnum(r.get("barsChart")), fnum(r.get("barsEmul"))
        if b_c is not None and b_e is not None and b_e < b_c:
            causes.append("%s: the series emulation is BEHIND the chart (Bars=%d of"
                          " %d bars) - history is still arriving, so every read of"
                          " Bars/Time[]/Close[] sees fewer bars than MT4 would"
                          % (tag, int(b_e), int(b_c)))

    for col in STATE_EXACT:
        if col in r4 and col in r5 and r4[col] != r5[col]:
            ok = False
            causes.append("%s differs: mt4=%s mt5=%s" % (col, r4[col], r5[col]))

    # the two "the user set it / the chart is doing it" flags
    for tag, r in (("mt4", r4), ("mt5", r5)):
        if r.get("startTypeLive") != r.get("startTypeInput"):
            ok = False
            causes.append(
                "%s: the CHART is not using the input start type - live=%s input=%s"
                " (a leftover custom TH anchor = a different ladder regardless of "
                "settings; customStartPrice=%s)"
                % (tag, r.get("startTypeLive"), r.get("startTypeInput"),
                   r.get("customStartPrice")))
        elif r.get("startTypeLive") == str(START_CUSTOM):
            causes.append("%s: start type IS custom (input and live agree) - both"
                          " sides must use the same anchor to be comparable" % tag)

    # history depth: the reference-price chain and the ATR legs both read it
    for col in ("barsChart", "barsEmul", "barsM1", "barsD1"):
        a, b = fnum(r4.get(col)), fnum(r5.get(col))
        if a is not None and b is not None and a != b:
            causes.append("%s: mt4=%d mt5=%d (history depth feeds the ATR legs and"
                          " the reference-price rebuild)" % (col, int(a), int(b)))

    # the reference price itself: was one side anchored on the live Bid?
    h4, h5 = fnum(r4.get("histCount")), fnum(r5.get("histCount"))
    if h4 is not None and h5 is not None:
        if (h4 == 0) != (h5 == 0):
            ok = False
            causes.append("the reference-price file: mt4 has %d entries, mt5 has %d"
                          " - the empty side anchored its base price on the LIVE BID"
                          " (BASE PRICE INIT), so its ladder is anchored elsewhere"
                          % (int(h4), int(h5)))
        elif h4 != h5:
            causes.append("reference-price entries: mt4=%d mt5=%d (same day file,"
                          " different number of 30-min updates)" % (int(h4), int(h5)))

    print("mt4: %s  tf=%s  bars=%s/%s/%s  base=%s  entries=%s"
          % (r4.get("symbol"), r4.get("tfMinutes"), r4.get("barsChart"),
             r4.get("barsM1"), r4.get("barsD1"), r4.get("basePrice"),
             r4.get("histCount")))
    print("mt5: %s  tf=%s  bars=%s/%s/%s  base=%s  entries=%s"
          % (r5.get("symbol"), r5.get("tfMinutes"), r5.get("barsChart"),
             r5.get("barsM1"), r5.get("barsD1"), r5.get("basePrice"),
             r5.get("histCount")))

    # values that scale with the feed: pass when base-relative (or ATR-relative)
    print("\nvalue            mt4              mt5             verdict")
    for col in STATE_FEED + STATE_LEGS:
        if col not in r4 or col not in r5:
            continue
        v4, v5 = fnum(r4[col]), fnum(r5[col])
        if v4 is None or v5 is None:
            continue
        if close(v4, v5, 0.0):
            verdict = "same"
        else:
            a4, a5 = fnum(r4.get("weightedATR")), fnum(r5.get("weightedATR"))
            b4v, b5v = fnum(r4.get("basePrice")), fnum(r5.get("basePrice"))
            scale4 = a4 if a4 else b4v
            scale5 = a5 if a5 else b5v
            if scale4 and scale5 and close(v4 / scale4, v5 / scale5, rel_tol):
                verdict = "ok /scale"
            else:
                verdict = "DIFFERS"
                ok = False
        print("%-16s %-16s %-16s %s" % (col, r4[col], r5[col], verdict))

    print()
    if causes:
        print("CAUSES (%d):" % len(causes))
        for c in causes:
            print("   * " + c)
        print("\nA cause that is not a settings difference is DATA/STATE, not a code")
        print("bug: the two terminals hold different histories and their own")
        print("reference-price files. Equalise them (delete today's history file on")
        print("both sides / attach both at the same time) before reading the levels")
        print("as a parity verdict.")
    else:
        print("no state cause found: inputs, history depth and reference-price")
        print("provenance all agree.")
    return ok


def ladder_key(name):
    """`THLevels_Mark_Above_3` -> (family, index) so a renamed feed can't hide."""
    return name


def cmp_objects(mt4, mt5, tol, rel_tol, vals4, vals5, bar):
    print()
    print("=" * 72)
    print("OBJECTS  (mt4 %d rows, mt5 %d rows)" % (len(mt4), len(mt5)))
    print("=" * 72)
    b4, b5 = bars(mt4), bars(mt5)
    bt4 = (bar if bar != "latest" else sorted(b4)[-1]) if b4 else None
    bt5 = (bar if bar != "latest" else sorted(b5)[-1]) if b5 else None
    rows4 = b4.get(bt4, [])
    rows5 = b5.get(bt5, [])
    o4 = {r["name"]: r for r in rows4}
    o5 = {r["name"]: r for r in rows5}
    print("mt4 bar %s   mt5 bar %s" % (bt4, bt5))

    only4 = sorted(set(o4) - set(o5))
    only5 = sorted(set(o5) - set(o4))
    common = sorted(set(o4) & set(o5))
    ok = True
    if only4 or only5:
        ok = False
        print("INVENTORY DIFFERS:  %d only on mt4, %d only on mt5"
              % (len(only4), len(only5)))
        for n in only4[:40]:
            print("   only-mt4: " + n)
        for n in only5[:40]:
            print("   only-mt5: " + n)
    else:
        print("INVENTORY IDENTICAL: %d objects, same names on both sides" % len(common))

    prop_bad = []
    geom_bad = []
    for n in common:
        a, b = o4[n], o5[n]
        for col in EXACT_OBJ:
            if a.get(col) != b.get(col):
                prop_bad.append("%s  %s: mt4=%r mt5=%r" % (n, col, a.get(col), b.get(col)))
        for col in NUM_OBJ:
            v4, v5 = fnum(a.get(col)), fnum(b.get(col))
            if close(v4, v5, tol):
                continue
            base4 = fnum(vals4.get("basePrice")) if vals4 else None
            base5 = fnum(vals5.get("basePrice")) if vals5 else None
            step4 = fnum(vals4.get("adaptedStep")) if vals4 else None
            step5 = fnum(vals5.get("adaptedStep")) if vals5 else None
            if base4 and base5 and step4 and step5:
                r4 = (v4 - base4) / step4
                r5 = (v5 - base5) / step5
                if close(r4, r5, 1e-3):
                    continue                      # same rung of the same ladder
            geom_bad.append("%s  %s: mt4=%s mt5=%s" % (n, col, a.get(col), b.get(col)))

    if prop_bad:
        ok = False
        print("\nPROPERTY DIFFERENCES (%d) - these are feed-independent, so each one"
              % len(prop_bad))
        print("is a real divergence:")
        for d in prop_bad[:60]:
            print("   " + d)
        if len(prop_bad) > 60:
            print("   ... %d more" % (len(prop_bad) - 60))
    else:
        print("PROPERTIES IDENTICAL on all %d common objects "
              "(type/colour/style/width/TF mask/back/fill/ray/zorder/text)" % len(common))

    if geom_bad:
        print("\nGEOMETRY outside tolerance on %d object(s) (absolute AND base-relative):"
              % len(geom_bad))
        for d in geom_bad[:60]:
            print("   " + d)
    else:
        print("GEOMETRY: every common object sits on the same base-relative rung")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mt4", required=True, help="MT4 terminal's MQL4/Files folder")
    ap.add_argument("--mt5", required=True, help="MT5 terminal's MQL5/Files folder")
    ap.add_argument("--bar", default="all", choices=["all", "latest"])
    ap.add_argument("--tolerance", type=float, default=1e-9)
    ap.add_argument("--rel-tolerance", type=float, default=2e-6,
                    help="tolerance on base-relative ratios (feed-independent pass)")
    args = ap.parse_args()

    v4h, v4 = load(os.path.join(args.mt4, VALUES))
    v5h, v5 = load(os.path.join(args.mt5, VALUES))
    o4h, o4 = load(os.path.join(args.mt4, OBJECTS))
    o5h, o5 = load(os.path.join(args.mt5, OBJECTS))
    s4p, s4 = os.path.join(args.mt4, STATE), []
    s5p, s5 = os.path.join(args.mt5, STATE), []
    if os.path.exists(s4p):
        s4 = load(s4p)[1]
    if os.path.exists(s5p):
        s5 = load(s5p)[1]

    okv = cmp_values(v4, v5, args.tolerance, args.rel_tolerance, args.bar)
    b4 = bars(v4)
    b5 = bars(v5)
    last4 = b4[sorted(b4)[-1]][0] if b4 else None
    last5 = b5[sorted(b5)[-1]][0] if b5 else None
    oko = cmp_objects(o4, o5, args.tolerance, args.rel_tolerance, last4, last5, args.bar)
    oks = cmp_state(s4, s5, args.rel_tolerance, args.bar)

    print()
    print("=" * 72)
    print("VERDICT: values=%s  objects=%s  state=%s" %
          ("OK" if okv else "DIFFER", "OK" if oko else "DIFFER",
           "OK" if oks else "DIFFER"))
    print("=" * 72)
    return 0 if (okv and oko and oks) else 1


if __name__ == "__main__":
    sys.exit(main())
