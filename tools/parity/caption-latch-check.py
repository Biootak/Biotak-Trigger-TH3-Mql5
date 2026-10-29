#!/usr/bin/env python3
# P-TH3-DEL4 — the caption latch is asked by every path that can repaint it.
#
# A dismissal is only durable if there is exactly ONE writer of the latch and
# NO paint path that skips the question. That is a structural property of the
# source, so it is checked here instead of being asserted in a comment:
#
#   1. TH3InfoOffAdd (the latch writer) is called from exactly one function,
#      and that function is TH3InfoFamilyDismiss.
#   2. TH3InfoFamilyDismiss is called from exactly one function, and that
#      function is TH3InfoOnMemberDelete (the delete handler's answer).
#   3. Every function that CREATES caption ink (TH3ROPlateAt / TH3RORowAt) is
#      either guarded by TH3InfoOff itself, or reachable only from a caller
#      that is. The reachable-only case must be declared in ALLOWED below, so
#      adding a new paint path fails this check until it is justified.
#
# Source-truth, no heuristics: bodies are split by brace matching.
#
#   python tools/parity/caption-latch-check.py
#
# Exit 0 = invariant holds. Exit 1 = a path can resurrect a dismissed readout.

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
RENDERER = os.path.join(ROOT, "Biotak", "TH3", "TH3Renderer.mqh")
TOOL = os.path.join(ROOT, "Biotak", "TH3Tool.mqh")

# Paint paths that carry no guard of their own, and the guarded owner that is
# the only way in. Keep this list tiny and justified: each entry is a claim
# that the caller asks the latch first.
ALLOWED = {
    "TH3InfoFamilyPlateGrow": (
        "TH3InfoFamilySetVisible / TH3InfoFamilyVerify",
        "grows the plate from rows that a guarded owner already authorised",
    ),
}

FN_RE = re.compile(
    r"^[ \t]*(?:void|int|bool|double|string|long|uint|color|datetime)\s+"
    r"([A-Za-z_]\w*)\s*\([^;]*?\)\s*$",
    re.M,
)


def strip_comments(src):
    """Blank out // and /* */ so calls in prose never count as calls."""
    out, i, n = [], 0, len(src)
    while i < n:
        two = src[i:i + 2]
        if two == "//":
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif two == "/*":
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
        elif src[i] == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1])
            i = j + 1
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def function_bodies(src):
    """name -> (body, start_line). Brace-matched from each definition line."""
    bodies = {}
    for m in FN_RE.finditer(src):
        name = m.group(1)
        if name in bodies:
            continue
        brace = src.find("{", m.end())
        if brace < 0:
            continue
        depth, i = 0, brace
        while i < len(src):
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = src[brace:i + 1]
        bodies[name] = (body, src.count("\n", 0, m.start()) + 1)
    return bodies


def callers_of(bodies, target):
    """Functions whose body calls target (word-boundary, not a definition)."""
    pat = re.compile(r"\b%s\s*\(" % re.escape(target))
    return sorted(n for n, (b, _) in bodies.items() if pat.search(b))


def main():
    renderer = strip_comments(open(RENDERER, encoding="utf-8", errors="replace").read())
    tool = strip_comments(open(TOOL, encoding="utf-8", errors="replace").read())
    bodies = function_bodies(renderer)
    bodies.update(function_bodies(tool))

    failures = []

    # --- 1. one writer of the latch -------------------------------------
    writers = callers_of(bodies, "TH3InfoOffAdd")
    print("1. writers of the latch (TH3InfoOffAdd):")
    for w in writers:
        print("     %s()  line %d" % (w, bodies[w][1]))
    if writers != ["TH3InfoFamilyDismiss"]:
        failures.append("latch writers = %r, expected ['TH3InfoFamilyDismiss']" % writers)

    # --- 2. one caller of the dismissal verb ----------------------------
    dismiss_callers = callers_of(bodies, "TH3InfoFamilyDismiss")
    print("2. callers of TH3InfoFamilyDismiss():")
    for c in dismiss_callers:
        line = next((ln for ln, t in enumerate(bodies[c][0].split("\n"), 1)
                     if "TH3InfoFamilyDismiss" in t), 0)
        print("     %s()  +%d" % (c, line))
    if dismiss_callers != ["TH3InfoOnMemberDelete"]:
        failures.append(
            "dismissal callers = %r, expected ['TH3InfoOnMemberDelete']" % dismiss_callers
        )

    # --- 3. every paint path asks the question --------------------------
    # "Caption family" is defined by its NAMING owners: a painter belongs to
    # the caption iff it builds names through TH3InfoLineName/TH3InfoPlateName.
    # (The leg meter's box paints through its own prefix and is a different
    # readout with its own contract, P-LM-17 — it must not be counted here.)
    painters = [n for n, (b, _) in bodies.items()
                if re.search(r"\bTH3(?:ROPlateAt|RORowAt)\s*\(", b)
                and re.search(r"\bTH3Info(?:LineName|PlateName)\s*\(", b)
                and n not in ("TH3ROPlateAt", "TH3RORowAt")]
    print("3. functions that create caption ink:")
    for p in sorted(painters):
        body, line = bodies[p]
        guarded = re.search(r"\bTH3InfoOff\s*\(", body) is not None
        if guarded:
            verdict = "guarded by TH3InfoOff"
        elif p in ALLOWED:
            verdict = "UNGUARDED, allowed: %s" % ALLOWED[p][0]
        else:
            verdict = "UNGUARDED - FAIL"
            failures.append("%s() creates caption ink without asking the latch" % p)
        print("     %-26s line %-5d %s" % (p, line, verdict))

    print()
    if failures:
        for f in failures:
            print("FAIL: " + f)
        return 1
    print("OK: one latch writer, one dismissal caller, every paint path asks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
