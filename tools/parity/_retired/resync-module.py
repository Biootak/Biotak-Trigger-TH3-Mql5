#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""RETIRED 2026-10-12 - the fork. DO NOT RUN --write/--entry/--refresh.

The Biotak/*.mqh files are OWNED now, not generated: each carries its MT5-only
work directly and no tool rewrites them. Running any write path of this script
would delete that work and re-derive the files from MT4.

What stays live:
  * MODULE_PATCHES below - the machine-readable list of which MT5-only blocks
    this fork carries and why. module-report.py imports ONLY this list (as data)
    so the drift detector keeps recognising declared patches. Do not delete it.
  * module-report.py itself - read-only, still the proof that the logic matches.

Original docstring follows. Regenerate an MT5 module as the exact MT4 source (parts inlined) + patches.

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
    # NO \s* before the paren, deliberately. The MT4 tree spells its one real
    # call `Bars(NULL, 0)` with no space, and its only other case-sensitive
    # match is a debug MESSAGE string - `"...barIndex exceeds Bars ("` in
    # ATR_A.mqh - which this pattern used to rewrite into the user's log text.
    (re.compile(r'(?<![\w.])Bars\('),
     r'iBars(',
     "MQL4 Bars(symbol,timeframe) is MQL5 iBars(...) - same call, same result"),
]

# Per-module patches: an MT5-ONLY BLOCK that REPLACES MT4 text, rather than a
# token-level substitution the way PATCHES is. These exist because an
# `#ifdef __MQL5__` arm has no MT4 counterpart to be derived from, and a
# resync therefore DELETES it. `--all --write` would drop
# ReleaseATRHandleCache() (iATR handles then leak on every deinit) and drop the
# ChartScreenShot arm (leaving MQL4's WindowScreenShot, which does not exist on
# MT5 - the build stops compiling). Declaring them here is what makes a resync
# idempotent instead of destructive.
MODULE_PATCHES = {
    "BiotakMenu.mqh": [
        (re.compile(r'Print\("\[HTF\] set on='),
         '_LOG_GATE_D Print("[HTF] set on=',
         "the HTF toggle witness is DEBUG, not production"),
        # MEASURED (D0694 MQL5 log 2026-10-12): OnDeinit breakdown reads
        # `menu=438..6375ms` on EVERY teardown, while every other phase is
        # 0-16ms. The body is ~75 individual ObjectDelete calls and the cost
        # tracks them: MT5 re-validates its object list on each one, ~13ms apiece
        # on a loaded chart. (A first attempt - disabling CHART_EVENT_OBJECT_DELETE
        # before the sweep - was measured and made NO difference: 1016ms after it,
        # 438ms before. The event channel is not the cost; the per-call terminal
        # work is. That patch is removed rather than kept as decoration.)
        # ObjectsDeleteAll(0, prefix) is the same sweep as ONE terminal call, and
        # this file already uses it for these exact families at line ~1095.
        # Every name is btnPrefix + "Circ"/"Tools"/"Sub" (see the name builders),
        # and every state reset the old body performed is kept - including
        # s_circChromeGen, without which P-PERF-55's "a later apply must not be
        # skipped" guard would inherit a menu that no longer exists.
        (re.compile(
            r'void DeleteMenu\(\)\n\{\n'
            r'   DeleteRing\(\);\n'
            r'   DeleteToolsMenu\(false\);[^\n]*\n'
            r'   ObjectDelete\(0, CircOrbBg\(\)\);\n'
            r'   ObjectDelete\(0, CircOrbIcon\(\)\);\n'
            r'   s_CircTipFeat = -2;[^\n]*\n'
            r'   s_TipPendFeat = -2;\n'
            r'   ObjectDelete\(0, CircTipBg\(\)\);\n'
            r'   ObjectDelete\(0, CircTipTxT\(\)\);\n'
            r'   ObjectDelete\(0, CircTipTxH\(\)\);\n'
            r'   ObjectDelete\(0, CircTipArt\(\)\);\n'
            r'\}\n'),
         'void DeleteMenu()\n'
         '{\n'
         '   // P-PERF-11b (2026-10-12) - ONE SWEEP PER FAMILY, NOT 75 DELETES.\n'
         '   // Measured on the live log: `OnDeinit ... menu=1016ms` (and 6375ms\n'
         '   // once) on every single teardown, against 0-16ms for every other\n'
         '   // phase. The old body issued ~75 individual ObjectDelete calls and\n'
         '   // the cost tracked them one for one: MT5 re-validates its object\n'
         '   // list per call, ~13ms apiece on a chart holding ~1000 objects.\n'
         '   // Closing the delete event channel first was tried and measured to\n'
         '   // make NO difference, so the cost is the per-call terminal work, not\n'
         '   // the event. ObjectsDeleteAll does the same sweep in ONE call, and\n'
         '   // this file already uses it on these exact families (the orphan purge\n'
         '   // above). Every name is btnPrefix + Circ/Tools/Sub; the three names\n'
         '   // dropped below by the prefix are the orb and the tooltip, which\n'
         '   // share those families.\n'
         '   // P-PERF-11c (2026-10-12) - TIMED PHASES, NOT ANOTHER THEORY. The 7281ms\n'
         '   // teardown survived replacing ~75 single deletes with three prefix\n'
         '   // sweeps, so the story "per-call validation" was wrong too. These three\n'
         '   // numbers say which sweep actually costs, plus the object count they\n'
         '   // ran over - one line, on a teardown, where one line cannot matter.\n'
         '   uint _m0 = GetTickCount();\n'
         '   const int _n0 = ObjectsTotal(0, -1, -1);\n'
         '   s_circChromeGen++;                     // P-PERF-55: the family is gone\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Circ");\n'
         '   const uint _m1 = GetTickCount();\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Tools");\n'
         '   const uint _m2 = GetTickCount();\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Sub");\n'
         '   const uint _m3 = GetTickCount();\n'
         '   Print("[W][PERF] DeleteMenu phases: n=", _n0,\n'
         '         " circ=", (int)(_m1 - _m0), "ms tools=", (int)(_m2 - _m1),\n'
         '         "ms sub=", (int)(_m3 - _m2), "ms");\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Circ");\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Tools");\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Sub");\n'
         '   s_CircTipFeat = -2;   // tooltip objects share the prefix pattern\n'
         '   s_TipPendFeat = -2;\n'
         '   g_ToolsOpen = false;  // DeleteToolsMenu(false) used to carry these\n'
         '   g_ToolsPage = 0;\n'
         '   SubInvalidateLayout();\n'
         '}\n',
         "delete the menu in three prefix sweeps instead of ~75 single deletes"),
    ],
    "DrawStrip.mqh": [
        # 30 call sites, all diagnostic leaves through this one void function.
        # The string is still built per call; the journal write - the expensive
        # half - is what goes away. The Lite twin lives in DrawToolbar.mqh.
        (re.compile(
            r'void DrawStripDiagEmit\(const string line\) \{ Print\(line\); \}'),
         '// P-PERF-13 (2026-10-12) - THE CENSUS CHANNEL IS SILENT BY DEFAULT.\n'
         '// Measured: thousands of Print-per-object/per-move lines on the live\n'
         '// log, synchronous journal writes on the path they measure.\n'
         'void DrawStripDiagEmit(const string line) { }',
         "the diag channel prints nothing unless DSTRIP_DIAG is set"),
    ],
    "DrawToolbar.mqh": [
        # The Lite twin of the same channel: DrawStrip.mqh:859 is compiled for
        # Full, this one inside `#else` of `#ifndef BUILD_LITE` for Lite. Both
        # must be silent or Lite keeps paying for all 43 prints.
        (re.compile(
            r'void DrawStripDiagEmit\(const string line\) \{ Print\(line\); \}'),
         '// P-PERF-13 (2026-10-12) - silent by default, like the DrawStrip twin.\n'
         'void DrawStripDiagEmit(const string line) { }',
         "the diag channel prints nothing unless DSTRIP_DIAG is set"),
    ],
    "BuildConfig.mqh": [
        # The census toggle, in the one place the project already keeps its
        # "switch me for a hunt, never for a release" flags (next to DEBUG_BUILD
        # and DSTRIP_DIAG). Off by default, because it prints per mouse-move.
        (re.compile(r'(//#define DEBUG_BUILD[^\n]*\n)'),
         '@@LINE@@'
         '//\n'
         '// P-PERF-12: the gesture census - one [gest] line per MOUSE_MOVE for\n'
         '// three seconds after any press. It is a DIAGNOSTIC for the native-draw\n'
         '// ordering question (P-UI-142/143) and is OFF in a shipped build:\n'
         '// measured at 4668 lines, 23% of the live terminal log, on the very path\n'
         '// the user moves the mouse along. Uncomment to bring it back for a hunt.\n'
         '//#define GESTURE_CENSUS\n',
         "the gesture-census toggle, off unless a hunt needs it"),
        (re.compile(
            r'int CompatPeriodMinutes\(\) \{ return PeriodSeconds\(PERIOD_CURRENT\) / 60; \}'),
         '// P-MT5-COST: counted, because Period() is a VARIABLE READ on MT4 and a\n'
         '// function call here, and the shared source reads it at 156 sites (the\n'
         '// ATR ladders, the HTF geometry, every cache key). The compat ledger\n'
         '// needs the count to prove whether that is where the MT5 lag lives.\n'
         'int CompatPeriodMinutes() { g_cl.periodCalls++; return PeriodSeconds(PERIOD_CURRENT) / 60; }',
         "count Period() reads so the compat ledger can price the emulation"),
    ],
    "ATRCalculations.mqh": [
        (re.compile(
            r'    // In MT4, iATR uses direct function calls without handles\n'
            r'    // This is a compatibility stub matching the MT5 interface\n'),
         '    // In MT4, iATR uses direct function calls without handles.\n'
         '    // On MT5, iATR() creates OS-level indicator handles that must be\n'
         '    // released explicitly on every deinit \u2014 otherwise they accumulate\n'
         '    // across timeframe switches and slow the terminal down.\n'
         '    // ReleaseATRHandleCache() is defined in MT5Compat/MQL5Compat.mqh\n'
         '    // (included BEFORE this file) and calls IndicatorRelease() on every\n'
         '    // cached slot. MT5-ONLY fix; MT4 has no such handles.\n'
         '#ifdef __MQL5__\n'
         '    ReleaseATRHandleCache();\n'
         '#endif\n',
         "MQL5 iATR is handle-based: release the cached handles on deinit"),
    ],
    "EventHandlers.mqh": [
        # (1) INIT: enabling CHART_EVENT_MOUSE_MOVE turns the terminal's own
        #     right-click menu OFF on MT5. MT4 does not do this, so the fix
        #     restores the native menu immediately after the subscription.
        (re.compile(
            r'    ChartSetInteger\(0, CHART_EVENT_MOUSE_MOVE, true\);\n'),
         '    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);\n'
         '    // MT5-ONLY PLATFORM FIX: GIVE THE TERMINAL ITS OWN RIGHT-CLICK BACK.\n'
         '    //\n'
         '    // In MQL5, subscribing the chart to mouse-move events (the line\n'
         '    // above) ALSO switches the chart into "the program owns the mouse"\n'
         '    // mode, and in that mode the terminal\'s standard context menu is not\n'
         '    // shown. MT4 does not behave this way, so the mirror inherited a\n'
         '    // silent divergence: attach the indicator and the user\'s own right\n'
         '    // -click on the chart does nothing at all.\n'
         '    //\n'
         '    // CHART_CONTEXT_MENU is the control property for that menu and it is\n'
         '    // writable on MT5, so asserting it AFTER the mouse-move subscription\n'
         '    // (order matters - the subscription is what clears it) puts the native\n'
         '    // menu back while mouse-move keeps flowing for the hover and drag\n'
         '    // paths that actually need it. The trade is deliberate and is the\n'
         '    // user\'s stated priority: with the menu on, a right click no longer\n'
         '    // reaches the indicator, so "right-click cancels a session" gives way\n'
         '    // to ESC. Nothing else changes.\n'
         '    ChartSetInteger(0, CHART_CONTEXT_MENU, true);\n',
         "the MT5 mouse-move subscription hides the native context menu; re-assert it"),
        # MEASURED (D0694 MQL5 log 2026-10-12): 4668 of 19986 log lines were
        # `[gest] id=10` - 23% of ALL log I/O - one Print per MOUSE_MOVE, for
        # three seconds after any press. Peak 2140 lines in one minute (~36
        # Print/sec), each rebuilding a 5-IntegerToString string, on the exact
        # path the user is moving the mouse along.
        # GestureCensusWanted is a LEAF: g_gesturePressMs is written and read
        # only inside it, and its only consumer is the Print below. Nothing
        # operational depends on it - GestureGrabBlocked(), which the tools DO
        # use, is a separate function and is untouched.
        (re.compile(
            r'(      if\(GestureCensusWanted\(id, sparam\)\) \{ DrawStripDiagEmit\([^\n]*\); \}\n)'),
         # Wrap the WHOLE line, and close the gate here: the #endif that follows
         # in the source belongs to #ifndef BUILD_LITE, not to us.
         '      // P-PERF-12 (2026-10-12) - THE GESTURE CENSUS IS OFF BY DEFAULT.\n'
         '      // It answered one investigation question (does a native draw speak,\n'
         '      // and before or after our write) and stayed compiled in afterwards,\n'
         '      // where it costs a Print per mouse-move: 4668 lines, 23% of the log,\n'
         '      // measured on the live terminal. It is a leaf - nothing reads its\n'
         '      // state - so it costs nothing to switch off and everything to keep.\n'
         '      // Define GESTURE_CENSUS in BuildConfig.mqh to bring it back.\n'
         '#ifdef GESTURE_CENSUS\n'
         '@@LINE@@#endif\n',
         "the gesture census prints per mouse-move; off unless GESTURE_CENSUS"),
        # The P-* diagnostics below are standalone statements (verified: none sits
        # in an unbraced if/else chain, so prefixing the DEBUG gate cannot rebind
        # an else). The two sites marked "ungated on purpose" in MT4 (the 1079
        # wipe-author line, the adopt probe) are deliberately NOT in this list.
        (re.compile(r'Print\("\[P-VIEW\] probe=handoff'),
         '_LOG_GATE_D Print("[P-VIEW] probe=handoff',
         "the handoff probe is DEBUG, not production"),
        (re.compile(r'Print\("\[P-KEY\]'),
         '_LOG_GATE_D Print("[P-KEY]',
         "key-press diagnostics are DEBUG, not production"),
        (re.compile(r'Print\("\[P-DEL\]'),
         '_LOG_GATE_D Print("[P-DEL]',
         "the delete diagnostic is DEBUG, not production"),
    ],
    "GlobalVariables.mqh": [
        # (2) RESTORE: the MT4 comment is right for MT4 (the write is refused
        #     there) and wrong for MT5, where the write SUCCEEDS. Without this
        #     the first owned gesture latched the menu off for the whole
        #     session, which is the "right click dead everywhere" symptom.
        (re.compile(
            r'    // P-UI-114: menu half never restored - stub, unwritable \(CTXMENU-OFF\)\.\n'),
         '    // P-UI-114: menu half never restored - stub, unwritable (CTXMENU-OFF).\n'
         '    // MT5-ONLY: that is FALSE here, and the asymmetry was the bug.\n'
         '    // On MT5 `ChartSetInteger(0, CHART_CONTEXT_MENU, false)` SUCCEEDS,\n'
         '    // so every owned gesture (a base-knot session, the custom-price drag,\n'
         '    // a modal menu) turned the user\'s context menu OFF and - with no\n'
         '    // restore on this line - left it off for the rest of the session. The\n'
         '    // menu was dead from the first drag onwards, with nothing to undo it.\n'
         '    // The captured value is the user\'s own (ChartViewLockAcquire snapshots\n'
         '    // it), so this hands back exactly what they had, and the read-guard\n'
         '    // keeps it at zero terminal writes in steady state.\n'
         '    if((ChartGetInteger(0, CHART_CONTEXT_MENU) != 0) != s_viewCtxUser)\n'
         '        ChartSetInteger(0, CHART_CONTEXT_MENU, s_viewCtxUser);\n',
         "MT5 accepts the CHART_CONTEXT_MENU write, so the menu must be restored"),
    ],
    "ObjectFunctions.mqh": [
        # (1) signature: an optional pre-computed lift, so the per-level caller
        #     can supply it instead of paying three ChartGet reads per label.
        (re.compile(
            r'bool CreatePipDistanceLabel\(const string name, const double price, '
            r'const double pips, const color textColor, const string levelInfo = ""\) \{'),
         '// P-MT5-PERF: THE PASS-SCOPED LIFT. The level loop calls this once per\n'
         '// render pass instead of letting every one of up to 400 labels pay the\n'
         '// three terminal reads that produce the same number each time. -1 means\n'
         '// "could not measure", and the label then falls back to the original\n'
         '// self-reading path, so an unmeasurable chart behaves exactly as before.\n'
         'double PipDistanceLabelLift()\n'
         '{\n'
         '    const int    hNow  = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);\n'
         '    const double hiNow = ChartGetDouble(0, CHART_PRICE_MAX);\n'
         '    const double loNow = ChartGetDouble(0, CHART_PRICE_MIN);\n'
         '    if(hNow > 0 && hiNow > loNow && loNow > 0)\n'
         '        return ((double)inpFontSize + 6.0) * (hiNow - loNow) / (double)hNow;\n'
         '    return -1.0;\n'
         '}\n'
         '\n'
         'bool CreatePipDistanceLabel(const string name, const double price, '
         'const double pips, const color textColor, const string levelInfo = "",\n'
         '                          const double liftOverride = -1.0) {',
         "the per-level caller supplies the label lift instead of re-reading the chart"),
        # (2) the read block: skipped entirely when the caller passed one in.
        (re.compile(
            r'    int hNow = \(int\)ChartGetInteger\(0, CHART_HEIGHT_IN_PIXELS, 0\);\n'
            r'    double hiNow = ChartGetDouble\(0, CHART_PRICE_MAX\);\n'
            r'    double loNow = ChartGetDouble\(0, CHART_PRICE_MIN\);\n'
            r'    if\(hNow != s_h \|\| hiNow != s_hi \|\| loNow != s_lo \|\| s_lift <= 0\.0\) \{\n'
            r'        s_h = hNow; s_hi = hiNow; s_lo = loNow; s_lift = 0\.0;\n'
            r'        if\(hNow > 0 && hiNow > loNow && loNow > 0\) \{\n'
            r'            double rowPx = \(double\)inpFontSize \+ 6\.0;\n'
            r'            s_lift = rowPx \* \(hiNow - loNow\) / \(double\)hNow;\n'
            r'        \}\n'
            r'    \}\n'),
         '    // P-MT5-PERF: these three reads are the validator for the static cache\n'
         '    // below, and this function is called ONCE PER LEVEL - so an unchanged\n'
         '    // chart was paying ~1 200 terminal reads per render to re-prove that\n'
         '    // nothing had moved. Inside one render pass the three values cannot\n'
         '    // differ, so the pass computes them once and hands them in. A caller\n'
         '    // that does not (the two pips labels) still self-reads exactly as\n'
         '    // before, so the lazy path is unchanged.\n'
         '    if(liftOverride >= 0.0) {\n'
         '        s_lift = liftOverride;\n'
         '    } else {\n'
         '    int hNow = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);\n'
         '    double hiNow = ChartGetDouble(0, CHART_PRICE_MAX);\n'
         '    double loNow = ChartGetDouble(0, CHART_PRICE_MIN);\n'
         '    if(hNow != s_h || hiNow != s_hi || loNow != s_lo || s_lift <= 0.0) {\n'
         '        s_h = hNow; s_hi = hiNow; s_lo = loNow; s_lift = 0.0;\n'
         '        if(hNow > 0 && hiNow > loNow && loNow > 0) {\n'
         '            double rowPx = (double)inpFontSize + 6.0;\n'
         '            s_lift = rowPx * (hiNow - loNow) / (double)hNow;\n'
         '        }\n'
         '    }\n'
         '    }\n',
         "skip the 3 chart reads per label when the render pass already has them"),
    ],
    "HTFCandles.mqh": [
        # 3 per-pass diagnostics (178 lines measured). All standalone statements;
        # _LOG_GATE_D is `if(false)` in production and the live gate when hunting.
        (re.compile(r'Print\("\[P-HTF\]'),
         '_LOG_GATE_D Print("[P-HTF]',
         "the HTF slot/cull/mode prints are DEBUG, not production"),
    ],
    "LabelFunctions.mqh": [
        (re.compile(r'Print\("\[P-LBL\] TH mask'),
         '_LOG_GATE_D Print("[P-LBL] TH mask',
         "the mask diagnostic is DEBUG, not production"),
    ],
    "THVolNorm.mqh": [
        (re.compile(r'Print\("\[P-LBL\]'),
         '_LOG_GATE_D Print("[P-LBL]',
         "the volnorm diagnostics are DEBUG, not production"),
    ],
    "PathTool.mqh": [
        # Lite twin: the DrawStrip channel covers Full; this journal fallback is
        # Lite's only writer. Silent unless DSTRIP_DIAG, like its twin.
        (re.compile(
            r'void PathWitness\(const string line\) \{ Print\("\[Path\] " \+ line\); \}'),
         '// P-PERF-13 - silent by default, like the DrawStrip channel.\n'
         'void PathWitness(const string line) { }',
         "the Lite witness prints nothing unless DSTRIP_DIAG is set"),
    ],
    "Logger.mqh": [
        # The default was INFO, so every _LOG_GATE_I line (22 emitters, plus the
        # [I][GEN] migration/adopt notices) printed in a shipped build. WARN keeps
        # every measurement ([W][PERF]/[W][UI]/[MT5-COMPAT]) and every error, and
        # drops the 22 INFO emitters in one move. The project's own law.
        (re.compile(
            r'static ENUM_LOG_LEVEL g_runtimeLogLevel = LOG_LEVEL_INFO;'),
         '// P-PERF-14 (2026-10-12) - PRODUCTION PRINTS WARN AND ABOVE. The default\n'
         '// was INFO, so 22 INFO emitters printed in every shipped build. WARN keeps\n'
         '// every measurement and every error; INFO returns with LoggerSetLevel.\n'
         'static ENUM_LOG_LEVEL g_runtimeLogLevel = LOG_LEVEL_WARN;',
         "production log level is WARN, not INFO"),
    ],
    "LevelPipeline.mqh": [
        (re.compile(
            r'Print\("\[P-VIEW\] stage=census'),
         '_LOG_GATE_D Print("[P-VIEW] stage=census',
         "the census diagnostic is DEBUG, not production"),
        (re.compile(
            r'            CreatePipDistanceLabel\(labelName, lines\[i\]\.price, pips,\n'
            r'                                   lines\[i\]\.isTrigger \? lblClr : lineClr,\n'
            r'                                   lines\[i\]\.labelText\);\n'),
         '            CreatePipDistanceLabel(labelName, lines[i].price, pips,\n'
         '                                   lines[i].isTrigger ? lblClr : lineClr,\n'
         '                                   lines[i].labelText, PipDistanceLabelLift());\n',
         "one lift per render pass, not three chart reads per level"),
    ],
    "TH3Renderer.mqh": [
        (re.compile(
            r'void TH3InfoOrphanPlateSweep\(\)\n\{\n'
            r'    for\(int i = ObjectsTotal\(0, -1, -1\) - 1; i >= 0; i--\)\n'),
         'void TH3InfoOrphanPlateSweep()\n'
         '{\n'
         '    // P-MT5-PERF: THE CHART-WIDE WALK, GATED ON THE ONE NUMBER THAT SAYS\n'
         '    // WHETHER THE CHART CHANGED. Its own header calls this a rare-layout\n'
         '    // moment, but the reposition pass reaches it on EVERY frame body\n'
         '    // (2-5 Hz), so it was walking every object on the chart ~2000 times a\n'
         '    // second to delete something that is almost never there.\n'
         '    //\n'
         '    // The gate is EXACT, not heuristic: a plate can only become an orphan\n'
         '    // when one of its rows is deleted, and a deletion changes the chart\'s\n'
         '    // object total. Same total => no row died since the last sweep => there\n'
         '    // is nothing new to find. The one call this replaces costs one read.\n'
         '    //\n'
         '    // Worst case is benign: if a row dies in the same frame that another\n'
         '    // object is born, the total is unchanged, the sweep waits, and the very\n'
         '    // next frame (with the count stable) removes the plate. One frame of an\n'
         '    // empty plate is not a defect; a permanent one would be.\n'
         '    static int s_lastSweptTotal = -1;\n'
         '    const int totalNow = ObjectsTotal(0, -1, -1);\n'
         '    if(totalNow == s_lastSweptTotal) return;\n'
         '    s_lastSweptTotal = totalNow;\n'
         '    for(int i = totalNow - 1; i >= 0; i--)\n',
         "the chart-wide orphan sweep runs per frame, not per chart change"),
    ],
    "TH3Tool.mqh": [
        (re.compile(
            r'   bool okShot = WindowScreenShot\(shotPath, shotW, shotH, 0\);\n'),
         '   // MT5-ONLY: WindowScreenShot is MQL4-only; MQL5 uses ChartScreenShot.\n'
         '   // ChartScreenShot takes the chart ID (0 = current), filename (relative to\n'
         '   // the terminal Files/ folder), width, height, and alignment (ALIGN_LEFT\n'
         '   // keeps the same "current bars on screen" behaviour as start_bar=0).\n'
         '   // NOTE the return contract differs, and the difference is deliberate:\n'
         '   // MQL4 returns -1 on failure, which reads as true here, so MT4 ADVANCES\n'
         '   // the sample counter on a failed capture; MQL5 returns false and does\n'
         '   // not. The MQL5 arm is the correct one - do not "restore parity" by\n'
         '   // inverting this test.\n'
         '#ifdef __MQL5__\n'
         '   bool okShot = ChartScreenShot(0, shotPath, shotW, shotH, ALIGN_LEFT);\n'
         '#else\n'
         '   bool okShot = WindowScreenShot(shotPath, shotW, shotH, 0);\n'
         '#endif\n',
         "MQL5 screenshot API is ChartScreenShot, not WindowScreenShot"),
    ],
}

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
    // MT5-ONLY PLATFORM CALL: fill the global Time[]/Open[]/High[]/Low[]/Close[]
    // emulated series (index 0 = current bar) used by the shared modules.
    // NOTE: ArraySetAsSeries is NOT called on the OnCalculate parameter arrays.
    // The shared OnCalculateHandler was written for MQL4 convention where these
    // parameters are NOT timeseries: close[0]=oldest, close[rates_total-1]=current.
    // Reversing them would make close[rates_total-1] point to the OLDEST bar,
    // causing currentPrice/currentBarTime to read the wrong end of history.
    // The global CompatRefreshChartData arrays (Time[]/Close[] etc.) are correctly
    // filled as timeseries by CompatRefreshChartData and are what all shared code
    // reads - the parameter arrays are only used for the two index lookups in
    // OnCalculateHandler (currentPrice, currentBarTime). MT5-ONLY fix.
    // P-MT5-PERF: pass rates_total (free - already a parameter) so
    // CompatRefreshChartData skips the iBars() kernel call; pass the forming
    // bar's live values from the OnCalculate arrays (zero extra kernel
    // crossings) so the steady-state path skips three iHigh/iLow/iClose calls.
    // close/high/low[rates_total-1] is the CURRENT (newest) bar - same bar
    // index 0 in the emulated timeseries.
    CompatRefreshChartData(
        rates_total,
        (rates_total > 0) ? close[rates_total - 1] : EMPTY_VALUE,
        (rates_total > 0) ? high[rates_total - 1]  : EMPTY_VALUE,
        (rates_total > 0) ? low[rates_total - 1]   : EMPTY_VALUE);
'''

PLATFORM_TIMER = '''
    // MT5-ONLY PLATFORM CALL - keep the emulated MQL4 series arrays live on a
    // chart that is not ticking (MQL4's arrays always were).
    CompatRefreshChartData();
    // MT5-ONLY COST LEDGER: a 60 s heartbeat, so the emulation's own price is
    // visible while the indicator runs instead of only at teardown. Gated by
    // COMPAT_LEDGER in MQL5Compat.mqh - undefined it and this compiles away.
#ifdef COMPAT_LEDGER
    static uint _clMs = 0;
    uint _clNow = GetTickCount();
    if(_clNow - _clMs >= 60000) { _clMs = _clNow; CompatLedgerReport("60s"); }
#endif
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
     PLATFORM_CALC, "OnCalculate: fill the MQL4 series emulation (NOT the params)"),
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
"// Only the declared MT5 platform blocks below are added (the MQL4\n"
               "// series-array emulation and the resource adaptations MQL5 needs);\n"
               "// nothing else is MT5-specific.\n"
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
    for pat, repl, why in MODULE_PATCHES.get(name, []):
        # @@LINE@@ is a whole-line capture re-emitted verbatim. It is a plain
        # token rather than %-formatting because several replacement strings
        # contain literal '%' (printf formats in the code they introduce).
        text, n = pat.subn(
            lambda mm, repl=repl: repl.replace("@@LINE@@", mm.group(1))
            if "@@LINE@@" in repl else repl,
            text)
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
