#!/usr/bin/env python3
# TH3 movement-step math on real EURUSD numbers.
# Mirrors Biotak/TH3/TH3Math.mqh: GetCachedDailyATR, TH3SkeletonFromBars,
# TH3MomentumSpeed/TH3MomentumFromSpeed and TH3StepFromSkeleton.
# Pure stdlib. Outputs in PIPS (EURUSD pip = 0.0001) unless noted.
import json, datetime, os, math

HERE = os.path.dirname(os.path.abspath(__file__))
PIP = 0.0001

def load(fn):
    d = json.load(open(os.path.join(HERE, fn)))
    r = d['chart']['result'][0]
    ts = r['timestamp']
    q = r['indicators']['quote'][0]
    bars = []
    for i in range(len(ts)):
        o, h, l, c = q['open'][i], q['high'][i], q['low'][i], q['close'][i]
        if None in (o, h, l, c):
            continue
        bars.append((datetime.datetime.fromtimestamp(ts[i], datetime.UTC), float(o), float(h), float(l), float(c)))
    bars.reverse()          # index 0 = newest bar (MQL shift semantics)
    return bars

def tr_at(bars, j):
    _, _, h, l, c = bars[j]
    pc = bars[j + 1][4] if j + 1 < len(bars) else c
    return max(h - l, abs(h - pc), abs(l - pc))

def wilder_atr(bars, period, shift):
    # MQL iATR(period, shift): RMA over TR, seeded with SMA(TR, period).
    if shift + period >= len(bars):
        return 0.0
    trs = [tr_at(bars, j) for j in range(shift, shift + period)]
    atr = sum(trs) / period
    for k in range(period - 2, -1, -1):
        atr = (atr * (period - 1) + trs[k]) / period
    return atr

def p(x):
    return x / PIP

def f1(x):
    return round(x, 1)

D1 = load('eurusd_d1.json'); H1 = load('eurusd_h1.json')
H4 = load('eurusd_h4.json'); W1 = load('eurusd_w1.json')

# ---------- the two inputs, exactly as TH3SkeletonFromBars reads them ----------
S = wilder_atr(D1, 14, 1)          # GetCachedDailyATR: iATR(D1,14,shift 1)
print(f"S = atrStructure = iATR(D1,14,shift1) = {f1(p(S))} pips   (P-TH3-STEP-01: completed days only, frozen within the day)")
print(f"chart bars: H1={len(H1)} H4={len(H4)} D1={len(D1)} W1={len(W1)}   (data: Yahoo EURUSD=X, 2026-10-23)")
print()

# ---------- the three candidates (course method 1, TH3Math.mqh:907-909) ----------
def candidates(S, P):
    long_ = 3.0 * S - 2.0 * P
    med   = 2.0 * S - 1.0 * P
    short = 0.5 * (long_ + med)
    return long_, med, short

def band_of(R):
    if R >= 1.60: return 'EXPLOSIVE'
    if R >= 1.30: return 'STRONG'
    if R >= 1.00: return 'NORMAL'
    return 'WEAK'

print("=== per-chart-TF: P = iATR(chart,14) at pivot, and the three candidates ===")
print(f"{'chart':<7}{'P (pips)':>10}{'P/S':>7}{'long':>9}{'med':>9}{'short':>9}   {'WEAK':>7}{'NORMAL':>8}{'STRONG':>8}")
chart_rows = []
for tf, bars in [('H1', H1), ('H4', H4), ('D1', D1), ('W1', W1)]:
    P = wilder_atr(bars, 14, 1)
    lo, me, sh = candidates(S, P)
    order = sorted([lo, me, sh])                     # TH3Math.mqh:923-935 insertion sort
    w  = order[0] if order[0] > 0 else 0.0
    n  = order[1] if order[1] > 0 else 0.0
    st = order[2] if order[2] > 0 else 0.0
    chart_rows.append((tf, P, P / S if S else 0, lo, me, sh, w, n, st))
    print(f"{tf:<7}{f1(p(P)):>10}{P/S:>7.2f}{f1(p(lo)):>9}{f1(p(me)):>9}{f1(p(sh)):>9}   "
          f"{f1(p(w)):>7}{f1(p(n)):>8}{f1(p(st)):>8}")
print("   (0.0 in a band column = that band gets NO step: base <= 0 -> return false)")
print()

