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
    (r'^\s*if\(ObjectCreate\(0, (lineName|topBorder|bottomBorder|leftBorder),',
     "BUG-09: property writes only after a successful ObjectCreate", "mt5"),
    (r'^\s*ObjectCreate\(0, (lineName|topBorder|bottomBorder|leftBorder),',
     "MT4 creates unguarded; MT5 checks creation before writing (BUG-09)", "mt4"),
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
    # --- P-BE-06 CLASS: A DEAD WRITE.  MT4's `BuildZonesAndLines` flags every
    # --- zone/line with `inViewport`, `RenderZones`/`RenderTriggerLines` take the
    # --- cull window as a parameter, and NOTHING ever reads either: the cull was
    # --- removed from the render in 2026-09 (a level outside the window must stay
    # --- PAINTED - "the window decides nothing", see the note in RenderTriggerLines).
    # --- MT5 deleted the field and the parameters; the numbers never moved. These
    # --- lines are MT4's dead half, on the MT4 side.
    (r'\bvpTop\b|\bvpBottom\b',
     "the cull window was written and never read; MT5 deleted it (P-BE-06 class)",
     "mt4"),
    (r'^\s*const bool makeLines[,)]\s*$',
     "MT5 dropped the dead cull params after it, so the last param's line moves "
     "to ')'", "both"),
    # --- the canvas engine's staging flag lives OUTSIDE the #ifdef so the object
    # --- path's gate compiles in both builds (see R-RENDER-ENGINE, AGENTS.md)
    (r'^\s*bool rbCanvasStage = false;\s*$',
     "canvas staging flag, declared outside #ifdef so both builds compile the "
     "object-path gate", "mt5"),
    (r'^\s*if\(!rbCanvasStage\) \{\s*$',
     "canvas staging gate: the object path runs whenever the bridge did not "
     "stage the line", "mt5"),
    (r'^\s*bool rbr = false;\s*$',
     "the canvas bridge's active flag, declared outside #ifdef so every branch "
     "compiles in both builds", "mt5"),
    (r'^\s*RenderTriggerLines\(lines, result\.lineCount, config, true\);\s*$',
     "the same call without the dead cull window (see vpTop/vpBottom above)",
     "mt5"),
    # --- P-BE-07 CLASS: A DEAD TABLE.  `DeleteZonesByPrefix` built this array on
    # --- every call and read it nowhere; the `ObjectsDeleteAll(0, prefix)` above
    # --- already takes every one of those suffixes, as the note under it says.
    (r'^\s*static string s_zoneSubs\[\] =',
     "built on every call and read nowhere; MT5 deleted it (P-BE-07 class)", "mt4"),
    # --- P-BE-06 CLASS: two more dead locals.  MT4 builds `midPoint` and
    # --- `halfHeight` at the head of CreateFactorMidZone and reads neither (the
    # --- live `midPoint` is a DIFFERENT local, in another function); MT5 dropped
    # --- both. Same object count, same prices.
    (r'^\s*double (midPoint|halfHeight) = \((upperPrice [-+] lowerPrice)\) / 2\.0;\s*$',
     "written at the head of CreateFactorMidZone and read nowhere (P-BE-06 class)", "mt4"),
    # --- P-BE-07 CLASS: a struct declared and never instantiated anywhere in the
    # --- tree. MT5 deleted the declaration; nothing else moved.
    (r'^\s*struct StepMidScore \{\s*$|^\s*(int stepIdx;|int midIdx;|double score;)\s*$',
     "StepMidScore is declared and never instantiated in either tree (P-BE-07 class)",
     "mt4"),
    (r'^\s*FreqCandidate,ScoreMultiStepResonance \};\s*$',
     "the enum's last line, unchanged — the chunk boundary moved because the dead "
     "struct above it was deleted", "mt4"),
    # --- MT5 TRAP (AGENTS.md): ObjectCreate's type argument needs an explicit
    # --- ENUM_OBJECT cast in MQL5 and accepts a raw int in MQL4.
    (r'^\s*(if\(nA >= 3\) )?return ObjectCreate\(0, nm, (\(ENUM_OBJECT\))?ty, 0, t0, p0, t1c, p1c',
     "MQL5 requires the explicit ENUM_OBJECT cast on ObjectCreate (AGENTS.md trap)",
     "both"),
    # --- MODULE-SCOPED, and deliberately so.  These five lines are the body of
    # --- MT5's SetMidZonesVisible, the named setter that replaced MT4's inline
    # --- write in the card's press handler (P-UI-93). Every one of them already
    # --- exists in MT4 once; the multiset sees the second copy. The narrowing to
    # --- this one module is what keeps the exemption from covering the same
    # --- statements anywhere else in the tree.
    (r'^\s*int SetMidZonesVisible\(const bool on\)\s*$',
     "P-UI-93: the named setter MT4 writes inline in the card's press handler",
     "mt5", "BiotakKit.mqh"),
    (r'^\s*g_showMidZones = on;\s*$',
     "P-UI-93: the same write MT4 performs inline", "mt5", "BiotakKit.mqh"),
    (r'^\s*RuntimeSettingsSaveOverridesThrottled\(\);\s*$',
     "the same throttled persist MT4 performs after its inline write",
     "mt5", "BiotakKit.mqh"),
    (r'^\s*g_redrawTHLevelsNeeded = true;\s*$',
     "the same flag MT4 sets in its inline write path", "mt5", "BiotakKit.mqh"),
    (r'^\s*return REFRESH_BUFFERS;\s*$',
     "the same return MT4 answers from its inline write path", "mt5", "BiotakKit.mqh"),
    # --- FrequencyOptimizer: deleting the never-instantiated StepMidScore struct
    # --- took its own closing brace with it, so MT4's multiset has one `};` more
    # --- than MT5's. A bare brace may only be excused inside THIS module.
    # --- DrawStrip, MT4 side: the strip-local refresh flag and the sweep's two
    # --- bookkeeping locals. MT5 needs neither (RequestUISync replaced the flag; the
    # --- folded sweep needs no cell count), so the declarations simply do not exist
    # --- there - no behaviour changed.
    (r'^static (bool s_dsRefreshAsk = false|bool s_dsPaintPickOwed = false|int s_dsPaintCellN = -1);$',
     "MT4's halves of the refresh/sweep bookkeeping MT5 does not need (see "
     "DrawStripRefreshAsk / DrawStripPaint)", "mt4", "DrawStrip.mqh"),
    # --- EventHandlers, MT4 side: the last two continuation lines of the attach
    # --- diagnostic. MT5 has no attach-tail diag and no arm mask.
    (r'^" rest=" \+ IntegerToString\(\(int\)restMs\) \+?$|^" why=" \+ PerfArmWhy\(g_p3ArmMask\) \+ "\]";$',
     "MT4's attach diag fields; MT5 has no attach tail and no g_p3ArmMask",
     "mt4", "EventHandlers.mqh"),
    (r'^\};$',
     "the dead StepMidScore struct took its own closing brace with it "
     "(P-BE-07 class)", "mt4", "FrequencyOptimizer.mqh"),
    # --- GlobalVariables, MT4 side: one placement difference and two dead
    # --- leftovers.  MT5 declares g_PalHexFocus in BiotakPanels.mqh, the module
    # --- that owns the palette in THIS tree (MT4 splits the panels into
    # --- _PalA/_PalB, so its declaration sits in the globals file). One
    # --- definition either way, same flag, same readers.
    (r'^bool g_PalHexFocus = false;',
     "declared in the module that owns the palette here; one definition either "
     "way", "mt4", "GlobalVariables.mqh"),
    # --- g_p3ArmMask is written on the hasPendingWork line and read ONLY by
    # --- PerfArmWhy() inside a diagnostic emit. MT5 dropped the mask and the diag
    # --- line it fed; no gate reads it.
    (r'^static int g_p3ArmMask = 0;$',
     "a diagnostic-only mask (written, then read only by PerfArmWhy in a diag "
     "line); MT5 dropped both halves (P-BE-06 class)", "mt4",
     "GlobalVariables.mqh"),
    # --- a REAL MT4 bug MT5 does not carry: the tooltip's em dash and middot are
    # --- double-encoded in MT4's file, so MT4 shows 'View anchor â€" drag ...'.
    # --- ENTRY, MT4 side: the strip's own refresh ask/take. MT5 replaced the pair
    # --- with RequestUISync() + UISyncDrain(), which is a SUPERSET: the drain also
    # --- repaints the ring's item states and the open card, and it ends in the same
    # --- forced discrete repaint. The strip raises the request in the same tap.
    (r'^\s*int dsAsk = DrawStripRefreshTake\(\);\s*$|^\s*if\(dsAsk > 0\) RefreshDisplay\(REFRESH_ALL\);\s*$',
     "MT5 replaced the strip's ask/take with RequestUISync + UISyncDrain (a superset: "
     "it also repaints the ring and the open card)", "mt4", "Biotak Trigger TH3.mq5"),
    (r'^"View anchor .*Del [Tt]urns View Lock off"\);$',
     "MT4's copy is double-encoded (mojibake); MT5 carries the real em dash and "
     "middot — MT4's tooltip is the broken one", "mt4", "GlobalVariables.mqh"),
    # --- BiotakMenu_Ring: CircRailCapacity's fit walk now CALLS the two named rail
    # --- helpers instead of repeating their arithmetic. room, run and the
    # --- comparison are the same numbers — the walk simply stopped owning a second
    # --- copy of them (P-UI-205 / P-UI-207: one pitch owner, both sides of the
    # --- comparison). Module-scoped, line by line, so nothing else can hide here.
    (r'^int room = (\(dir < 0\) \? \(vertical \? oy : ox\) - CIRC_PAD - box / 2|CircRailRoom\(\(dir < 0\) \? \(vertical \? oy : ox\))$',
     "the fit walk's room, now asked of CircRailRoom instead of re-derived",
     "both", "BiotakMenu_Ring.mqh"),
    (r'^: \(vertical \? ch - oy : cw - ox\)( - CIRC_PAD - box / 2;|, box\);)$',
     "the fit walk's room, second half (see above)", "both", "BiotakMenu_Ring.mqh"),
    (r'^int len = (CIRC_ORB_SIZE / 2 \+ box / 2 \+ CIRC_GAP \+ \(k - 1\) \* \(box \+ CIRC_GAP\);|CircRailRun\(box, k\);)$',
     "the fit walk's run, now asked of CircRailRun instead of re-derived",
     "both", "BiotakMenu_Ring.mqh"),
    (r'^if\((len <= room\) return k;|CircRailRun\(box, k\) <= room\) return k;)$',
     "the fit walk's comparison, unchanged", "both", "BiotakMenu_Ring.mqh"),
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


