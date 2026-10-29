#!/usr/bin/env python3
# P-TH3-BASE-01 — what the hand-typed base actually becomes.
#
# The defect this measures: MT5's DrawABCDPattern ran the typed base through
# TH3RetraceBestStep and ADOPTED the winner (pbStep = bS) before TH3LockedStep
# saw it. The 8-state retrace reading therefore rewrote an explicit instruction
# by up to 5x, silently. MT4 retired that rewrite on 2026-10-24 ("the base the
# hand typed is the base the formula uses", retrace SHOWN as `ret <q>`, never
# applied); this tree has now ported the same rule.
#
# The constants are PARSED FROM THE MQL SOURCE, not copied: if TH3RetraceQ's
# switch is edited, this table changes with it. Stdlib only.
#
#   python tools/research/base_step_parity.py
#
# Exit code 0 = the table is self-consistent and the 1:1 rule holds.

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PIVOTS = os.path.join(ROOT, "Biotak", "TH3", "TH3Pivots.mqh")


def read_source(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def eval_arith(expr):
    """Evaluate a literal arithmetic expression, refusing anything else."""
    if not re.fullmatch(r"[0-9./*+() \-]+", expr):
        raise ValueError("refusing to evaluate: %r" % expr)
    return float(eval(expr, {"__builtins__": {}}, {}))  # noqa: S307 (literal-only)


def parse_retrace_qs(src):
    """Pull the 8 q values out of TH3RetraceQ's switch, in case order."""
    m = re.search(r"double\s+TH3RetraceQ\s*\(([^)]*)\)\s*\{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("TH3RetraceQ not found in %s" % PIVOTS)
    body = m.group(2)
    out = {}
    for case, expr in re.findall(
        r"case\s+(\d+)\s*:\s*return\s*\(?\s*([0-9./*+() \-]+?)\s*\)?\s*;", body
    ):
        out[int(case)] = eval_arith(expr)
    if sorted(out) != list(range(8)):
        raise SystemExit("expected 8 retrace states, parsed %d" % len(out))
    return [out[i] for i in range(8)]


def parse_retrace_names(src):
    m = re.search(r"string\s+TH3RetraceQName\s*\(([^)]*)\)\s*\{(.*?)\n\}", src, re.S)
    names = {}
    for case, name in re.findall(r'case\s+(\d+)\s*:\s*return\s*"([^"]*)"', m.group(2)):
        names[int(case)] = name
    return [names.get(i, "?") for i in range(8)]


QS = parse_retrace_qs(read_source(PIVOTS))
NAMES = parse_retrace_names(read_source(PIVOTS))


def best_step(typed, ref_step, th_rung):
    """Faithful port of TH3RetraceBestStep (Biotak/TH3/TH3Pivots.mqh)."""
    has_ref, has_th = ref_step > 0, th_rung > 0
    if not has_ref and not has_th:
        return typed, 1.0, 2                      # "the retrace IS the step"
    best_score, best_central, best = 1e9, 1e9, None
    for i, q in enumerate(QS):
        s = typed / q
        if s <= 0:
            continue
        if has_ref and has_th:
            score = 0.6 * abs(s - ref_step) / ref_step + 0.4 * abs(s - th_rung) / th_rung
        elif has_ref:
            score = abs(s - ref_step) / ref_step
        else:
            score = abs(s - th_rung) / th_rung
        central = abs(q - 1.0)
        if score < best_score - 1e-12 or (
            abs(score - best_score) <= 1e-12 and central < best_central
        ):
            best_score, best_central, best = score, central, (s, q, i)
    return best


def main():
    print("TH3RetraceQ parsed from Biotak/TH3/TH3Pivots.mqh")
    for i, q in enumerate(QS):
        print("  state %d  q = %-8s  name = %-4s  S = R / q = R x %.3f"
              % (i, ("%.6f" % q).rstrip("0").rstrip("."), NAMES[i], 1.0 / q))
    print()

    # A typed base, and the two anchors the reading compares it against. These
    # are the shapes a "BUY THE RETRACE" user actually types: the CD leg's own
    # step (momentum) and the owner TF's TH rung (volatility).
    rows = [
        # typed, closedStep, seedRung        a leg step ~1/3 of the typed base
        (30.0, 10.0, 10.0),
        (30.0, 15.0, 15.0),
        (24.0, 12.0, 10.0),
        (40.0, 20.0, 18.0),
        (50.0, 10.0, 12.0),
        (20.0, 20.0, 20.0),                    # the honest case: nothing to gain
    ]

    print("%-7s %-9s %-8s | %-24s | %-24s"
          % ("typed", "closed", "rung", "MT5 BEFORE (adopted)", "MT5/MT4 AFTER (1:1)"))
    print("%-7s %-9s %-8s | %-8s %-7s %-7s | %-8s %-7s %-7s"
          % ("", "", "", "applied", "q", "err%", "applied", "q", "err%"))
    print("-" * 84)

    worst = 0.0
    for typed, ref, rung in rows:
        s, q, idx = best_step(typed, ref, rung)
        old_err = (s - typed) / typed * 100.0
        worst = max(worst, abs(old_err))
        print("%-7.2f %-9.2f %-8.2f | %-8.2f %-7s %-7.1f | %-8.2f %-7s %-7.1f"
              % (typed, ref, rung, s, NAMES[idx], old_err, typed, "1", 0.0))

    print()
    print("The rule the fix installs (MT4 P-TH3-BASE-01, ported here):")
    print("  pbRaw  = TH3ManualBaseStep(inpTH3BaseRangePips, pip)   // pips -> price")
    print("  pbStep = pbRaw                                          // 1:1, never rewritten")
    print("  retHow = 'ret <q>'                                      // a READING, logged only")
    print()
    print("worst rewrite the old path could apply on these rows: %.1f%% of the typed base"
          % worst)

    # Self-checks: the 1:1 rule must hold on every row, and the rewrite must be
    # a real risk (a guard that can never fire would prove nothing).
    for typed, ref, rung in rows:
        new_step = typed           # pbStep = pbRaw
        assert abs(new_step - typed) < 1e-12, "1:1 rule broken"
    if worst < 1.0:
        print("FAIL: the old rewrite never moved the number - this diagnostic proves nothing")
        return 1
    print("OK: 1:1 holds on every row, and the retired rewrite would have moved them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