print("=== death boundaries: sweep P/S, which candidate dies where ===")
print(f"{'P/S':>6}{'long':>9}{'med':>9}{'short':>9}   WEAK/NORMAL/STRONG alive?")
for r in [0.0, 0.5, 0.8, 1.0, 1.2, 1.4, 1.49, 1.5, 1.6, 5.0/3.0, 1.8, 2.0, 2.2]:
    P = r * S
    lo, me, sh = candidates(S, P)
    order = sorted([lo, me, sh])
    alive = ['Y' if v > 0 else '-' for v in order]
    print(f"{r:>6.2f}{f1(p(lo)):>9}{f1(p(me)):>9}{f1(p(sh)):>9}   WEAK:{alive[0]} NORMAL:{alive[1]} STRONG:{alive[2]}")
print("   WEAK dies at P>=1.5S, NORMAL at P>=5/3S (1.667S), STRONG at P>=2S")
print()

print("=== the ordering bug the sort fixed (P<S is every intraday chart) ===")
P_h1 = wilder_atr(H1, 14, 1)
lo, me, sh = candidates(S, P_h1)
print(f"with H1 numbers (P/S={P_h1/S:.2f}): long={f1(p(lo))} med={f1(p(me))} short={f1(p(sh))} pips")
print(f"  OLD: WEAK=short={f1(p(sh))}  NORMAL=med={f1(p(me))}  -> WEAK was {(p(sh)/p(me)-1)*100:.1f}% BIGGER than NORMAL")
order = sorted([lo, me, sh])
print(f"  NEW: WEAK={f1(p(order[0]))} < NORMAL={f1(p(order[1]))} < STRONG={f1(p(order[2]))}  (monotone)")
print("  algebra: short > med  <=>  2.5S-1.5P > 2S-P  <=>  P < S")
print()

print("=== cover containment multipliers (the only tunable part, TH3Math.mqh:942-946) ===")
print(f"{'coverDepth':<14}{'coverDelay':<14}{'mult':>7}")
for dname, dm in [('NONE/SHALLOW', 1.0), ('FULL', 0.85), ('DEEP', 0.70)]:
    for lname, lm in [('<=2', 1.0), ('3', 0.90), ('>=4', 0.80)]:
        print(f"{dname:<14}{lname:<14}{dm*lm:>7.2f}")
print()

print("=== worked end-to-end example: a real H1 swing (A->B) ===")
# B = highest high of the last 40 H1 bars; A = lowest low in the 25 bars before it
win = 40
b = min(range(win), key=lambda i: -H1[i][2])            # max high
lo_idx = min(range(b + 1, min(b + 26, len(H1))), key=lambda i: H1[i][3])  # min low, older
tA, tB = H1[lo_idx][0], H1[b][0]
pA, pB = H1[lo_idx][3], H1[b][2]
dp = pB - pA
minutes = (tB - tA).total_seconds() / 60.0
bars_elapsed = max(1.0, minutes / 60.0)                 # H1 -> 60-minute bars
P_b = wilder_atr(H1, 14, b)                             # chart ATR at the pivot bar
R = dp / (P_b * math.sqrt(bars_elapsed))
band = band_of(R)
lo, me, sh = candidates(S, P_b)
order = sorted([lo, me, sh])
sel = {'WEAK': order[0], 'NORMAL': order[1], 'STRONG': order[2], 'EXPLOSIVE': order[2]}[band]
print(f"A = {tA:%Y-%m-%d %H:%M} low  {pA:.5f}")
print(f"B = {tB:%Y-%m-%d %H:%M} high {pB:.5f}   (pivot bar, {b} bars back)")
print(f"dp = {f1(p(dp))} pips over {minutes/60:.1f} H1 bars")
print(f"P = iATR(H1,14,barB) = {f1(p(P_b))} pips | S = {f1(p(S))} pips | P/S = {P_b/S:.2f}")
print(f"R = dp / (P * sqrt(bars)) = {f1(p(dp))} / ({f1(p(P_b))} * sqrt({minutes/60:.1f})) = {R:.2f}  -> momentum = {band}")
print(f"candidates: long={f1(p(lo))} med={f1(p(me))} short={f1(p(sh))} -> sorted {f1(p(order[0]))} / {f1(p(order[1]))} / {f1(p(order[2]))}")
print(f"selected step ({band}) = {f1(p(sel))} pips   (cover multipliers = 1.0 in this demo: no cover axis measured)")
print(f"panel would print: skeleton {sel/PIP:.1f} pips (key <packed>)")
print()

print("=== sensitivity: what if avg_atr were Wilder vs SMA on D1 (parity question) ===")
# plain SMA-of-TR(14) variant of S for comparison
def sma_tr(bars, period, shift):
    if shift + period > len(bars): return 0.0
    return sum(tr_at(bars, shift + i) for i in range(period)) / period
S_sma = sma_tr(D1, 14, 1)
print(f"S Wilder = {f1(p(S))} pips | S SMA-of-TR = {f1(p(S_sma))} pips | gap = {(p(S)/p(S_sma)-1)*100:.1f}%")