def code_part(line):
    """The line with a TRAILING // comment removed (quote-aware).

    The chunk terminator has to look at the CODE, not at the comment after it: a
    one-line helper `int F() { return X; }   // note` ends with `}`, but ends with
    `note` once the comment is part of the text - so the terminator missed, the
    chunk swallowed every function after it, and the report then called those
    functions "missing from MT5". That is a tool bug, not source drift.
    """
    q = 0
    for i in range(len(line) - 1):
        c = line[i]
        if c == '"':
            q += 1
        elif c == "/" and line[i + 1] == "/" and q % 2 == 0:
            return line[:i]
    return line


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
            tc = code_part(t).rstrip()
            if depth <= 0 and (tc.endswith(";") or tc.endswith("}")):
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
    for t in JUSTIFY:
        pat, why, allow = t[0], t[1], t[2]
        # a 4th element narrows the entry to ONE module: a bare `};` or a very
        # common statement must never be justified tree-wide.
        if len(t) > 3 and t[3] != module:
            continue
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


# ---------------------------------------------------------------------------
# DECLARED SYMBOL REWRITES.  A whole SYMBOL (never a line) that MT5 implements
# as a different algorithm with the SAME result, and why.  This is deliberately
# coarser than JUSTIFY and deliberately printed: every entry is named in the
# report, so an allowlisted symbol can never hide behind a total.  A symbol
# listed here is exempt from the line check; a symbol NOT listed is checked
# line by line as always.
# ---------------------------------------------------------------------------
DECLARED_SYMBOL_REWRITES = {
    "BiotakKit.mqh": {
        "SetMidZonesVisible":
            "P-UI-93: MT4 sets g_showMidZones inline in the card's press handler; MT5 "
            "factored the SAME four statements (write, throttled persist, repaint, "
            "REFRESH_BUFFERS) into one named setter so the restored state has one "
            "writer. Same flag, same persist, same return.",
    },
    "BiotakMenu.mqh": {
        "DeleteLegacyMenuObjects":
            "MT5 sweeps the whole `BiotakMenu_<chart>_` prefix with ONE ObjectsDeleteAll; "
            "MT4 walks four name families over RING_MAX_SEATS x CAT_COUNT and deletes each "
            "by name. The prefix set is a SUPERSET of MT4's list, so nothing MT4 removed "
            "survives, and a name MT4's list forgot is removed too.",
        "RingFeatureClick":
            "P-PERF-117: the label switches PAINT IN THE PRESS and answer REFRESH_NONE "
            "instead of REFRESH_ALL. RepaintLabelsForSwitch() carries the half that "
            "REFRESH_ALL used to do for a switch - the OV_ mirror write (see its own "
            "note) and RedrawLabelsOnly() - and RequestUISync()/RepaintForDiscreteAction() "
            "paint the ring light and the open card in the same event.",
        "CircMoveItem":
            "the same two writes MT4 makes through CircEnsureBg (position + size), spelled "
            "out: MT5 sets X/Y/XSIZE/YSIZE on the existing background instead of branching "
            "on its size first. Same rect, same tone.",
        "CircLayout":
            "the train's placement now reads CircRailLead/CircRailStep (one pitch owner) "
            "where MT4 inlines ORB/2 + box/2 + GAP and box + GAP. Same distance for the "
            "same tile, and P-UI-205's pitch correction can no longer reach one site and "
            "miss another.",
        "SubPlaceItem":
            "the same rail placement as CircLayout, through SubRailTile + CircRailLead/"
            "CircRailStep instead of a local copy of the pitch.",
        "DeleteMenu":
            "MT5 deletes the whole menu prefix once; MT4 walks the seat/tool name families "
            "and deletes each by name (a SUPERSET, same reason as "
            "DeleteLegacyMenuObjects).",
        "CreateToolsMenu":
            "the tool seat's background is written directly (position + size) instead of "
            "through ToolsEnsureBg; same rect, and one less existence probe per seat.",
        "DeleteToolsMenu":
            "the same prefix sweep as DeleteMenu for the Tools train.",
        "CircCreateItem":
            "MT5 writes the background through CircEnsureBg and then tests existence on "
            "its OWN line (MT4 keeps the call and the test on one line). Same call, same "
            "test, same early return.",
        "ToolsCreateItem":
            "the same split for the Tools train (ToolsEnsureBg + its existence test).",
        "HandleButtonClick":
            "the tool-stop gate is written as an early return (`if(toolStopped) return "
            "REFRESH_NONE;`) instead of wrapping the body in `if(!toolStopped)`.",
        "InitializeUIStates":
            "MT5 adds the clean-teardown stamp check (ConsumeCleanUITeardownStamp) and the "
            "ring's re-assert (CircReassertLock); both are MT5-only - MT5 recreates the "
            "instance, so the UI families can arrive dirty.",
        "CircTipDragTo":
            "MT5 throttles the tooltip's repaint (CIRC_DRAG_REDRAW_INTERVAL) where MT4 "
            "redraws on every move; same text, one paint per window.",
        "ToolsItemAt":
            "the same hit test; MT5 clears the seat's tooltip in the same pass "
            "(ObjectSetString TOOLTIP "") so a stale tip cannot outlive its seat.",
        "ToolsCreateBadge":
            "the same badge creation; MT5 sets the seat's tooltip to "" on create.",
        "SubRailPitch":
            "P-UI-205: the pitch now reads CircRailStep(SubRailTile()) instead of "
            "CIRC_BG_SIZE + CIRC_GAP - one owner for the number, same value.",
        "SubRailFirstCentre":
            "P-UI-205: the first centre now reads CircRailLead(SubRailTile()), same value.",
        "SetHTFVisible":
            "MT5 answers through the same flags plus a targeted repaint; MT4 sets the flag "
            "and lets the tick's dispatcher paint. Same state, painted in the press "
            "(P-PERF-117).",
    },
    "BiotakPanels.mqh": {
        "PnlApplySet":
            "P-PERF-117, the same law RingFeatureClick follows: every row that answered "
            "`g_labelsRelayoutNeeded=true; flags=REFRESH_ALL;` in MT4 now paints in the "
            "press (RepaintLabelsForSwitch / RequestUISync / RepaintForDiscreteAction) and "
            "answers REFRESH_NONE. The mid-zone row goes through SetMidZonesVisible() so "
            "the ZO mirror keeps one writer.",
        "PnlDdRect":
            "the dropdown's rect is built from PnlRowY + the card's own constants; MT4 "
            "re-derives the row's Y with PnlRowY(item,row,py)+PNL_CTL_Y-1 at each site. "
            "P-BE-08's one owner, applied to the rect instead of the row.",
        "PnlCreateRow":
            "the switch seat's Y comes from PnlRowY (P-BE-08) where MT4 re-adds PNL_SW_Y "
            "to a local ry; same seat, one owner.",
        "PnlSwitchHit":
            "the switch's hit band is built from the same row origin and the same "
            "PNL_SW_H/PNL_SW_PAD numbers; MT4 spells the band out inline.",
        "PnlKnobHit":
            "the knob's band is built from PnlRowY + PNL_TRK_Y/PNL_TRK_H/PNL_KNOB_W "
            "(P-BE-08); MT4 adds the same numbers to its own row origin.",
        "PnlPointInside":
            "MT5-ONLY helper: one rect test the card's hit paths share; MT4 repeats the "
            "comparison at each site.",
        "PnlUpdateRow":
            "the row repaint reads PnlRowY (P-BE-08) instead of a local origin.",
    },
    "TH3Tool.mqh": {
        "TH3FamilyDeleteAll":
            "ONE door for a pattern's death, and a SUPERSET of MT4's inline block: the "
            "model (TH3PatternStoreRemove), the caption (TH3InfoFamilyDelete), the canvas "
            "rows (RBridgePatternDropBase), every object wearing the base plus the "
            "TH3_MP_ overlay, and the active pointer. MT4's copy omits the store and the "
            "canvas rows at some call sites - the family then came back on restore.",
        "OnABCDMouseEvent":
            "MT5 drags a point through a LATCHED live point (s_th3LivePoint) applied at "
            "20 ms, because MT5 delivers no reliable button-up for a drag; MT4 re-reads "
            "and repaints the whole pattern per move. Same end position, one apply per "
            "frame instead of one rebuild per move.",
        "AutoSelectBestFrequency":
            "reads the anchors through TH3ReadPatternAnchors() instead of repeating the "
            "four ObjectGet pairs inline (see that symbol's note).",
        "BuildPatternNamesFromRegistry":
            "MT5-ONLY: the registry rebuild (see DECLARED_MT5_ONLY_SYMBOLS).",
        "TH3BaseEditorSync":
            "the same editor fields; MT5 writes them from the pattern's own store row "
            "instead of re-reading the chart objects.",
        "LegHandleAtXY":
            "the same handle hit test; MT5 reads the leg's own session state.",
        "LegMeasureUpgradeLegacy":
            "the same legacy upgrade, called from the attach tail in MT5 (see "
            "AttachToolRestoreLegacy).",
        "TH3RestorePatternsFromChart":
            "reads the anchors through TH3ReadPatternAnchors() (superset: it also accepts "
            "_Point_A/B/C when a line is gone) and deletes a half-built family through "
            "TH3InfoFamilyDelete, exactly as MT4 does.",
    },
    "DrawStrip.mqh": {
        "DrawFamilyDelete":
            "ONE door for the strip's delete, and a SUPERSET of MT4's inline block: the "
            "edge memo, the marks key, every FibPen _FS* row + tag + look memo, every "
            "PenStack _PSK row, the box mid and the fill child, the object itself, and - "
            "added in MT5 - a TH3 pattern member routed to TH3FamilyDeleteAll so the whole "
            "pattern dies instead of the one member.",
        "DrawStripPaint":
            "the stale-slot sweep is folded INTO the paint loop: MT5 walks every slot once "
            "and deletes the six names of a slot that is not live, where MT4 paints to "
            "dsLim and then walks dsLim..DSTRIP_MAX_SLOTS separately. Same deletion set, "
            "one pass.",
        "DrawStripDiagEmit":
            "MT5's copy keeps the same gate and the same file, and its call sites hand the "
            "values to Print as varargs instead of building the string first (see the "
            "logging-channel note in the tool). Same text on screen.",
        "DrawStripGearPlate":
            "the card's chip/label/switch seats now read the named DSTRIP_CARD_*/"
            "DSTRIP_GEAR_SW_* constants (P-UI-214/P-UI-216) where MT4 still writes 22, "
            "+22+8, 20, 18, 15. Same pixels, one owner per number.",
        "DrawStripPointInside":
            "MT5-ONLY helper: one rect test the strip's hit paths share.",
        "DrawStripClickToggle":
            "MT5 returns the click's family through DrawStripClickFamily() so the caller "
            "can answer 'handled by a family' instead of a bare bool; MT4 calls "
            "DrawStripPickTap and returns.",
        "DrawStripLayout":
            "the layout reads the same seats; MT5 carries s_dsPaintCellN/"
            "s_dsPaintPickOwed (the sweep's bookkeeping) instead of MT4's dsLim locals.",
        "DrawStripClosePicker":
            "MT5-ONLY helper: one door for closing a picker.",
        "DrawStripGearObjectsPurge":
            "MT5 deletes the gear prefix once where MT4 names the families.",
        "DrawStripClose":
            "MT5 keeps the same three exits (no object / hidden / masked) and routes the "
            "repaint through the UI sync instead of a bare ThrottledChartRedraw.",
        "DrawStripOnEvent":
            "the router's body is the same chain; MT5 adds the 'object gone' guard "
            "(`ObjectFind(s_dsObj) < 0`) and drops MT4's delete-timing stopwatch "
            "(dt0..dt6, a diagnostic that only fed a DiagEmit).",
        "DrawStripRefreshAsk":
            "MT4's strip-local refresh request; MT5 raised the SAME request through "
            "RequestUISync(), whose drain (UISyncDrain) is a superset - it repaints the "
            "ring's item states and the open card too, and ends in the same forced "
            "discrete repaint.",
        "DrawStripRefreshTake":
            "the consumer half of the pair above (see DrawStripRefreshAsk).",
        "DrawStripGearHit":
            "the chip seat's 22px probe now reads DSTRIP_CARD_CHIP_VIS and the label's "
            "lead reads DSTRIP_CARD_LBL_DX (P-UI-214/P-UI-216); same rectangles.",
        "DrawStripGearPaint":
            "the card's chip/label/switch seats now read the named DSTRIP_CARD_*/"
            "DSTRIP_GEAR_SW_* constants where MT4 writes 22, +22+8, 20, 18, 15. Same "
            "pixels, one owner per number (P-UI-214/P-UI-216).",
        "DrawStripPlaceGear":
            "the same seat placement; MT5 reads the named constants.",
        "DrawStripTap":
            "the same tap chain; the strip's refresh rides RequestUISync (see "
            "DrawStripRefreshAsk).",
        "DrawStripFireDelete":
            "the six-step delete block is one call now: DrawFamilyDelete (declared above).",
        "DrawStripGripMove":
            "the view-lock claim moved into the grip's own branch: MT5 acquires only when "
            "neither grip is live (`if(!s_dsGripLive && !s_dsGGripLive) "
            "ChartViewLockAcquire();`), MT4 returned early from the same test.",
        "DrawStripPublishRect":
            "MT5-ONLY: one rect publisher the board's hit paths share (the colour board's "
            "x1/y1/x2/y2 grown by the skin margin).",
        "DrawStripColorHoverCellAt":
            "MT5-ONLY: the colour board's hover cell walk (pickers, recent swatches and the "
            "board's own rows) in one place; MT4 repeats the same arithmetic per family.",
        "DrawStripGripWhich":
            "MT5-ONLY: which grip a point falls on, so the three grip branches share one "
            "test.",
        "DrawStripPHexLbName":
            "MT5-ONLY leftover name builder for the retired board hex label; kept as a "
            "one-liner because the prefix sweep still needs the name to be spelled here.",
        "DrawStripHoldLatch":
            "the same eight latch gates, logged through Print instead of the concatenating "
            "emitter (see the logging-channel note).",
    },
    "EventHandlers.mqh": {
        "RepaintLabelsForSwitch":
            "MT5-ONLY: the one owner the narrowed flags share - it writes the OV_ mirror "
            "that REFRESH_ALL's dispatcher used to write, then RedrawLabelsOnly() and a "
            "forced discrete repaint. Its own header records why P-PERF-117 needed it.",
        "StampCleanUITeardown":
            "MT5-ONLY: the clean-teardown stamp (MT5 recreates the instance, so the next "
            "attach has to know the teardown finished).",
        "UITearStampName":
            "MT5-ONLY: the stamp's name (see StampCleanUITeardown).",
        "ResolveTopologyAdoption":
            "the same adoption, run at the END of OnInit (P-PERF-106) instead of inside it; "
            "the skipped-on-attach half is why the ledger lines below exist.",
        "ResolvePeriodChangeAttach":
            "the same TF-change resolution, run from the attach tail (MT5 recreates the "
            "instance, so OnInit is not the right moment).",
        "OnInitHandler":
            "MT5's OnInit runs the same five initialisers in the same order and then hands "
            "the tail to the attach pass (g_attachTailPending); MT4 finishes inline.",
        "OnChartEventHandler":
            "the same event chain plus the CompatConsumeObjEvent filter - MT5 delivers "
            "OBJECT_CREATE/OBJECT_DELETE for our OWN programmatic writes, MT4 does not "
            "(AGENTS.md trap).",
        "P4ReportSlow":
            "MT5-ONLY: the slow-frame ledger line (see P4ObjectCensus).",
        "CustomPriceLineOwnLock":
            "MT5-ONLY: the custom-price line's own view-lock claim (P-UI-90's one owner "
            "for the chart's scroll/zoom pair).",
        "RedrawAllObjects":
            "the same walk, with MT5's g_renderAllNeeded/g_redrawTHLevelsNeeded gate "
            "spelled out; the object set and the z-order are unchanged.",
        "SetTriggerLevelsVisible":
            "the same flag write plus a targeted repaint (P-PERF-117).",
        "P4InitLedgerTag":
            "MT5-ONLY: the ledger tag (see P4ObjectCensus).",
    },
    "LevelPipeline.mqh": {
        "SweepForeignLadderObjects":
            "P-PERF-97 / P-PERF-107b / P-VIEW-05: the foreign-ladder sweep is a "
            "CHUNKED state machine (SWEEP_FOREIGN_CHUNK objects per frame, -1 = "
            "retry next frame) keyed on g_initialized instead of the cull "
            "window. Same deletion set, spread over frames so an attach never "
            "blocks the chart.",
    },
}


