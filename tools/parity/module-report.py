#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Module-by-module MT4 (reference) vs MT5 comparison.  ONE question: are the
two builds the same code, so they produce the same numbers?

POLICY (user, 2026-10-03)

    "exactly like MT4 - nothing less, nothing more; remove MT5's extras too"

So the verdict is deliberately strict:

  * MT4 is the reference.  For every MT4 module the reference is rebuilt the way
    the compiler sees it - the MT4 file plus every part file it includes - so
    nothing of MT4 can be missed.
  * Both sides are cut into NAMED SYMBOLS (function / #define / struct /
    declaration block).  A symbol that exists on only ONE side is printed: an
    MT4-only symbol is lost logic, an MT5-only symbol is an extra to remove.
  * The verdict per module compares the MULTISET OF CODE LINES of the whole
    module (comments and whitespace removed, preprocessor architecture such as
    include guards and #include lines excluded, #define constants kept because
    they carry numbers).  A line that exists on both sides is not a difference,
    so re-ordering and alignment can never hide or invent one.
  * A line that exists on one side only is a real difference.  It is tolerated
    ONLY if it matches a declared PLATFORM idiom in JUSTIFY (each with a reason
    and the side it may appear on).  Anything else is UNJUSTIFIED -> RED.
    Because MT5 features must now be REMOVED, no MT5-only feature is
    allowlisted: every one of them shows up as work.

If the report is clean, the MT5 module is the MT4 module modulo the MQL5 API
adaptation - i.e. the same arithmetic, the same numbers.

  python tools/parity/module-report.py                 # full report
  python tools/parity/module-report.py --quiet         # one line per module
  python tools/parity/module-report.py --only LevelPipeline.mqh TH3Math.mqh
  python tools/parity/module-report.py --show-ok       # list identical symbols too
