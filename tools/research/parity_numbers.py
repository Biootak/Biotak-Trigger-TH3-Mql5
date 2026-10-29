#!/usr/bin/env python3
# Numerical parity: Pine TRex formulas vs Biotak Trigger TH3 (MT5) on EURUSD.
# Data: Yahoo Finance EURUSD=X (D1 2y, H1 90d, H4 90d, W1 10y, MO1 10y), fetched 2026-10-23.
# Pure stdlib. All outputs in PIPS (EURUSD pip = 0.0001) unless noted.
import json, datetime, os

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
        bars.append((datetime.datetime.fromtimestamp(ts[i], datetime.UTC).date(), float(o), float(h), float(l), float(c)))
    bars.reverse()          # index 0 = newest bar (MT4 shift semantics)
    return bars

def tr_at(bars, j):
    # true range at bar j; previous close = close of the OLDER bar (j+1);
    # at the oldest available bar, prev close = own close (data edge)
    _, _, h, l, c = bars[j]
    pc = bars[j + 1][4] if j + 1 < len(bars) else c
    return max(h - l, abs(h - pc), abs(l - pc))

def sma_leg(bars, period, shift):
    # OUR TrexSMALeg (ATRCalculations.mqh:979): window bars shift..shift+period-1;
    # the NEWEST bar of the window (i==0) uses its OWN close as prev close.
    if not has_bars(bars, period, shift):
        return 0.0
    s = 0.0
    for i in range(period):
        j = shift + i
        _, _, h, l, c = bars[j]
        pc = c if i == 0 else (bars[j + 1][4] if j + 1 < len(bars) else c)
        s += max(h - l, abs(h - pc), abs(l - pc))
    return s / period

def has_bars(bars, period, shift):
    # window needs bars[shift .. shift+period-1]
    return shift + period <= len(bars)

def plain_sma_tr(bars, period, shift):
    # Pine ta.sma(ta.tr(true), period) at bar shift: every bar uses its true prev close.
    if not has_bars(bars, period, shift):
        return 0.0
    s = 0.0
    for i in range(period):
        s += tr_at(bars, shift + i)
    return s / period

def wilder_atr(bars, period, shift):
    # MQL4 iATR(period, shift): RMA over TR, seeded with SMA(TR,period).
    need = shift + period
    if need >= len(bars):
        return 0.0
    trs = [tr_at(bars, j) for j in range(shift, shift + period)]   # newest..oldest
    atr = sum(trs) / period                                        # seed at oldest bar of window
    for k in range(period - 2, -1, -1):                            # smooth toward newer bars
        atr = (atr * (period - 1) + trs[k]) / period
    return atr

LEGS = [(5, 1), (10, 1), (21, 2), (66, 3), (132, 5), (264, 8)]

def composite(bars, shift, tf):
    # OUR ATRWeightedComposite (ATRCalculations.mqh:1179): six weighted SMA-of-TR legs;
    # W1 -> iATR(55), MN1 -> iATR(30) (single leg, weight 1).
    if tf == 'W1':
        return wilder_atr(bars, 55, shift)
    if tf == 'MN1':
        return wilder_atr(bars, 30, shift)
    ws, tw = 0.0, 0
    for p, w in LEGS:
        v = sma_leg(bars, p, shift)
        if v > 0:
            ws += v * w
            tw += w
    return ws / tw if tw else 0.0

def atr254(bars, shift, mode='sma'):
    if not has_bars(bars, 254, shift):
        return None
    return plain_sma_tr(bars, 254, shift) if mode == 'sma' else wilder_atr(bars, 254, shift)

def p(x):    # price units -> pips
    return x / PIP

def f1(x):
    return round(x, 1)

D1 = load('eurusd_d1.json'); H1 = load('eurusd_h1.json'); H4 = load('eurusd_h4.json')
W1 = load('eurusd_w1.json'); MO1 = load('eurusd_mo1.json')
SH = 1   # last CLOSED bar (our shift=1 law); D1[1] = 2026-10-22
print(f"data: D1 {D1[1][0]} (closed) .. {D1[0][0]} (live) | bars D1={len(D1)} H1={len(H1)} H4={len(H4)} W1={len(W1)} MO1={len(MO1)}")
print(f"close(last closed) = {D1[SH][4]:.5f}   live = {D1[0][4]:.5f}")
print()

# ---------------- PINE side (chart TF = D1) ----------------
mATR      = atr254(D1, SH)                    # assumed mATR = atr254 of chart TF
mATR_w    = atr254(D1, SH, 'wilder')          # sensitivity: Wilder variant
a254_H4   = atr254(H4, SH)
a254_H1   = atr254(H1, SH)
a254_W1   = atr254(W1, SH)
a254_MO1  = atr254(MO1, SH)
close_c   = D1[SH][4]
apr66     = close_c * 0.06666                 # price mode
apr66_pip = (close_c * 0.006666) / PIP        # pip mode (as written in the Pine)
aprD1     = apr66
TAPR      = aprD1
matr      = a254_H4                           # one rung down: D1 -> H4
matr3     = a254_H1                           # two rungs down: D1 -> H1
matrsakh  = a254_MO1                          # two rungs up:  D1 -> MO1
engsl     = mATR * 0.1818
hunsl     = matr + matr3
tp1 = mATR; tp3 = 3 * mATR; tp7 = 7 * mATR; tp15 = 15 * mATR
pivotsl   = tp1
mATRPIP   = mATR / PIP
matrP     = matr / PIP
thlong_pip  = round(3 * mATRPIP - 2 * matrP)          # pip mode (math.round)
thsmall_pip = round(2 * mATRPIP - 1 * matrP)
thlong_raw  = 3 * mATR - 2 * matr                     # price mode (unrounded)
thsmall_raw = 2 * mATR - 1 * matr
live55 = plain_sma_tr(D1, 55, 0); live7 = plain_sma_tr(D1, 7, 0); live3 = plain_sma_tr(D1, 3, 0)