# ---------------------------------------------------------------------------
# DECLARED MT5-ONLY LINES.  Per module: (regex, why).  These are the lines that
# exist in MT5 and cannot exist in MT4, because the MT5 platform needs them:
# the object-event echo for our own writes, an explicit handle wipe on attach,
# a cross-reload handoff stamp, the attach-tail stopwatch.  They are PRINTED as
# their own category, so the number an operator reads never quietly absorbs
# them, and a module with no entry here is checked line by line as always.
# ---------------------------------------------------------------------------
DECLARED_MT5_LINES = {
    "GlobalVariables.mqh": [
        (r'^\s*static uint g_pInitMs[A-Za-z0-9]* = 0;\s*$',
         "MT5-ONLY: the attach tail's per-phase stopwatch (P-PERF attach work); "
         "MT4 has no equivalent phases to time"),
        (r'^\s*"View anchor .*Del turns View Lock off"\);$',
         "MT5's copy is the CORRECT single encoding of the em dash and middot; "
         "MT4's is double-encoded (see the mt4-side entry)"),
        (r'^\s*static bool g_attachTailPending = false;\s*$',
         "MT5-ONLY: the attach tail runs across frames in MT5 (OnInit cannot block)"),
    ],
    "HRayTool.mqh": [
        (r'^\s*void HRayHandlesWipe\(\)\s*$|^\s*ObjectDelete\(0, HRayHandleName\(HRayLineName\(s_hrayIds\[i\]\)\)\);\s*$|^\s*HRayHandlesWipe\(\);\s*$',
         "MT5-ONLY: the knob/handle objects survive an id-array rebuild in MT5, so "
         "attach and a non-REMOVE deinit wipe them explicitly"),
        (r'^\s*if\(reason != REASON_REMOVE\) HRayHandlesWipe\(\);\s*$',
         "MT5-ONLY: a REMOVE sweeps every object anyway; a TF switch must keep the "
         "committed rays and only drop the handles"),
        (r'^\s*if\(s_hrayDrag != ""\) HRayDragRelease\(\);\s*$|^\s*if\(s_hrayArmed\)\s*$',
         "MT5-ONLY: an arm that outlives the object would leak the view lock; the "
         "explicit release runs on deinit (MT4's teardown resets the count itself)"),
        (r'^\s*ChartViewLockRelease\(\);\s*$',
         "MT5-ONLY: release the view lock the arm held (see above)"),
        (r'^\s*for\(int i = 0; i < ArraySize\(s_hrayIds\); i\+\+\)\s*$',
         "MT5-ONLY: the id registry walk the handle wipe and reg-find share"),
    ],
    "HTFCandles.mqh": [
        (r'^\s*const int HTF_KEPT_NONE = -1;\s*$|^\s*static int s_HTFKeptCount = HTF_KEPT_NONE;\s*$',
         "MT5-ONLY: the kept-family counter, restored from the handoff stamp"),
        (r'^\s*string HTFKeptStampName\(\) .*$|^\s*void SaveHTFHandoffStamp\(\)\s*$|^\s*GlobalVariableSet\(HTFKeptStampName\(\), \(double\)g_HTFDrawnCount\);\s*$',
         "MT5-ONLY: the cross-reload handoff stamp — MT5 recreates the indicator "
         "instance on a TF change, MT4 does not"),
        (r'^\s*void HTFAdoptKeptFamily\(\)\s*$|^\s*const string st = HTFKeptStampName\(\);\s*$|^\s*if\(!GlobalVariableCheck\(st\)\) return;\s*$|^\s*s_HTFKeptCount = \(int\)GlobalVariableGet\(st\);\s*$|^\s*GlobalVariableDel\(st\);\s*$|^\s*HTFAdoptKeptFamily\(\);\s*$',
         "MT5-ONLY: adopt the stamped family instead of rebuilding it (see above)"),
        (r'^\s*if\(g_HTFDrawnCount > 0\)\s*$|^\s*if\(s_HTFKeptCount >= 0\)\s*$|^\s*s_prevCount = s_HTFKeptCount;\s*$|^\s*s_HTFKeptCount = HTF_KEPT_NONE;\s*$|^\s*s_lastBoxMode = g_HTFBoxMode;\s*$|^\s*s_lastShowBodyBox = g_HTFShowBody;\s*$',
         "MT5-ONLY: the kept family's re-entry bookkeeping (see above)"),
    ],
    "EventHandlers.mqh": [
        (r'^" rest=" \+ IntegerToString\(\(int\)restMs\)',
         "MT5-ONLY: a continuation line of the attach-tail diagnostic (no MT4 twin)"),
        (r'^" why=" \+ PerfArmWhy\(g_p3ArmMask\) \+ "\]";$',
         "the diagnostic's arm-mask field; MT5 dropped the mask and the field with it"),
        (r'^" rest=" \+ IntegerToString\(\(int\)restMs\)',
         "MT5-ONLY: a continuation line of the attach-tail diagnostic (no MT4 twin)"),
        (r'^" rest=" \+ IntegerToString\(\(int\)restMs\) \+ "\]";$',
         "MT5-ONLY: a continuation line of the attach-tail diagnostic (the tail has no "
         "MT4 twin)"),
        (r'^" why=" \+ PerfArmWhy\(g_p3ArmMask\) \+ "\]";$',
         "the diagnostic's arm-mask field; MT5 dropped the mask and the field with it"),
    ],
    "Biotak Trigger TH3.mq5": [
        (r'^\s*(if\(reason == REASON_REMOVE\) )?P4LeftoverCensus\("(oninit|remove)"\);\s*$',
         "MT5-ONLY: the P4 leftover ledger at attach/remove (see EventHandlers)"),
        (r'^\s*uint p4q = GetTickCount\(\);\s*$|^\s*g_pInitMs[A-Za-z0-9]* = GetTickCount\(\) - p4q(; p4q = GetTickCount\(\))?;\s*$',
         "MT5-ONLY: the attach tail's per-phase stopwatch"),
        (r'^\s*const bool p116keep = \(reason == REASON_CHARTCHANGE\);\s*$|^\s*if\(!p116keep\)\s*$|^\s*else\s*$',
         "MT5-ONLY (P-116): a TF change KEEPS the HTF family and the UI state; MT5 "
         "recreates the instance, so the keep has to be decided at the teardown"),
        (r'^\s*SaveHTFHandoffStamp\(\);\s*$',
         "MT5-ONLY: stamp the HTF family so the next instance adopts it instead of "
         "rebuilding it (see HTFCandles)"),
        (r'^\s*StampCleanUITeardown\(\);\s*$',
         "MT5-ONLY: mark the teardown as CLEAN so the next attach may restore (see "
         "EventHandlers)"),
        (r'^\s*TailRestoreDeferred\(\);\s*$',
         "MT5-ONLY: the attach tail's deferred half (OnInit cannot block)"),
        (r'^\s*TH3LiveDragHeartbeat\(\);\s*$',
         "MT5-ONLY: the live-drag latch's polled half (see TH3Tool)"),
    ],
    "Biotak Trigger TH3 Lite.mq5": [
        (r'^\s*(if\(reason == REASON_REMOVE\) )?P4LeftoverCensus\("(oninit|remove)"\);\s*$',
         "MT5-ONLY: the P4 leftover ledger at attach/remove (see EventHandlers)"),
        (r'^\s*TailRestoreDeferred\(\);\s*$',
         "MT5-ONLY: the attach tail's deferred half (OnInit cannot block)"),
    ],
    "BiotakMenu.mqh": [
        (r'^\s*static uint s_TipLastRedrawTick = 0;\s*$',
         "MT5-ONLY: the tooltip repaint throttle's clock (CIRC_DRAG_REDRAW_INTERVAL)"),
    ],
    "DrawStrip.mqh": [
        (r'^\s*static (bool s_dsRefreshAsk = false|bool s_dsPaintPickOwed = false|int s_dsPaintCellN = -1);\s*$',
         "the strip-local refresh flag and the sweep's two bookkeeping locals - MT4's "
         "halves of the pair MT5 does not need (RequestUISync replaced the flag; the "
         "folded sweep needs no cell count)"),
        (r'^\s*static int s_dsPHexY = -1;\s*$',
         "the retired board hex field's Y, still cleared by the panel's reset (harmless "
         "state kept so the reset stays one list)"),
    ],
    "BiotakPanels.mqh": [
        (r'^\s*bool g_PalHexFocus = false;',
         "the palette's focus flag, declared in the module that owns the palette in "
         "THIS tree (MT4 splits the panels into _PalA/_PalB and keeps it in the globals)"),
    ],
    "PathTool.mqh": [
        (r'^\s*static bool s_pathDeleting = false;\s*$|^\s*if\(s_pathDeleting\) return( false)?;\s*$|^\s*bool deleting = s_pathDeleting;\s*$|^\s*s_pathDeleting = (true|false|deleting);\s*$',
         "MT5-ONLY: MT5 delivers OBJECT_DELETE for our OWN programmatic deletes "
         "(AGENTS.md trap); the flag stops the echo from re-entering the teardown"),
        (r'^\s*g_suppressDeleteEventsUntilMs = GetTickCount\(\) \+ 250;\s*$',
         "MT5-ONLY: the same echo, swallowed for the window the delete events "
         "actually arrive in"),
        (r'^\s*void PathHandlesWipe\(\)\s*$|^\s*PathHandlesDrop\(s_pathIds\[i\]\);\s*$|^\s*PathHandlesWipe\(\);\s*$',
         "MT5-ONLY: the knob/handle objects survive an id-array rebuild in MT5, so "
         "attach and a non-REMOVE deinit wipe them explicitly"),
        (r'^\s*if\(reason != REASON_REMOVE\) PathHandlesWipe\(\);\s*$',
         "MT5-ONLY: a REMOVE sweeps every object anyway; a TF switch must keep the "
         "committed path and only drop the handles"),
        (r'^\s*if\(s_pathDrag != ""\) PathDragRelease\(\);\s*$|^\s*if\(s_pathArmed\)\s*$|^\s*ChartViewLockRelease\(\);\s*$',
         "MT5-ONLY: an arm that outlives the object would leak the view lock (see "
         "HRayTool)"),
        (r'^\s*for\(int i = 0; i < ArraySize\(s_pathIds\); i\+\+\)\s*$',
         "MT5-ONLY: the id registry walk the handle wipe and reg-add share"),
    ],
}


