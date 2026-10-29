#!/usr/bin/env python3
# TH3Tool ladder step on real EURUSD numbers.
# Mirrors: TH3UnifiedK + CalculateUnifiedMasterStep (TH3Pivots.mqh:1851-1877),
# TH3PatternStepRungTF (TH3Pivots.mqh:1469), THAbilityPrice (THCalculations.mqh:133),
# TH3ClosedOwnerTFEx (TH3Pivots.mqh:1424) and the 7-level ladder (TH3Tool.mqh:5184,
# TH3Renderer.mqh:1775-1799).
# Pure stdlib. Outputs in PIPS (EURUSD pip = 0.0001).
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
    bars.reverse()          # index 0 = newest bar
    return bars

H1 = load('eurusd_h1.json'); H4 = load('eurusd_h4.json')
D1 = load('eurusd_d1.json'); W1 = load('eurusd_w1.json')

FRACTAL = {60: 0.1666, 240: 0.3333, 1440: 0.6666, 10080: 2.6664}
RUNG_NAME = {60: 'H1+M4', 240: 'H4+M16', 1440: 'H17+M4', 10080: 'D11+H9+M4'}
SERIES = {60: H1, 240: H4, 1440: D1, 10080: W1}

def p(x): return x / PIP
def f1(x): return round(x, 1)

def th3_unified_k(ratio):
    if ratio <= 0.85: return 2.5
    if ratio <= 1.20: return 3.0
    if ratio <= 1.80: return 3.5
    return 1.0

def owner_tf(tf_min, cd_bars):
    if cd_bars <= 7: return tf_min
    owner, bars = tf_min, cd_bars
    up_map = {60: 240, 240: 1440, 1440: 10080}
    for _ in range(6):
        up = up_map.get(owner, owner)
        if up == owner: return owner
        bars = int(round(bars * owner / up))
        owner = up
        if bars <= 7: return owner
    return owner

def rung_price(tf_min):
    return SERIES[tf_min][1][4] * FRACTAL[tf_min] / 100.0

def unified_master_step(leg_cd, ratio, mother_in, rung):
    step_mother = mother_in / 3.0 if (mother_in >= 2.5 * rung) else mother_in
    if step_mother <= 0: step_mother = rung
    k = th3_unified_k(ratio)
    step_pattern = leg_cd / k
    final = math.sqrt(step_mother * step_pattern)
    if final <= 0: final = step_pattern if step_pattern > 0 else rung
    return final, step_mother, step_pattern, k

def analyze(a, b, c, d, title):
    tA, tB, tC, tD = H1[a][0], H1[b][0], H1[c][0], H1[d][0]
    pA, pB, pC, pD = H1[a][3], H1[b][2], H1[c][3], H1[d][2]
    legAB, legBC, legCD = abs(pB - pA), abs(pC - pB), abs(pD - pC)
    ratio = legCD / legBC if legBC else 0.0
    cd_bars = c - d
    own = owner_tf(60, cd_bars)
    rung = rung_price(own)
    base, sm, sp, k = unified_master_step(legCD, ratio, 0.0, rung)

    print(f"=== {title} ===")
    print(f"A {tA:%Y-%m-%d %H:%M} low  {pA:.5f}")
    print(f"B {tB:%Y-%m-%d %H:%M} high {pB:.5f}")
    print(f"C {tC:%Y-%m-%d %H:%M} low  {pC:.5f}")
    print(f"D {tD:%Y-%m-%d %H:%M} high {pD:.5f}")
    print(f"legs AB {f1(p(legAB))} | BC {f1(p(legBC))} | CD {f1(p(legCD))} pips")
    print(f"CD/BC = {ratio:.2f} | CD bars = {cd_bars} | owner TF = {own} ({RUNG_NAME[own]})")
    print(f"K = {k} | step_pattern = CD/K = {f1(p(sp))} | step_mother = rung = {f1(p(rung))} "
          f"(close {SERIES[own][1][4]:.5f} x {FRACTAL[own]}%)")
    print(f"baseUnit = sqrt({f1(p(sm))} x {f1(p(sp))}) = {f1(p(base))} pips")
    print("levels from D:")
    for i in range(7):
        lv = pD - (i + 1) * base if pD > pC else pD + (i + 1) * base
        tag = 'T%d' % (i + 1) if (i + 1) % 2 == 1 else 'mid T%d' % (i + 1)
        print(f"  L{i+1} {tag:<7} {f1(p(abs(lv - pD))):>7} pips   {lv:.5f}")
    print()
    return dict(base=base, ratio=ratio, k=k, own=own, rung=rung, cd=legCD, bars=cd_bars)