"""
import argparse
import collections
import importlib.util
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
MT5_REPO = os.path.dirname(os.path.dirname(HERE))
MT4_REPO = os.path.join(os.path.dirname(MT5_REPO), "Biotak-Trigger-TH3-mql4")
MT4_BIOTAK = os.path.join(MT4_REPO, "Biotak")
MT5_BIOTAK = os.path.join(MT5_REPO, "Biotak")

INC = re.compile(r'^\s*#include\s+[<"]([^>"]+)[>"]\s*(?://.*)?$')
DEFINE = re.compile(r'^#define\s+(\w+)')
GUARD = re.compile(r'^#define\s+\w+(_MQH|_H)?\s*$')

# ---------------------------------------------------------------------------
# Declared PLATFORM idioms only.  A one-sided line is tolerated only if it
# matches one of these AND appears on the side the pattern allows.  Every entry
# is an MQL5 API adaptation that changes no arithmetic.
# ---------------------------------------------------------------------------
JUSTIFY = [
    (r'ObjectCreate\(\s*0\s*,\s*\w+\s*,\s*type\s*,',
     "MQL4 untyped ObjectCreate overload", "mt4"),
    (r'ObjectCreate\(\s*0\s*,\s*\w+\s*,\s*\(ENUM_OBJECT\)type\s*,',
     "MQL5 ObjectCreate needs the explicit enum cast", "mt5"),
    (r'ObjectCreate\(\s*0\s*,\s*\w+\s*,\s*type\s*,',
     "MQL4 untyped ObjectCreate overload", "mt4"),
    (r'CopyTime\(Symbol\(\),\s*\(ENUM_TIMEFRAMES\)',
     "MT4 timeframe cast in CopyTime", "mt4"),
    (r'\bCompatTF\b', "MT4 timeframe number mapped through CompatTF", "mt5"),
    (r'\biBars\s*\(', "MQL4 Bars() -> MQL5 iBars()", "mt5"),
    (r'\bCompat[A-Z]\w*\(', "MT5 compatibility shim call", "mt5"),
    (r'#include\s+[<"][^>"]*[Cc]ompat', "MT5 compatibility shim include", "mt5"),
    (r'\biATR\s*\(', "MQL5 iATR accessor", "mt5"),
    (r'ArraySetAsSeries\(\s*\w+\s*,\s*true\s*\);',
     "MQL5 arrays are not timeseries by default, MQL4's always were", "mt5"),
    (r'(?<![\w.])Bars\s*\(', "MQL4 Bars(symbol,timeframe) call", "mt4"),
    (r'(?<![\w.])iBars\s*\(', "MQL5 iBars(symbol,timeframe) call", "mt5"),
    (r'\bPeriodSeconds\s*\(', "MT4 PeriodSeconds", "mt4"),
    (r'\b(ENUM_TIMEFRAMES)\s*\(\s*timeframe', "MT5 enum cast for a timeframe", "mt5"),
    (r'^\s*#\w+', "preprocessor line", "both"),
    # --- MT5-ONLY resource/API adaptations (each one is a declared module
    # --- patch in resync-module.py's MODULE_PATCHES, so a resync preserves it)
    (r'ReleaseATRHandleCache\(',
     "MQL5 iATR is handle-based: the cached handles are released on deinit",
     "mt5"),
    (r'\bChartScreenShot\(',
     "MQL4 WindowScreenShot has no MQL5 counterpart (return contract differs)",
     "mt5"),
    # --- the entry's OnCalculate bridge into the emulated series
    (r'^\s*rates_total,\s*$',
     "OnCalculate already knows the bar count - saves the iBars() call", "mt5"),
    (r'\(rates_total\s*>\s*0\)\s*\?\s*\w+\[rates_total\s*-\s*1\]',
     "the forming bar's live value, taken from OnCalculate's own arrays",
     "mt5"),
    # --- MT5-ONLY render-cost work. Each is a declared MODULE_PATCH in
    # --- resync-module.py, and each REMOVES terminal calls; none adds logic.
    (r'PipDistanceLabelLift',
     "one label lift per render pass instead of three chart reads per level",
     "mt5"),
    (r's_lastSweptTotal', "the orphan-plate sweep is gated on the object count",
     "mt5"),
    (r'\btotalNow\b', "the orphan-plate sweep is gated on the object count",
     "mt5"),
    (r'CHART_CONTEXT_MENU', "MT5 hides the native context menu behind these",
     "mt5"),
    (r'\b_cl(Ms|Now)\b',
     "the compat ledger's 60 s heartbeat (measurement build only)", "mt5"),
    # --- the P-* diagnostics are DEBUG-gated on the MT5 side (a resync patch)
    # --- and bare Prints on the MT4 side. Both spellings are the same diagnostic.
    (r'_LOG_GATE_D Print\("\[P-',
     "project diagnostic behind the DEBUG gate (off in production)", "mt5"),
    (r'Print\("\[P-',
     "project diagnostic that MT5 gates behind DEBUG", "mt4"),
    (r'_LOG_GATE_D Print\("\[HTF\]',
     "project diagnostic behind the DEBUG gate (off in production)", "mt5"),
    (r'Print\("\[HTF\]',
     "project diagnostic that MT5 gates behind DEBUG", "mt4"),
    # --- MT5-only object housekeeping that predates the 2026-10-12 fork and
    # --- would previously have been DESTROYED by any resync run. Both are
    # --- behaviour-identical on MT4: deleting an absent object is a no-op
    # --- there, and is a terminal call here, so the existence probe pays.
    (r'if\(ObjectFind\(0, \w+ \+ "[^"]*"\) >= 0\) ObjectDelete\(0, \w+ \+ "[^"]*"\);',
     "delete guarded by an existence probe (a terminal call MT4 does not pay)",
     "mt5"),
    (r'^\s*ObjectDelete\(0, \w+ \+ "[^"]*"\);\s*$',
     "unguarded delete; MT5 guards it with an existence probe", "mt4"),
    (r'bool objectExists = inCache && cache\.exists;',
     "object-existence from the cache, still re-probed with ObjectFind", "mt5"),
    (r'if\(inCache && cache\.exists && ObjectFind\(0, \w+\[i\]\.name\) < 0\) \{',
     "stale-cache branch; MT4 probes existence in two steps", "mt5"),
    (r'^\s*bool objectExists = false;\s*$',
     "probed separately; MT5 derives it from the cache entry", "mt4"),
    (r'^\s*ObjectSetInteger\(0, \w+, OBJPROP_(FILL|BACK), (true|false)\);\s*$',
     "MT5 guards this property behind a compare (write-only-if-changed)", "mt4"),
    (r'^if\(inpTH3LabelPosition != TH3_LABEL_HIDDEN\)',
     "MT4's single-branch form; MT5 extends it with the changed-text check", "mt4"),
    (r'^\s*objectExists = \(ObjectFind\(0, \w+\[i\]\.name\) >= 0\);\s*$',
     "MT4's existence probe; MT5 answers it from the cache (still re-probed)", "mt4"),
    (r'^\s*if\(inCache && cache\.exists\) \{',
     "MT4's cache-hit branch; MT5 folds it into one cached read", "mt4"),
    (r'^\s*\} else \{',
     "MT4's else branch; MT5 reaches the same states in fewer branches", "mt4"),
    (r'^\s*if\(!objectExists\) \{',
     "MT4's exists/not-exists split; MT5 derives it from the cache", "mt4"),
    (r'^\s*if\(!inCache\) \{',
     "MT5's cache-miss branch (replaces MT4's else)", "mt5"),
    (r'^\s*objectExists = false;\s*$',
     "MT5's re-create path (MT4 reaches it via !objectExists)", "mt5"),
    # --- WRITE-ONLY-IF-CHANGED. The project's own performance law ("never
    # --- write a chart property you would not change") is implemented in MT5 by
    # --- prefixing the write with a compare against the live property. These
    # --- lines are exactly that guard, on the MT5 side.
    (r'^\s*if\(\(?color\)?ObjectGetInteger\(0, \w+, OBJPROP_(COLOR|STYLE|WIDTH|FILL|BACK)\)\s*!=',
     "write-only-if-changed guard (project performance law)", "mt5"),
    (r'^\s*if\(\(int\)ObjectGetInteger\(0, \w+, OBJPROP_(STYLE|WIDTH)\)\s*!=',
     "write-only-if-changed guard (project performance law)", "mt5"),
    (r'ObjectGetString\(0, \w+, OBJPROP_LEVELTEXT, 0\) !=',
     "write-only-if-changed guard (project performance law)", "mt5"),
    (r'^\s*if\(inpTH3LabelPosition != TH3_LABEL_HIDDEN &&',
     "MT4's single-branch form; MT5 extends it with the changed-text check",
     "mt5"),
    # --- MT5-ONLY PLATFORM FILTER (2026-10-13). MT5 fires a chart event for
    # --- every PROGRAMMATIC ObjectCreate/ObjectDelete/ObjectsDeleteAll while
    # --- MT4 fires none; the entries' OnChartEvent consumes a one-shot token
    # --- for those events before dispatch, which restores MT4's semantics
    # --- exactly. The filter removes spurious handler work, it adds no logic.
    (r'^\s*if\(\(id == CHARTEVENT_OBJECT_CREATE \|\| id == CHARTEVENT_OBJECT_DELETE\) &&',
     "MT5 programmatic-object-event filter gate (restore MT4 event semantics)",
     "mt5"),
    (r'^\s*CompatConsumeObjEvent\(id, sparam\)\) return;',
     "MT5 programmatic-object-event filter: drop the tokenized event", "mt5"),
    # --- MT5-ONLY R-TF-UNIT (2026-10-13). On MT4 PERIOD_H1..PERIOD_MN1 ARE
    # --- minutes (60/240/1440/10080/43200); on MT5 they are enum values
    # --- (16385+), so a switch whose INPUT is minutes can never match the
    # --- enum labels here. The literals below are the same table's MT4
    # --- values: same names, same outputs, one scale spelled honestly.
    (r'^\s*case (60|240|1440|10080|43200):\s*return "(H1|H4|D1|W1|MN1|MN)";',
     "R-TF-UNIT: minute literals where MT5's PERIOD_* enums never match minutes", "mt5"),
    (r'^\s*case PERIOD_(H1|H4|D1|W1|MN1):\s*return "(H1|H4|D1|W1|MN1|MN)";',
     "MT4 label spelling of the case lines MT5 writes as minute literals", "mt4"),
    # --- MT5-ONLY P-MT5-SEED-01: iATR answers asynchronously after attach,
    # --- so MT5's first frames have no seed and no jump. This gate DEFERS
    # --- the same first paint (bounded 20 s) until UpdateATRScalingFactor
    # --- seeds; it adds no drawing, only orders it.
    (r'\bseedWait\b|s_seedWaitStartMs',
     "first paint waits for the async ATR seed (MT5 iATR handle)", "mt5"),
    # --- MT5-ONLY P-PERF-106 (2026-10-16): the two cross-reload resolutions
    # --- moved OUT of OnInitHandler into the entries, after the OV_ runtime
    # --- overrides load (inside OnInitHandler the topology fingerprint read
    # --- the 144 seed while the dying instance had written the OV_'s 352, so
    # --- every attach stamped a mismatch and walked the chart). MT4 resolves
    # --- inside its OnInitHandler, so the entry call lines are MT5-only.
    (r'^\s*Resolve(TopologyAdoption|PeriodChangeAttach)\(\);\s*$',
     "the cross-reload resolutions run at the end of OnInit (P-PERF-106)", "mt5"),
]

# mq5 shells use minutes where MQL4 used PERIOD_* constants for the *standard*
# timeframe table; those lines are declared per-line in TIMEFRAME_MINUTES below.
TF_MINUTES = {1: "PERIOD_M1", 5: "PERIOD_M5", 15: "PERIOD_M15", 30: "PERIOD_M30",
              60: "PERIOD_H1", 240: "PERIOD_H4", 1440: "PERIOD_D1",
              10080: "PERIOD_W1", 43200: "PERIOD_MN1"}

# Emphasis: modules that produce what the user sees and counts on.
NUMERIC_MODULES = [
    "ATRCalculations.mqh", "BasePriceManager.mqh", "THCalculations.mqh",
    "AdaptiveScaling.mqh", "ComboEngine.mqh", "LevelPipeline.mqh",
    "LabelFunctions.mqh", "ZoneCalculator.mqh", "ZoneFactory.mqh",
    "ZoneRenderer.mqh", "ZoneValidator.mqh", "TradePlanFormulas.mqh",
    "FractalTimeframes.mqh", "TH3/TH3Math.mqh", "TH3/TH3Renderer.mqh",
    "TH3/TH3Pivots.mqh",
]

GROUPED = ("#preproc", "#decls")     # grouping names, not real symbols

# The MT5 platform layer is the ONLY file MT5 may include and MT4 may not.
PLATFORM_INCLUDES = {"mql5compat.mqh", "mt5objwritefilter.mqh",
                     "mt5leveldump.mqh", "mt5primitiveprobe.mqh"}


# ---------------------------------------------------------------------------
# text handling
# ---------------------------------------------------------------------------
def read(path):
    with io.open(path, "r", encoding="utf-8-sig", newline="") as fh:
        return [l.rstrip("\r\n") for l in fh]


def strip_comment(s):
    out, i, q, n = [], 0, None, len(s)
    while i < n:
        c = s[i]
        if q:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(s[i + 1]); i += 2; continue
            if c == q:
                q = None
            i += 1; continue
        if c in "\"'":
            q = c; out.append(c); i += 1; continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            break
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            j = s.find("*/", i + 2)
            if j < 0:
                break
            i = j + 2; continue
        out.append(c); i += 1
    return "".join(out)


def norm_line(s):
    return re.sub(r"\s+", " ", strip_comment(s)).strip()


def norm_body(body):
    return [t for t in (norm_line(x) for x in body.split("\n")) if t]


def build_ref(path):
    """Flatten an MT4 file: inline every include the MT5 tree lacks as its own file."""
    out, seen = [], set()

    def walk(p, depth=0):
        key = os.path.normcase(p)
        if key in seen or depth > 6:
            return
        seen.add(key)
        for ln in read(p):
            m = INC.match(ln)
            if not m:
                out.append(ln); continue
            target = m.group(1).replace("\\", "/")
            cand = os.path.normpath(os.path.join(os.path.dirname(p), target))
            if not os.path.exists(cand):
                top = os.path.normpath(os.path.join(MT4_REPO, target.lstrip("/")))
                if os.path.exists(top):
                    cand = top
            if not os.path.exists(cand):
                continue
            counter = os.path.normpath(os.path.join(
                MT5_REPO, os.path.relpath(cand, MT4_REPO)))
            if os.path.exists(counter):
                continue                     # a real module: both sides own it
            walk(cand, depth + 1)

    walk(path)
    return out


# ---------------------------------------------------------------------------
# chunking: cut a translation unit into named symbols
# ---------------------------------------------------------------------------
NAME_PATTERNS = [
    re.compile(r'^\s*(?:static\s+)?(?:struct|class|enum|union)\s+(\w+)'),
    re.compile(r'^\s*[\w:<>,~&*\s\[\]]*?\b(\w+)\s*\('),
    re.compile(r'^\s*typedef\b[^;]*?\b(\w+)\s*;'),
]


def pick_name(s):
    for pat in NAME_PATTERNS:
        m = pat.match(s)
        if m:
            return m.group(1)
    return "(block)"


def chunks(lines):
    """Yield (name, body_lines).  Grouping names #preproc / #decls are not symbols."""
    out, i, n = [], 0, len(lines)
    while i < n:
        s = lines[i].strip()
        if not s or s.startswith("//"):
            i += 1; continue
        if s.startswith("#"):
            m = DEFINE.match(s)
            if m:
                body, j = [s], i + 1
                while body[-1].rstrip().endswith("\\") and j < n:
                    body.append(lines[j].strip()); j += 1
                out.append((m.group(1), body)); i = j; continue
            body, j = [], i
            while j < n:
                t = lines[j].strip()
                if not t.startswith("#"):
                    break
                # a #define carrying a value is its own symbol; never swallow it
                # into the architecture run (it carries numbers)
                if j > i and DEFINE.match(t) and not GUARD.match(t):
                    break
                body.append(t); j += 1
            out.append(("#preproc", body)); i = j; continue
        if "(" not in s and "{" not in s and s.rstrip().endswith(";"):
            body, j = [], i
            while j < n:
                t = lines[j].strip()
                if not t or t.startswith("//"):
                    j += 1; continue
                if t.startswith("#") or "(" in t or "{" in t:
                    break
                body.append(t); j += 1
            out.append(("#decls", body)); i = j; continue
        name, depth, body, j = pick_name(s), 0, [], i
        while j < n:
            t = lines[j].strip()
            body.append(t)
            depth += t.count("{") - t.count("}")
            j += 1
            if depth <= 0 and (t.rstrip().endswith(";") or t.rstrip().endswith("}")):
                break
        out.append((name, body)); i = j
    return out