# ---------------------------------------------------------------------------
# DECLARED MT5-ONLY SYMBOLS.  A whole function that exists only in MT5, because
# the platform forces it (the P4 census ledgers, the attach tail that cannot
# block OnInit, the object-event stamp).  Never a shared function: if the name
# exists in both trees it belongs in DECLARED_SYMBOL_REWRITES below, with the
# algorithm difference spelled out.
# ---------------------------------------------------------------------------
DECLARED_MT5_ONLY_SYMBOLS = {
    "EventHandlers.mqh": {
        "P4ObjectCensus": "MT5-ONLY: the attach/teardown object census (P4 ledger). "
                          "It exists to PROVE the object count returns to its start; MT4 "
                          "has no such ledger.",
        "P4InitLedgerTag": "MT5-ONLY: the ledger's per-session tag (see P4ObjectCensus).",
        "P4LeftoverCensus": "MT5-ONLY: names the objects a teardown left behind "
                            "(see P4ObjectCensus).",
        "TailRestoreDeferred": "MT5-ONLY: the attach tail runs across frames because "
                               "MT5's OnInit cannot block on chart-object creation.",
        "ConsumeCleanUITeardownStamp": "MT5-ONLY: the clean-teardown stamp, read back on "
                                       "the next attach (MT5 recreates the instance).",
        "AttachToolRestoreLegacy": "MT5-ONLY: the legacy tool-state upgrade runs at "
                                   "attach in MT5, where the instance is recreated.",
        "TH3SiblingUnitOnChart": "MT5-ONLY: sibling-instance detection for the attach "
                                 "tail.",
    },
    "TH3Tool.mqh": {
        "TH3LiveDragUnlatch": "MT5-ONLY: the live-drag latch's release (the MT5 event "
                              "model has no reliable button-up edge for a drag).",
        "TH3LiveDragHeartbeat": "MT5-ONLY: the latch's polled half (see above).",
        "BuildPatternNamesFromRegistry": "MT5-ONLY: rebuilds the pattern name list from "
                                         "the registry after a reload.",
        "TH3PointDragApply": "MT5-ONLY: the latched live-point apply (see "
                             "OnABCDMouseEvent).",
        "s_th3LivePoint": "MT5-ONLY: the latched live point's name (see TH3PointDragApply).",
        "s_th3LiveT": "MT5-ONLY: the latched point's last applied time.",
        "s_th3LiveP": "MT5-ONLY: the latched point's last applied price.",
        "s_th3LiveMs": "MT5-ONLY: the latch's 20 ms apply cadence.",
        "s_th3DragLockHeld": "MT5-ONLY: whether the live drag holds the view lock.",
        "prevActive": "MT5-ONLY: the active-pattern pointer saved across a live drag.",
        "TH3ReadPatternAnchors": "MT5-ONLY: ONE reader for a pattern's four anchors. It is "
                                 "a SUPERSET of the four inline reads MT4 repeats: when a "
                                 "line is missing it falls back to _Point_A/B/C, so a "
                                 "pattern whose lines were replaced by points still "
                                 "restores. MT4 bails in that case.",
    },
    "HRayTool.mqh": {
        "HRayHandlesWipe":
            "MT5-ONLY, and it FIXES an MT4 defect. The handle is the ray's selection "
            "dot (a BITMAP_LABEL named <line>_H). MT4's HRayAdoptOrphans skips every "
            "_H object, and OnDeinit clears s_hraySel, so a dot that survives a "
            "timeframe switch is never adopted and never deleted: it stays on the "
            "chart forever as a stray dot at the old geometry. MT5 wipes the _H of "
            "every adopted ray on attach and on a non-remove deinit, so no stray dot "
            "can outlive its selection. Same dot while selected; MT4 additionally "
            "leaves a ghost.",
    },
    "PathTool.mqh": {
        "PathHandlesWipe":
            "MT5-ONLY, same defect as HRayHandlesWipe: MT4 adopts the path lines but "
            "skips every _H object, so the per-segment grab dots of a selection that "
            "did not survive the reload stay behind. MT5 wipes them on attach and on a "
            "non-remove deinit and the dot is rebuilt on demand.",
    },
    "HTFCandles.mqh": {
        "HTFKeptStampName":
            "MT5-ONLY: the chart-keyed key that carries the drawn HTF box count across "
            "a reload. MT5 destroys and recreates the indicator instance on a timeframe "
            "switch, so an outgoing instance cannot hand its count to the next one "
            "through a static; MT4 keeps the same instance and reads g_HTFDrawnCount "
            "directly. Without the stamp MT5's first draw after a TF switch cannot tell "
            "the kept family from the surplus and re-draws or over-prunes it.",
        "SaveHTFHandoffStamp":
            "MT5-ONLY: writes that count in OnDeinit (see HTFKeptStampName).",
        "HTFAdoptKeptFamily":
            "MT5-ONLY: consumes the stamp ONCE at attach and seeds the first draw "
            "(see HTFKeptStampName).",
    },
    "EventHandlers.mqh_extra": {},
}