# ---------------- OURS side (chart TF = D1) ----------------
compD1 = composite(D1, SH, 'D1')
compH1 = composite(H1, SH, 'H1'); compH4 = composite(H4, SH, 'H4'); compW1 = composite(W1, SH, 'W1')
engD1  = compD1 / 4.266666
hunter = (8.0 / 3.0) * engD1
engW1  = compW1 / 4.266666
slD1   = 1.20 * engW1
tpA = slD1 * 7 / 3; tpB = slD1 * 5; tpC = slD1 * 31 / 3; tpD = slD1 * 30
stShort = compD1 * 1.5; stMid = (stShort + compD1 * 2.0) / 2; stLong = compD1 * 2.0
tg3 = int(p(compD1 * 3)); tg5 = int(p(compD1 * 5)); tg15 = int(p(compD1 * 15))
S = wilder_atr(D1, 14, SH)          # GetCachedDailyATR: D1 ATR(14), shift 1
Pv = wilder_atr(D1, 14, SH)         # pattern ATR read at the pivot bar; demo uses shift 1
longStep = 3 * S - 2 * Pv; medStep = 2 * S - 1 * Pv; shortStep = (longStep + medStep) / 2

row = lambda name, pine, ours: print(f"{name:<34} {f1(p(pine)):>9} {f1(p(ours)):>9} {f1(p(pine)/p(ours)) if p(ours) else 0:>8}")
print("=== per-TF ATR ladder (pips) — Pine atr254 vs our composite ===")
print(f"{'':<34} {'Pine':>9} {'Ours':>9} {'ratio':>8}")
for tf, pb, ob, lbl in [('H1', atr254(H1, SH), compH1, 'H1'), ('H4', atr254(H4, SH), compH4, 'H4'),
                        ('D1', mATR, compD1, 'D1 (chart)'), ('W1', a254_W1, compW1, 'W1')]:
    row(f"{lbl} ATR", pb, ob)
print()
print("=== SL / TP family on the D1 chart (pips) ===")
print(f"{'':<34} {'Pine':>9} {'Ours':>9} {'ratio':>8}")
row("engsl / Eng", engsl, engD1)
row("hunsl / Hunter", hunsl, hunter)
row("SL (pivotsl vs plan SL)", pivotsl, slD1)
print()
print("Pine ladder = multiples of mATR (chart-TF atr254):")
print(f"  tp1 {f1(p(tp1))} | tp3 {f1(p(tp3))} | tp7 {f1(p(tp7))} | tp15 {f1(p(tp15))}")
print("Our ladder = multiples of SL (= 1.2 x Eng(W1)):")
print(f"  TP1 {f1(p(tpA))} | TP2 {f1(p(tpB))} | TP3 {f1(p(tpC))} | TP4 {f1(p(tpD))}")
print()
print("=== thresholds & steps (pips) ===")
print(f"{'':<34} {'Pine':>9} {'Ours':>9} {'ratio':>8}")
row("TH.long / longStep", thlong_raw, longStep)
row("TH.small / medStep", thsmall_raw, medStep)
print("  ^ identical formulas 3S-2P / 2S-P; the gap comes from the inputs:")
print(f"    Pine:  S = mATR (chart atr254) = {f1(p(mATR))}   P = matr (atr254 one rung down) = {f1(p(matr))}")
print(f"    Ours:  S = D1 ATR(14) shift1    = {f1(p(S))}   P = chart ATR(14) at pivot = {f1(p(Pv))}  (demo: pivot = last closed bar, so P = S and the three steps collapse to S)")
th_lo = close_c * 0.0208; th_hi = close_c * 5.3328
print(f"TAPR (apr66) = 6.666% of close = {f1(p(apr66))} pips | our TH ladder = fixed % of price 2.08%..533.28% = {f1(p(th_lo))}..{f1(p(th_hi))} pips")
print()
print("=== Pine APR ladder (pips, price mode) ===")
for lbl, v in [("apr66", apr66), ("aprD1 = TAPR", aprD1)]:
    print(f"{lbl:<34} {f1(p(v)):>9}")
print(f"apr66 pip-mode variant:            {f1(apr66_pip):>9}   <-- 10x discrepancy inside the Pine")
ms = (f"{f1(p(matrsakh))} pips" if matrsakh is not None
      else f"N/A - MO1 has only {len(MO1)} bars (needs 254)")
print(f"matr (atr254H4) {f1(p(matr))} | matr3 (atr254H1) {f1(p(matr3))} | matrsakhtar (atr254MO1) {ms}")
print(f"live D1 ATR 55/7/3 (shift 0, pips): {f1(p(live55))} / {f1(p(live7))} / {f1(p(live3))}")
print()
print("=== our label row (D1, pips) ===")
print(f"composite {f1(p(compD1))} | steps (1.5-mid-2.0): {f1(p(stShort))} / {f1(p(stMid))} / {f1(p(stLong))} | targets 3/5/15: {tg3} / {tg5} / {tg15}")
print(f"TH3 step inputs: S(D1 ATR14,shift1) = {f1(p(S))} | P(chart ATR14@pivot) = {f1(p(Pv))}")
print()
print("=== Pine sensitivity (avg_atr definition unknown) ===")
print(f"atr254(D1) SMA-of-TR : {f1(p(mATR))} pips   (primary)")
print(f"atr254(D1) Wilder    : {f1(p(mATR_w))} pips   (variant)")
print(f"engsl under Wilder   : {f1(p(mATR_w * 0.1818))} pips  vs our Eng {f1(p(engD1))}")