def is_arch(line):
    """Preprocessor architecture (guards/includes) - carries no behaviour.

    A #define that HAS a value is code: it carries constants, i.e. numbers.
    """
    if not line.startswith("#"):
        return False
    if DEFINE.match(line) and not GUARD.match(line):
        return False
    return True


def arch_only_note(a, b, limit=6):
    ca, cb = collections.Counter(a), collections.Counter(b)
    return list((ca - cb).elements())[:limit], list((cb - ca).elements())[:limit]


# ---------------------------------------------------------------------------
# comparison
# ---------------------------------------------------------------------------
def _decl_norm(raw):
    """Normalise a declared-patch line the way norm_body normalises a file line.

    The patch text carries the explanatory trailing comments its author wrote,
    and norm_body strips comments before comparing - so without this the two
    sides never match and a perfectly declared patch reads as drift.
    """
    s = re.sub(r"//.*$", "", raw)
    s = re.sub(r"/\*.*?\*/", "", s)
    return " ".join(s.split())


def _load_declared_patch_lines():
    """Lines that a DECLARED module patch put on one side of the diff.

    resync-module.py's MODULE_PATCHES is the authoritative list of the
    MT5-only blocks this mirror carries (each with a reason). A patch replaces
    MT4 text with MT5 text, so every line it introduces - including the
    structural braces of the block it wraps - is one-sided BY DESIGN and no
    regex in JUSTIFY can name it without becoming broad enough to hide real
    drift. Reading the declarations is exact instead of heuristic: a line is
    justified only if it literally came from a patch we declared.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    # MODULE_PATCHES lives on as pure DATA in the retired generator: it is the
    # machine-readable list of which MT5-only blocks this fork carries and why.
    # The generator itself is retired (2026-10-12 fork) - its --write paths must
    # never run again, because these files are owned, not generated.
    spec = importlib.util.spec_from_file_location(
        "rm", os.path.join(here, "_retired", "resync-module.py"))
    rm = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(rm)
    except Exception:
        return {}
    out = {}
    # The walk uses THIS file's MT4_REPO, not the retired generator's: moving
    # resync-module.py one directory deeper broke its own dirname math, and the
    # checker must not inherit that. MT4_REPO here is absolute and correct.
    mt4_root = MT4_REPO
    for mod, patches in getattr(rm, "MODULE_PATCHES", {}).items():
        introduced, consumed = set(), set()
        # what the patch PUT on the MT5 side
        for _pat, repl, _why in patches:
            for raw in repl.split("\n"):
                s = _decl_norm(raw)
                if s:
                    introduced.add(s)
        # what the patch ATE on the MT4 side: re-run its own pattern against the
        # MT4 source, so the replaced original is recognised as consumed rather
        # than mistaken for logic the mirror lost.
        if mt4_root:
            # Scan EVERY MT4 module. The tree splits a module into parts whose
            # names are not a predictable prefix of the module's (LevelPipeline
            # becomes LevelPipe_A/_B), and the generator INLINES those parts, so
            # a patch can match text that exists in no single MT4 file. Each
            # pattern is module-specific (it names that module's own functions),
            # so scanning the whole tree cannot justify another module's line.
            for base, _dirs, files in os.walk(mt4_root):
                for fn in files:
                    if not fn.endswith(".mqh"):
                        continue
                    with io.open(os.path.join(base, fn),
                                 encoding="utf-8-sig") as fh:
                        text = fh.read().replace("\r\n", "\n")
                    for pat, _repl, _why in patches:
                        for m in pat.finditer(text):
                            for raw in m.group(0).split("\n"):
                                s = _decl_norm(raw)
                                if s:
                                    consumed.add(s)
        out[mod] = {"introduced": introduced, "consumed": consumed}
    return out


DECLARED_PATCH_LINES = _load_declared_patch_lines()

# Names DEFINED by a declared patch (function signatures / definitions, not the
# prose inside them). Read off the replacement text the same way.
_SYMBOL_DEF = re.compile(r"^\s*(?:void|bool|int|double|string|datetime|long|"
                         r"color|uint|static)\b[^;()]*\b([A-Za-z_]\w*)\s*\(")


def declared_symbols(module):
    decl = DECLARED_PATCH_LINES.get(module)
    if not decl:
        return set()
    names = set()
    for line in decl["introduced"]:
        if line.lstrip().startswith("//"):
            continue
        m = _SYMBOL_DEF.match(line)
        if m:
            names.add(m.group(1))
    return names


def justify(line, side, module=None):
    decl = DECLARED_PATCH_LINES.get(module) if module else None
    if decl:
        s = _decl_norm(line)
        if side == "mt5" and s in decl["introduced"]:
            return "declared MT5-only platform patch (resync MODULE_PATCHES)"
        if side == "mt4" and s in decl["consumed"]:
            return "line consumed by a declared platform patch"
    for pat, why, allow in JUSTIFY:
        if allow in ("both", side) and re.search(pat, line):
            return why
    return None


def include_names(path, recurse_parts):
    """Include basenames of a module; recurse into MT4-only parts."""
    out, seen = [], set()

    def walk(p):
        if os.path.normcase(p) in seen:
            return
        seen.add(os.path.normcase(p))
        for ln in read(p):
            m = INC.match(ln)
            if not m:
                continue
            inc = m.group(1).replace("\\", "/")
            cand = os.path.normpath(os.path.join(os.path.dirname(p), inc))
            if not os.path.exists(cand):
                cand = os.path.normpath(os.path.join(MT4_REPO, inc.lstrip("/")))
            base = os.path.basename(inc).lower()
            counter = None
            if os.path.exists(cand):
                rel = os.path.relpath(cand, MT4_REPO)
                cp = os.path.normpath(os.path.join(MT5_REPO, rel))
                counter = cp if os.path.isfile(cp) else None
            if recurse_parts and counter is None and os.path.exists(cand):
                walk(cand)                    # an MT4-only part: its includes count
            else:
                out.append(base)

    walk(path)
    return out


def compare_module(p4, p5):
    """Symbol-level and line-level comparison of one module pair."""
    ref, cur = build_ref(p4), read(p5)
    sym4, sym5 = {}, {}
    for name, body in chunks(ref):
        sym4.setdefault(name, []).extend(norm_body("\n".join(body)))
    for name, body in chunks(cur):
        sym5.setdefault(name, []).extend(norm_body("\n".join(body)))

    code4 = [l for l in norm_body("\n".join(ref)) if not is_arch(l)]
    code5 = [l for l in norm_body("\n".join(cur)) if not is_arch(l)]
    c4, c5 = collections.Counter(code4), collections.Counter(code5)
    only4 = list((c4 - c5).elements())
    only5 = list((c5 - c4).elements())
    mod = os.path.basename(p5)
    bad4 = [(l, None) for l in only4 if not justify(l, "mt4", mod)]
    bad5 = [(l, None) for l in only5 if not justify(l, "mt5", mod)]
    just4 = [l for l in only4 if justify(l, "mt4", mod)]
    just5 = [l for l in only5 if justify(l, "mt5", mod)]

    def owners(one_sided):
        """attribute one-sided lines to the symbols that contain them"""
        hits = collections.Counter()
        for ln in set(one_sided):
            for name, body in (sym4.items() if one_sided is only4 else sym5.items()):
                if ln in body and name not in GROUPED:
                    hits[name] += 1
        return hits

    inc4 = include_names(p4, True)
    inc5 = include_names(p5, False)
    inc4_only = sorted(set(inc4) - set(inc5) - PLATFORM_INCLUDES)
    inc5_only = sorted(set(inc5) - set(inc4) - PLATFORM_INCLUDES)

    return dict(
        ref=ref, cur=cur, sym4=sym4, sym5=sym5,
        inc4_only=inc4_only, inc5_only=inc5_only,
        only4=only4, only5=only5, bad4=bad4, bad5=bad5, just4=just4, just5=just5,
        owners4=owners(only4), owners5=owners(only5),
        arch=(arch_only_note([l for l in norm_body("\n".join(ref)) if is_arch(l)],
                            [l for l in norm_body("\n".join(cur)) if is_arch(l)])),
        sym4_only=sorted(set(sym4) - set(sym5) - set(GROUPED)),
        # A symbol a DECLARED module patch introduced is not "extra logic to
        # remove" - it is the patch. Without this, every MT5-only helper reads
        # as a YELLOW the operator is being told to delete.
        sym5_only=sorted(set(sym5) - set(sym4) - set(GROUPED)
                         - declared_symbols(os.path.basename(p5))),
    )


# ---------------------------------------------------------------------------
def mt5_only_files():
    """Module files that exist ONLY in the MT5 tree - i.e. MT5 extras left."""
    out = []
    for d4, d5, rel in ((MT4_BIOTAK, MT5_BIOTAK, "Biotak"),
                        (os.path.join(MT4_BIOTAK, "TH3"),
                         os.path.join(MT5_BIOTAK, "TH3"), "Biotak/TH3")):
        if not os.path.isdir(d5):
            continue
        for fn in sorted(os.listdir(d5)):
            if not fn.endswith(".mqh"):
                continue
            if not os.path.exists(os.path.join(d4, fn)):
                out.append("%s/%s" % (rel, fn))
    return out


def platform_files():
    """MT5-only files that are the platform layer, not extras."""
    out = []
    d = os.path.join(MT5_REPO, "MT5Compat")
    for fn in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        out.append("MT5Compat/" + fn)
    return out


def modules():
    names = []
    for fn in sorted(os.listdir(MT5_BIOTAK)):
        if fn.endswith(".mqh") and os.path.exists(os.path.join(MT4_BIOTAK, fn)):
            names.append(("Biotak/" + fn,
                          os.path.join(MT4_BIOTAK, fn),
                          os.path.join(MT5_BIOTAK, fn)))
    for sub in ("TH3",):
        d4, d5 = os.path.join(MT4_BIOTAK, sub), os.path.join(MT5_BIOTAK, sub)
        if os.path.isdir(d4) and os.path.isdir(d5):
            for fn in sorted(os.listdir(d5)):
                if fn.endswith(".mqh") and os.path.exists(os.path.join(d4, fn)):
                    names.append(("Biotak/%s/%s" % (sub, fn),
                                  os.path.join(d4, fn), os.path.join(d5, fn)))
    names.append(("ENTRY",
                  os.path.join(MT4_REPO, "Biotak Trigger TH3.mq4"),
                  os.path.join(MT5_REPO, "Biotak Trigger TH3.mq5")))
    names.append(("ENTRY-LITE",
                  os.path.join(MT4_REPO, "Biotak Trigger TH3 Lite.mq4"),
                  os.path.join(MT5_REPO, "Biotak Trigger TH3 Lite.mq5")))
    return names


def head(label):
    print("=" * 78)
    print(label)
    print("=" * 78)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--show-ok", action="store_true")
    args = ap.parse_args()

    rows, all_bad, all_m4only, all_m5only = [], [], [], []
    print("=" * 78)
    print("MODULE BY MODULE:   MT4 (reference)   vs   MT5")
    print("=" * 78)

    for label, p4, p5 in modules():
        if args.only and not any(o in label for o in args.only):
            continue
        r = compare_module(p4, p5)
        nd = len(r["bad4"]) + len(r["bad5"])
        inclusion = bool(r["inc4_only"] or r["inc5_only"])
        verdict = "RED" if (nd or r["sym4_only"] or inclusion) else (
            "YELLOW" if r["sym5_only"] else "GREEN")
        rows.append((label, r, verdict))
        code4 = [l for l in norm_body("\n".join(r["ref"])) if not is_arch(l)]
        code5 = [l for l in norm_body("\n".join(r["cur"])) if not is_arch(l)]
        shared = sum((collections.Counter(code4) &
                      collections.Counter(code5)).values())
        print("%-38s lines mt4=%5d mt5=%5d  shared=%5d  mt4-only=%4d "
              "mt5-only=%4d  BAD=%3d  sym mt4=%3d/mt5=%3d  %s"
              % (label, len(code4), len(code5), shared, len(r["only4"]),
                 len(r["only5"]), len(r["bad4"]) + len(r["bad5"]),
                 len(r["sym4"]), len(r["sym5"]), verdict))
        if inclusion:
            all_bad.append((label, r))
        if r["bad4"] or r["bad5"]:
            all_bad.append((label, r))
        if r["sym4_only"]:
            all_m4only.append((label, r["sym4_only"]))
        if r["sym5_only"]:
            all_m5only.append((label, r["sym5_only"]))
        if not args.quiet:
            if r["inc4_only"]:
                print("      includes MT4 has, MT5 lacks: %s" % ", ".join(r["inc4_only"]))
            if r["inc5_only"]:
                print("      includes MT5 has, MT4 lacks: %s" % ", ".join(r["inc5_only"]))
            if r["bad4"]:
                print("      MT4-only lines with no declared idiom: %d" % len(r["bad4"]))
                for ln, _ in r["bad4"][:12]:
                    print("        - %s" % ln[:104])
            if r["bad5"]:
                print("      MT5-only lines with no declared idiom: %d" % len(r["bad5"]))
                for ln, _ in r["bad5"][:12]:
                    print("        + %s" % ln[:104])
            if r["sym4_only"]:
                print("      MT4-only symbols: %s" % ", ".join(r["sym4_only"][:12]))
            if r["sym5_only"]:
                print("      MT5-only symbols: %s" % ", ".join(r["sym5_only"][:12]))

    head("SUMMARY")
    print("UNJUSTIFIED one-sided lines: %d modules affected"
          % len(all_bad))
    for label, r in all_bad:
        tot = len(r["bad4"]) + len(r["bad5"])
        print("  !! %-38s %3d bad lines   (mt4-only %d, mt5-only %d)"
              % (label, tot, len(r["bad4"]), len(r["bad5"])))
        if r["owners4"] or r["owners5"]:
            print("      symbols: mt4 %s | mt5 %s"
                  % (", ".join(list(r["owners4"])[:6]) or "-",
                     ", ".join(list(r["owners5"])[:6]) or "-"))
    print()
    print("MT4-ONLY SYMBOLS (lost logic): %d" % len(all_m4only))
    for label, names in all_m4only:
        print("   - %s :: %s" % (label, ", ".join(names)))
    print()
    print("MT5-ONLY SYMBOLS (extras to remove): %d" % len(all_m5only))
    for label, names in all_m5only:
        print("   + %-34s %s" % (label, ", ".join(names)))

    extra_files = mt5_only_files()
    print()
    print("MT5-ONLY MODULE FILES (extras left in the build): %d" % len(extra_files))
    for f in extra_files:
        print("   + %s" % f)
    plat = platform_files()
    print("MT5 platform layer (declared, required by MQL5): %s"
          % ", ".join(plat))

    print()
    print("=" * 78)
    print("DO THE NUMBERS MATCH?  modules that draw / compute what the user sees")
    print("=" * 78)
    for label, r, verdict in rows:
        if any(m in label for m in NUMERIC_MODULES):
            print("  %-36s mt4-only lines=%4d mt5-only lines=%4d BAD=%3d   -> %s"
                  % (label, len(r["only4"]), len(r["only5"]),
                     len(r["bad4"]) + len(r["bad5"]), verdict))

    ok = not all_bad and not all_m4only and not extra_files
    print()
    print("VERDICT: %d RED, %d YELLOW, %d GREEN, %d MT5-only files   ->  %s"
          % (len([1 for _, _, v in rows if v == "RED"]),
             len([1 for _, _, v in rows if v == "YELLOW"]),
             len([1 for _, _, v in rows if v == "GREEN"]),
             len(extra_files),
             "IDENTICAL to MT4 modulo declared platform idioms" if ok
             else "WORK REMAINS"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