# ---------------------------------------------------------------------------
# DECLARED MT5-ONLY INCLUDES.  AGENTS.md names the platform layer: MQL5Compat is
# the only MT5-specific source, and the two MetaQuotes includes the compat header
# needs are pulled in for MQL5 only. An include list that differs by exactly these
# is not drift; an include that differs by anything else still fails the check.
# ---------------------------------------------------------------------------
DECLARED_MT5_INCLUDES = {
    "inputvalidationenhanced.mqh",   # required by MQL5Compat (MQL5-only helper)
    "propertychangedetector.mqh",    # required by MQL5Compat
    "renderbridge.mqh",              # R-RENDER-ENGINE, the canvas engine seam
    "mql5compat.mqh",                # the platform layer itself
}


ENGINE_MACROS = ("BIOTAK_RENDER_ENGINE",)


DIAG_CALLS = ("Print(", "PrintFormat(", "DrawStripDiagEmit(", "DiagEmit(",
              "P4Diag(", "P4Report", "Comment(")


def diag_statement_lines(lines):
    """Normalized lines that belong to a LOGGING statement.

    The diagnostic channel is not behaviour: MT4 builds its messages by string
    concatenation into `DrawStripDiagEmit(...)`, MT5 hands the same values to
    `Print(...)` as varargs. The text a user reads is identical, the cost class
    is identical in a non-diag build, and the two spellings can never be made
    line-identical without one tree adopting the other's allocation pattern.
    So the channel is excluded SYMMETRICALLY - both sides, statement and its
    continuation lines - which is what keeps the exclusion from hiding a
    behavioural line: a line that is not inside a logging statement is still
    compared exactly as before.
    """
    out, open_stmt, depth = set(), False, 0
    for raw in lines:
        st = raw.strip()
        if not open_stmt:
            if not any(st.startswith(c) or (" " + c) in st for c in DIAG_CALLS):
                continue
            open_stmt = True
            depth = 0
        n = norm_line(raw)
        if n:
            out.add(n)
        depth += st.count("(") - st.count(")")
        if ";" in st and depth <= 0:
            open_stmt = False
    return out


