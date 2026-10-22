#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Per-symbol gap report: what MT4 has that this MT5 tree does not.

module-report.py answers "is this module byte-for-byte the MT4 module modulo
declared platform idioms?"  This tool answers the next question, for a human
reading a work list: WHICH symbols are missing, and WHICH shared symbols have a
different body?

  * MT4 side = build_ref(): the MT4 file with every part include inlined (the
    MT4 tree split several monoliths into _A/_B/Ring files; MT5 still carries
    the monoliths, so the split itself is not a difference).
  * Both sides are cut into named symbols with module-report's chunker.
  * A symbol only on the MT4 side          -> MISSING (lost feature/logic).
  * A symbol on both sides, body differs   -> DRIFT   (same name, other code;
    the diff size says how much, and the P-* tags on both sides say which fix).
  * A symbol only on the MT5 side          -> EXTRA   (see module-report.py).

Read-only.  Never writes.

  python tools/parity/gap-report.py                 # every shared module
  python tools/parity/gap-report.py --only DrawToolbar.mqh
  python tools/parity/gap-report.py --tags          # attach P-* ids to each row
"""
import argparse
import collections
import difflib
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

TAG = re.compile(r"P-[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*")


def tags_of(lines):
    found = []
    for ln in lines:
        for t in TAG.findall(ln):
            if t not in found:
                found.append(t)
    return found


def chunks_by_name(lines):
    out = collections.OrderedDict()
    for name, body in MR.chunks(lines):
        out.setdefault(name, []).append(body)
    return out


def body_lines(body):
    return [t for t in (MR.norm_line(x) for x in body) if t]


def flat(name, bodies):
    """All lines of every definition of a name, deduplicated as a multiset."""
    acc = []
    for b in bodies:
        acc.extend(body_lines(b))
    return acc


def compare(rel):
    p4 = os.path.join(MR.MT4_REPO, rel)
    p5 = os.path.join(MR.MT5_REPO, rel)
    if not (os.path.exists(p4) and os.path.exists(p5)):
        return None
    a = chunks_by_name(MR.build_ref(p4))
    b = chunks_by_name(MR.read(p5))
    rows = []
    for name, bodies in a.items():
        if name in ("#preproc", "#decls"):
            continue
        la = flat(name, bodies)
        lb = flat(name, b.get(name, []))
        if not lb:
            rows.append(("MISSING", name, len(la), 0, tags_of(bodies[0])))
            continue
        ca, cb = collections.Counter(la), collections.Counter(lb)
        diff = sum((ca - cb).values()) + sum((cb - ca).values())
        if diff:
            sm = difflib.SequenceMatcher(None, la, lb)
            pct = int(round(100 * (1 - sm.ratio())))
            rows.append(("DRIFT", name, diff, pct,
                         tags_of([x for bb in bodies for x in bb])))
    for name in b:
        if name in ("#preproc", "#decls") or name in a:
            continue
        rows.append(("EXTRA", name, len(flat(name, b[name])), 0, []))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--tags", action="store_true")
    ap.add_argument("--min", type=int, default=1,
                    help="hide DRIFT rows with fewer differing lines")
    args = ap.parse_args()

    mods = MR.modules()
    names = args.only or [m[0].replace(os.sep, "/") for m in mods]
    total = collections.Counter()
    for name in names:
        rows = compare(name)
        if rows is None:
            print("  ?? %-42s (not on both sides)" % name)
            continue
        miss = [r for r in rows if r[0] == "MISSING"]
        drift = [r for r in rows if r[0] == "DRIFT" and r[2] >= args.min]
        extra = [r for r in rows if r[0] == "EXTRA"]
        total["MISSING"] += len(miss)
        total["DRIFT"] += len(drift)
        total["EXTRA"] += len(extra)
        if not (miss or drift or extra):
            print("  OK  %-42s" % name)
            continue
        print("  !!  %-42s missing=%d drift=%d extra=%d"
              % (name, len(miss), len(drift), len(extra)))
        for kind, sym, n, pct, tg in sorted(miss + drift + extra,
                                            key=lambda r: -r[2])[:40]:
            if kind == "DRIFT":
                where = "DRIFT  %4d lines, %3d%% different" % (n, pct)
            else:
                where = "%-7s%4d lines" % (kind, n)
            tail = ""
            if args.tags and tg:
                tail = "   [" + " ".join(tg[:6]) + "]"
            print("        %-8s %-44s %s%s"
                  % (kind, sym[:44], where, tail))
    print()
    print("TOTAL symbols: MISSING=%d DRIFT=%d EXTRA=%d"
          % (total["MISSING"], total["DRIFT"], total["EXTRA"]))


if __name__ == "__main__":
    main()