# ---------- example 1: the most recent structure ----------
win = 40
b1 = max(range(win), key=lambda i: H1[i][2])
a1 = min(range(b1 + 1, min(b1 + 26, len(H1))), key=lambda i: H1[i][3])
c1 = min(range(0, b1), key=lambda i: H1[i][3])
d1 = max(range(0, c1), key=lambda i: H1[i][2])
e1 = analyze(a1, b1, c1, d1, "example 1 - the most recent structure")

# ---------- example 2: a wider CD (so the owner TF has to climb) ----------
# indices: D < C < B < A  (0 = newest bar); cdBars = C - D
best = None
for dd in range(2, 200):
    hh = H1[dd][2]
    if not (hh > H1[dd-1][2] and hh > H1[dd-2][2] and hh > H1[dd+1][2] and hh > H1[dd+2][2]):
        continue                      # D must be a local swing high
    lo_hi = min(dd + 31, len(H1))
    if dd + 8 >= lo_hi: continue
    cc = min(range(dd + 8, lo_hi), key=lambda i: H1[i][3])   # C = lowest low 8..30 bars older
    bars = cc - dd
    if not (8 <= bars <= 30): continue
    bb_idx = max(range(cc + 1, min(cc + 26, len(H1))), key=lambda i: H1[i][2])  # B older than C
    if H1[cc][3] >= H1[bb_idx][2]: continue                  # C must retrace below B
    aa = min(range(bb_idx + 1, min(bb_idx + 26, len(H1))), key=lambda i: H1[i][3])
    best = (aa, bb_idx, cc, dd); break
e2 = analyze(best[0], best[1], best[2], best[3], "example 2 - a wider CD leg") if best else None

print("=== K table: the same CD at other retracement ratios ===")
print(f"{'CD/BC':>7}{'K':>6}{'baseUnit':>11}")
for r in [0.60, 0.85, 1.00, 1.20, 1.50, 1.80, 2.00, 2.50]:
    bb, _, _, kk = unified_master_step(e1['cd'], r, 0.0, e1['rung'])
    print(f"{r:>7.2f}{kk:>6.1f}{f1(p(bb)):>11}")
print()

print("=== the hand-typed mother (inpTH3PivotBasePips), example 1 ===")
rung = e1['rung']
print(f"2.5 x rung gate = {f1(p(2.5*rung))} pips")
print(f"{'typed':>7}{'branch':>22}{'step_mother':>13}{'baseUnit':>11}")
for typed in [10, 20, 46, 47, 100, 200, 400, 800]:
    m = typed * PIP
    branch = 'macro / 3' if m >= 2.5 * rung else 'knot as typed'
    bb, sm2, _, _ = unified_master_step(e1['cd'], e1['ratio'], m, rung)
    print(f"{typed:>7}{branch:>22}{f1(p(sm2)):>13}{f1(p(bb)):>11}")
print()

print("=== sensitivity: the owner TF changes the rung (and the step) ===")
for tf in [60, 240, 1440, 10080]:
    r2 = rung_price(tf)
    b2, _, _, _ = unified_master_step(e1['cd'], e1['ratio'], 0.0, r2)
    print(f"owner {RUNG_NAME[tf]:<14} rung {f1(p(r2)):>7} -> baseUnit {f1(p(b2)):>7} pips")