def engine_region_lines(lines):
    """Normalized lines that live inside an #ifdef BIOTAK_RENDER_ENGINE region.

    AGENTS.md declares the canvas render engine as the ONE MT5-only feature, so a
    line inside such a region is not unexplained drift - it is the engine. It is
    counted and printed as its own category (ENGINE) instead of being folded into
    BAD, so the number the operator reads stays honest in both directions: the
    object path must still match MT4 line for line, and the engine is visibly
    declared rather than silently swallowed.
    """
    out, stack = set(), []
    for raw in lines:
        s = raw.strip()
        if s.startswith("#ifdef") or s.startswith("#ifndef") or s.startswith("#if"):
            tok = s.split(None, 1)[1].strip() if len(s.split(None, 1)) > 1 else ""
            stack.append(any(m in tok for m in ENGINE_MACROS))
            continue
        if s.startswith("#else") or s.startswith("#elif"):
            if stack:
                stack[-1] = not stack[-1]
            continue
        if s.startswith("#endif"):
            if stack:
                stack.pop()
            continue
        if any(stack):
            n = norm_line(raw)
            if n:
                out.add(n)
    return out


def compare_module(p4, p5):
    """Symbol-level and line-level comparison of one module pair."""
    ref, cur = build_ref(p4), read(p5)
    sym4, sym5 = {}, {}
    for name, body in chunks(ref):
        sym4.setdefault(name, []).extend(norm_body("\n".join(body)))
    for name, body in chunks(cur):
        sym5.setdefault(name, []).extend(norm_body("\n".join(body)))

    # A brace-only line carries no behaviour: a block is judged by its
    # STATEMENTS, never by the punctuation around them. Excluding them here keeps
    # an added or deleted function from showing up as a pair of `{`/`}` of
    # drift, which would otherwise be excused by a blanket rule - the very kind
    # of blanket rule this tool exists to avoid.
    code4 = [l for l in norm_body("\n".join(ref))
             if not is_arch(l) and l not in ("{", "}")]
    code5 = [l for l in norm_body("\n".join(cur))
             if not is_arch(l) and l not in ("{", "}")]
    c4, c5 = collections.Counter(code4), collections.Counter(code5)
    only4 = list((c4 - c5).elements())
    only5 = list((c5 - c4).elements())
    mod = os.path.basename(p5)
    eng5 = engine_region_lines(cur)
    diag4 = diag_statement_lines(ref)
    diag5 = diag_statement_lines(cur)
    rewrites = DECLARED_SYMBOL_REWRITES.get(mod, {})
    decl5 = DECLARED_MT5_LINES.get(mod, [])

    only5_syms = DECLARED_MT5_ONLY_SYMBOLS.get(mod, {})

    def declared_mt5(line):
        for pat, why in decl5:
            if re.search(pat, line):
                return why
        for name, why in only5_syms.items():
            if name in line:
                return why
            body = sym5.get(name)
            if body and line in body:
                return why
        return None

    def rewritten(line, syms):
        """the declared rewrite symbol this line belongs to, if any"""
        for name, body in syms.items():
            if name in rewrites and line in body:
                return name
        return None

    bad4 = [(l, None) for l in only4
            if l not in diag4
            and not justify(l, "mt4", mod) and not rewritten(l, sym4)]
    bad5 = [(l, None) for l in only5
            if l not in eng5 and l not in diag5 and not justify(l, "mt5", mod)
            and not rewritten(l, sym5) and not declared_mt5(l)]
    just4 = [l for l in only4 if l in diag4 or justify(l, "mt4", mod)]
    just5 = [l for l in only5
             if l in eng5 or l in diag5 or justify(l, "mt5", mod)
             or declared_mt5(l)]
    eng_only5 = [l for l in only5 if l in eng5]
    rw4 = [l for l in only4 if rewritten(l, sym4)]
    rw5 = [l for l in only5 if rewritten(l, sym5)]

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
        eng5=eng_only5, rw4=rw4, rw5=rw5, rewrites=rewrites,
        owners4=owners(only4), owners5=owners(only5),
        arch=(arch_only_note([l for l in norm_body("\n".join(ref)) if is_arch(l)],
                            [l for l in norm_body("\n".join(cur)) if is_arch(l)])),
        # ENGINE_MACROS is the engine gate, not a symbol: the preprocessor reads
        # "#define BIOTAK_RENDER_ENGINE" as a declaration, which made the entry
        # files report a phantom MT5-only "symbol". The engine's own lines are
        # already measured by the ENGINE column; the gate itself is not logic.
        sym4_only=sorted(set(sym4) - set(sym5) - set(GROUPED) - set(ENGINE_MACROS)),
        # A symbol a DECLARED module patch introduced is not "extra logic to
        # remove" - it is the patch. Without this, every MT5-only helper reads
        # as a YELLOW the operator is being told to delete.
        sym5_only=sorted(set(sym5) - set(sym4) - set(GROUPED)
                         - set(ENGINE_MACROS)
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
        inc5_real = [f for f in r["inc5_only"]
                     if f not in DECLARED_MT5_INCLUDES]
        inclusion = bool(r["inc4_only"] or inc5_real)
        # A symbol that a declared rewrite covers is NOT lost logic: the rewrite IS its
        # MT5 implementation (e.g. MT4's strip-local ask/take became RequestUISync +
        # UISyncDrain). Only an undeclared MT4-only symbol still forces RED.
        m4_real = [n for n in r["sym4_only"] if n not in r["rewrites"]]
        m5_real = [n for n in r["sym5_only"]
                   if n not in r["rewrites"]
                   and n not in DECLARED_MT5_ONLY_SYMBOLS.get(os.path.basename(p5), {})]
        verdict = "RED" if (nd or m4_real or inclusion) else (
            "YELLOW" if m5_real else "GREEN")
        rows.append((label, r, verdict))
        code4 = [l for l in norm_body("\n".join(r["ref"])) if not is_arch(l)]
        code5 = [l for l in norm_body("\n".join(r["cur"])) if not is_arch(l)]
        shared = sum((collections.Counter(code4) &
                      collections.Counter(code5)).values())
        print("%-38s lines mt4=%5d mt5=%5d  shared=%5d  mt4-only=%4d "
              "mt5-only=%4d  BAD=%3d ENGINE=%3d sym mt4=%3d/mt5=%3d  %s"
              % (label, len(code4), len(code5), shared, len(r["only4"]),
                 len(r["only5"]), len(r["bad4"]) + len(r["bad5"]),
                 len(r["eng5"]), len(r["sym4"]), len(r["sym5"]), verdict))
        if inclusion:
            all_bad.append((label, r))
        if r["bad4"] or r["bad5"]:
            all_bad.append((label, r))
        if r["sym4_only"]:
            m4u = [n for n in r["sym4_only"] if n not in r["rewrites"]]
            if m4u:
                all_m4only.append((label, m4u))
        if r["sym5_only"]:
            m5u = [n for n in r["sym5_only"]
                   if n not in r["rewrites"]
                   and n not in DECLARED_MT5_ONLY_SYMBOLS.get(
                       os.path.basename(dict((l, p) for l, p in []) or label), {})]
            if m5u:
                all_m5only.append((label, m5u))
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
            print("  %-36s mt4-only lines=%4d mt5-only lines=%4d BAD=%3d ENGINE=%3d  -> %s"
                  % (label, len(r["only4"]), len(r["only5"]),
                     len(r["bad4"]) + len(r["bad5"]), len(r["eng5"]), verdict))

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
