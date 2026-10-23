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
         '   // P-PERF-11d (2026-10-12) - SUPPRESS DELETE EVENTS DURING BULK SWEEPS.\n'
         '   // MT5 fires CHARTEVENT_OBJECT_DELETE for every programmatic delete;\n'
         '   // MT4 does not fire any. The flag is this project\'s own suppression\n'
         '   // pattern (LabelFunctions, EventHandlers, LevelPipeline, ObjectCache).\n'
         '   g_suppressDeleteEvents = true;\n'
         '   uint _m0 = GetTickCount();\n'
         '   const int _n0 = ObjectsTotal(0, -1, -1);\n'
         '   s_circChromeGen++;                     // P-PERF-55: the family is gone\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Circ");\n'
         '   const uint _m1 = GetTickCount();\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Tools");\n'
         '   const uint _m2 = GetTickCount();\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Sub");\n'
         '   const uint _m3 = GetTickCount();\n'
         '   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;\n'
         '   g_suppressDeleteEvents = false;\n'
         '   _LOG_GATE_D Print("[W][PERF] DeleteMenu phases: n=", _n0,\n'
         '         " circ=", (int)(_m1 - _m0), "ms tools=", (int)(_m2 - _m1),\n'
         '         "ms sub=", (int)(_m3 - _m2), "ms");\n'
         '   // second pass: catches any objects the first sweep missed (same guard)\n'
         '   g_suppressDeleteEvents = true;\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Circ");\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Tools");\n'
         '   ObjectsDeleteAll(0, g_UI.btnPrefix + "Sub");\n'
         '   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;\n'
         '   g_suppressDeleteEvents = false;\n'
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
         'void DrawStripDiagEmit(const string line) { }\n'
         '// P-PERF-95: nothing was opened, so nothing is closed — the call site below\n'
         '// stays one line on both builds.\n'
         'void DrawStripDiagClose() { }',
         "the diag channel prints nothing unless DSTRIP_DIAG is set"),
        # P-PERF-95 (BUG-11, 2026-10-13): the census handle is opened once
        # (`static int dh`) and was never closed, so every attach/teardown
        # cycle leaked one file handle until `FileOpen` answered
        # INVALID_HANDLE. MT5-only: MT4's own batch never carried the release.
        # The whole emit is re-emitted with the handle renamed to
        # `s_dsDiagFh` and hoisted to file scope: the close function must see
        # it, and neither the function-static form (unreachable, error 256)
        # nor a plain file-scope `dh` (shadowed by BiotakPanels locals —
        # warning 62) compiles clean.
        (re.compile(
            r'void DrawStripDiagEmit\(const string line\)\n'
            r'\{\n'
            r'   Print\(line\);\n'
            r'   static int dh = INVALID_HANDLE;\n'
            r'   if\(dh == INVALID_HANDLE\)\n'
            r'      dh = FileOpen\("biotak_diag_" \+ Symbol\(\) \+ "_" \+ IntegerToString\(ChartID\(\)\) \+ "\.txt",\n'
            r'                    FILE_WRITE \| FILE_TXT \| FILE_ANSI \| FILE_SHARE_READ\);\n'
            r'   if\(dh == INVALID_HANDLE\) return;\n'
            r'   FileWrite\(dh, line\);\n'
            r'   FileFlush\(dh\);\n'
            r'\}\n#else'),
         '// MT5-ONLY P-PERF-95 (BUG-11): the census handle lives at FILE scope under a\n'
         '// name no shared module uses — the release below must see what the emit\n'
         '// opened, and `dh` cannot be reused there: as a function-static it is\n'
         '// unreachable (error 256), as a file-scope `dh` the shared BiotakPanels\n'
         '// locals shadow it (warning 62).\n'
         'static int s_dsDiagFh = INVALID_HANDLE;\n'
         'void DrawStripDiagEmit(const string line)\n'
         '{\n'
         '   Print(line);\n'
         '   if(s_dsDiagFh == INVALID_HANDLE)\n'
         '      s_dsDiagFh = FileOpen("biotak_diag_" + Symbol() + "_" + IntegerToString(ChartID()) + ".txt",\n'
         '                    FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);\n'
         '   if(s_dsDiagFh == INVALID_HANDLE) return;\n'
         '   FileWrite(s_dsDiagFh, line);\n'
         '   FileFlush(s_dsDiagFh);\n'
         '}\n'
         '// P-PERF-95 (BUG-11, 2026-10-13) — THE HANDLE IS RELEASED WITH THE STRIP.\n'
         '// `s_dsDiagFh` above is opened once and, before this, never closed: every\n'
         '// attach/teardown cycle leaked one file handle until the terminal hit its\n'
         '// per-program limit and `FileOpen` started answering INVALID_HANDLE — the\n'
         '// census would then go silently quiet instead of failing loudly. The owner of\n'
         '// the handle is the strip, so the release lives beside the strip\'s own close.\n'
         'void DrawStripDiagClose()\n'
         '{\n'
         '   if(s_dsDiagFh != INVALID_HANDLE) { FileClose(s_dsDiagFh); s_dsDiagFh = INVALID_HANDLE; }\n'
         '}\n'
         '#else',
         "P-PERF-95 BUG-11: release the census handle with the strip"),
        # P-PERF-DSC1 (2026-10-12) -> P-PERF-100 (2026-10-16). DSC1 armed the
        # suppression flag over the old ~530 single ObjectDelete calls (MT5 fires
        # a CHARTEVENT_OBJECT_DELETE per programmatic delete; MT4 fires none).
        # P-PERF-100 replaced that whole delete block with ONE
        # `ObjectsDeleteAll(0, "PnlDrawS_")` sweep: every name the close owns
        # carries that prefix by construction (faces/icons :1578-1594, grip/
        # badge/bg :1645, separators :5428, the three nine-piece skins :6266-6315,
        # the gear family via DrawStripGearObjectsPurge's own prefix wipe :4628),
        # and DrawStripSweepStale already takes the same family in one call. The
        # suppression flag stays: the sweep still fires one MT5 delete event per
        # removed object. Measured on the live log (2026.10.16 12:31, TF switch):
        # `OnDeinit reason=3 took 1063ms` with `pnl=0 menu=1031 handler=32` and
        # `DeleteMenu phases circ=0 tools=0 sub=0` — the whole second sat here.
        # P-PERF-TMP (2026-10-16): the phase stamps in the replacement below are
        # TEMPORARY attribution probes — they print only when the close clears
        # 100 ms, and they come OUT once the slow-teardown owner is named.
        (re.compile(
            r'void DrawStripClose\(\)\n'
            r'\{\n'
            r'   DrawStripColorHoverClear\(\);.*?\n'
            r'   DrawSelClear\(\);\n'
            r'\}\n',
            re.DOTALL),
         'void DrawStripClose()\n'
         '{\n'
         '   // P-PERF-100 (2026-10-16) - ONE PREFIX SWEEP, NOT ~530 SINGLE DELETES.\n'
         '   uint p101t = GetTickCount();   // P-PERF-TMP (remove after attribution)\n'
         '   g_suppressDeleteEvents = true;\n'
         '   DrawStripColorHoverClear();\n'
         '   uint p101h = GetTickCount();\n'
         '   DrawStripDiagClose();   // P-PERF-95 (BUG-11): the census handle leaves with the strip\n'
         '   uint p101d = GetTickCount();\n'
         '   DrawStripSweepStale();\n'
         '   uint p101s = GetTickCount();\n'
         '   DrawStripGearClose();\n'
         '   uint p101g = GetTickCount();\n'
         '   uint p101k = p101g;   // P-PERF-103: no skin phase left to time\n'
         '   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;\n'
         '   g_suppressDeleteEvents = false;\n'
         '   s_dsOpen = false;\n'
         '   s_dsObj = "";\n'
         '   s_dsKind = DK_NONE;\n'
         '   s_dsN = 0;\n'
         '   DrawStripPublishRect();   // P-DRAW-31: a closed strip occupies no pixels\n'
         '   DrawStripSurfaceClear();  // P-PAL-20: owns no popup pixels either\n'
         '   s_dsPicker = DSTRIP_PICK_NONE;\n'
         '   s_dsPN = 0;\n'
         '   s_dsPHexY = -1;\n'
         '   s_dsPHeadY = -1;\n'
         '   s_dsPOpY = -1;\n'
         '   s_dsOpGrab = false;\n'
         '   s_dsHexFocus = false;\n'
         '   s_dsGearManual = false;\n'
         '   s_dsPinned = false;\n'
         '   DrawStripGripRelease();   // P-UI-113d: a close never leaves the view locked\n'
         '   DrawStripOpenerDisarm();  // P-UI-113c: nor the opener guard armed\n'
         '   DrawStripHoldSelectionDisarm();  // P-UI-113g: no close outlives a selection repair\n'
         '   DrawSelClear();\n'
         '   uint p101e = GetTickCount();   // P-PERF-TMP\n'
         '   if((p101e - p101t) >= 100)\n'
         '      Print("[W][PERF-TMP] stripclose hover=", (int)(p101h - p101t),\n'
         '            " diag=", (int)(p101d - p101h), " sweep=", (int)(p101s - p101d),\n'
         '            " gear=", (int)(p101g - p101s), " skin=", (int)(p101k - p101g),\n'
         '            " tail=", (int)(p101e - p101k), " total=", (int)(p101e - p101t));\n'
         '}\n',
         "P-PERF-100: one prefix sweep instead of ~530 single deletes (live TF-switch teardown)"),
        # P-PERF-101 (2026-10-16) - ONE PREFIX WIPE, NOT ~330 MISSING-NAME PROBES.
        # The fallback chain this replaces probed ~330 names one at a time with
        # ObjectFind; on a chart that holds no gear family at all each probe is a
        # table walk with nothing to find, and the live log priced one such close
        # at `menu=1015ms` with every other phase 16ms - against 20ms for the same
        # teardown beside it, whose guard returned before the chain. Every name the
        # chain could reach starts with "PnlDrawS_G" (new spellings and the retired
        # GT/GU/GTrack set alike - the grip is _H, the badge _B, the popover _P*,
        # no non-gear name collides), so one prefix sweep IS the whole contract.
        (re.compile(
            r'bool DrawStripGearObjectsPurge\(\)\n'
            r'\{\n'
            r'   bool dirty = false;.*?\n'
            r'   return dirty;\n'
            r'\}\n',
            re.DOTALL),
         'bool DrawStripGearObjectsPurge()\n'
         '{\n'
         '   // P-PERF-101 (2026-10-16) - ONE PREFIX WIPE, NOT ~330 MISSING-NAME PROBES.\n'
         '   ObjectsDeleteAll(0, "PnlDrawS_G", -1, -1);\n'
         '   return true;\n'
         '}\n',
         "P-PERF-101: one prefix wipe instead of ~330 missing-name probes"),
        # P-PERF-103 (2026-10-16) - THE SKIN PURGE CALL IS GONE FROM
        # DrawStripClose, so there is nothing left to instrument here. The TMP
        # round that decided it measured d0=0 d1=0 d2=0 on every teardown: the
        # sweep above already took the whole PnlDrawS_ family, and the ~270
        # ObjectFind misses were themselves the 1.0-7.0s. DrawStripSkinPurge()
        # keeps its plain body (it is dead code now, but shared with MT4, and
        # deleting it would buy parity nothing).
        (re.compile(r'    Print\("\[drawstrip\] press named at ", mx, ",", my, " hit=\\"", named,'),
         '    _LOG_GATE_D Print("[drawstrip] press named at ", mx, ",", my, " hit=\\"", named,',
         "the press-name diagnostic is DEBUG, not production"),
        (re.compile(r'         if\(!s_dsOpen\) Print\("\[drawstrip\] press edge at ", tmx, ",", tmy, " bit=", \(tleft \? 1 : 0\)\);'),
         '         if(!s_dsOpen) _LOG_GATE_D Print("[drawstrip] press edge at ", tmx, ",", tmy, " bit=", (tleft ? 1 : 0));',
         "the press-edge diagnostic is DEBUG, not production"),
        # P-PERF-DSH1 (2026-10-12) - the queued delete events of a bulk sweep
        # (777 objects ~ 7 s) outrun the 250 ms window on MT5, so indicator-
        # owned objects must never be read as a user gesture. Name-prefix check
        # only; MT4 needs no such guard because its deletes raise no events.
        (re.compile(
            r'      bool userDel = !g_suppressDeleteEvents && !TickDeadlinePending\(g_suppressDeleteEventsUntilMs\);'),
         '      bool isOurObject = DrawIsIndicatorObject(sparam);\n'
         '      bool userDel = !isOurObject && !g_suppressDeleteEvents && !TickDeadlinePending(g_suppressDeleteEventsUntilMs);\n',
         "indicator-owned deletes are never user gestures on MT5"),
        # P-MT5-DRAGREL (2026-10-23) - ONE RELEASE, TWO CHANNELS. MT5 reports a
        # button-up on a drawing twice (the OBJECT click first, the CHART click
        # after); the first spends the press memo, so the second read
        # `s_dsPressTracked == false` and dropped its own MEASURED travel (64 px in
        # the terminal log: `[drawstrip] dismiss click ... travel=64`). The user's
        # report was exactly that: «این استریپ خودکار بسته میشه». P-UI-113d's own
        # sentence is the spec - a drag-release is never a dismissal - and travel
        # is the hand's fact, so it answers without the memo. A motionless click
        # still measures 0 and dismisses as before.
        (re.compile(
            r'       relWasDrag = \(s_dsPressTracked && s_dsTravel > DSTRIP_CLICK_SLOP\);\n'),
         '       //--- MT5-ONLY P-MT5-DRAGREL (2026-10-23) - ONE RELEASE, TWO CHANNELS, ONE\n'
         '       //--- HAND. Travel is the hand\'s own fact and it survives the spent press\n'
         '       //--- memo, so it answers alone here.\n'
         '       relWasDrag = (s_dsTravel > DSTRIP_CLICK_SLOP);\n',
         "MT5 reports one button-up on two channels; honour the measured travel"),
        # P-MT5-TWIN (2026-10-23) - the object-click open arms the twin flag, so the
        # chart click of the SAME release is spent instead of closing what it just
        # opened. Measured: `click opened ...` / `click closed ...` 170 ms apart,
        # twelve times in a minute, and the close wrote OBJPROP_SELECTED=false.
        (re.compile(
            r'          if\(DrawStripClickToggle\(sparam, relWasDrag\)\) return true;\n'),
         '          if(DrawStripClickToggle(sparam, relWasDrag))\n'
         '          {\n'
         '             //--- MT5-ONLY P-MT5-TWIN (2026-10-23): an OPEN owes its twin on\n'
         '             //--- every path; the interior path below already arms it.\n'
         '             if(s_dsOpen) DrawStripTwinArm();\n'
         '             return true;\n'
         '          }\n',
         "the object-click open arms the twin, as the interior open does"),
        # P-MT5-TWIN, second half: the twin must be spent at the DISMISSAL too, not
        # only inside the toggle - the second channel arrives as a chart click.
        (re.compile(
            r'       if\(DrawStripReleaseOnDrawing\(relPressObj, rcx, rcy\)\) return false;\n'
            r'      // P-DRAW-13: pin survives outside clicks[^\n]*\n'
            r'      if\(s_dsPinned\) return false;\n'),
         '      if(DrawStripReleaseOnDrawing(relPressObj, rcx, rcy)) return false;\n'
         '      // P-DRAW-13: pin survives outside clicks (only ✕ paths, Del and Esc dismiss).\n'
         '      if(s_dsPinned) return false;\n'
         '      //--- MT5-ONLY P-MT5-TWIN (2026-10-23): the second channel of the open.\n'
         '      if(DrawStripTwinSpent()) return false;\n',
         "the dismissal spends the twin of the click that opened the strip"),
    ],
    "ExtendedDrawingFunctions.mqh": [
        # P-PERF-CSO1 (2026-10-12) - MT5-only bulk-window arming (see the
        # DrawStrip patches): the surplus loop deletes through
        # DeleteIndicatorObjectManaged, which re-arms/clears the flag per call
        # unless the caller already owns the window. MT4 raises no events here.
        (re.compile(
            r'void CleanupSurplusObjects\(const string prefix, int startIdx, int maxConsecutiveMiss = 6, const string suffix = ""\) \{\n'
            r'    if\(g_customPriceLineDragging && StringFind\(prefix, "_Zone_"\) >= 0\) return;\n'
            r'    int misses = 0;\n'
            r'    bool zoneFamily = \(suffix == "" && StringFind\(prefix, "_Zone_"\) >= 0\);\n'
            r'    for\(int idx = startIdx; misses < maxConsecutiveMiss; idx\+\+\) \{\n'
            r'        string name = prefix \+ IntegerToString\(idx\) \+ suffix;\n'
            r'        bool deleted = zoneFamily \? DeleteManagedZoneObjects\(name, true\)\n'
            r'                                  : DeleteIndicatorObjectManaged\(name, true\);\n'
            r'        if\(deleted\) \{\n'
            r'            misses = 0;\n'
            r'        \} else \{\n'
            r'            misses\+\+;\n'
            r'        \}\n'
            r'    \}\n'
            r'\}'),
         'void CleanupSurplusObjects(const string prefix, int startIdx, int maxConsecutiveMiss = 6, const string suffix = "") {\n'
         '    if(g_customPriceLineDragging && StringFind(prefix, "_Zone_") >= 0) return;\n'
         '    // P-PERF-CSO1 (2026-10-12): arm the bulk-delete suppress window for the loop.\n'
         '    bool wasSupp = g_suppressDeleteEvents;\n'
         '    if(!wasSupp) g_suppressDeleteEvents = true;\n'
         '    int misses = 0;\n'
         '    bool zoneFamily = (suffix == "" && StringFind(prefix, "_Zone_") >= 0);\n'
         '    for(int idx = startIdx; misses < maxConsecutiveMiss; idx++) {\n'
         '        string name = prefix + IntegerToString(idx) + suffix;\n'
         '        bool deleted = zoneFamily ? DeleteManagedZoneObjects(name, true)\n'
         '                                  : DeleteIndicatorObjectManaged(name, true);\n'
         '        if(deleted) {\n'
         '            misses = 0;\n'
         '        } else {\n'
         '            misses++;\n'
         '        }\n'
         '    }\n'
         '    if(!wasSupp) {\n'
         '        g_suppressDeleteEventsUntilMs = GetTickCount() + 250;\n'
         '        g_suppressDeleteEvents = false;\n'
         '    }\n'
         '}',
         "arm the suppression window across the whole surplus sweep"),
        # P-PERF-91 (BUG-05, 2026-10-13): the steady update path pays nothing.
        # The existence probe was the only terminal call left on it, and on MT5
        # that call is a KERNEL ROUND TRIP (MT4's ObjectFind is direct); a
        # ~300-level render paid ~300 probes, all answering "still there" with
        # zero writes to guard. The probe now runs only when a write would; a
        # level whose price/colour/style/width all match costs one cache lookup
        # and one mask check. Correctness untouched: whenever the cache could be
        # stale AND something would be written, the probe still runs first.
        (re.compile(
            r'bool CreateOrUpdateHLine\(const string name, double price,[^\n]*\n'
            r'[^\n]*color clr, ENUM_LINE_STYLE style, int width,\n'
            r'[^\n]*const string tooltip,\n'
            r'[^\n]*const bool visibilityAsLine = true\) \{\n'
            r'    SObjectCacheEntry cachedEntry;\n'
            r'    bool hasCached = CacheGetObject\(name, cachedEntry\);\n'
            r'    bool objectExists = false;\n'
            r'    if\(hasCached && cachedEntry\.exists\) \{\n'
            r'        objectExists = \(ObjectFind\(0, name\) >= 0\);\n'),
         'bool CreateOrUpdateHLine(const string name, double price, \n'
         '                          color clr, ENUM_LINE_STYLE style, int width,\n'
         '                          const string tooltip,\n'
         '                          const bool visibilityAsLine = true) {\n'
         '    SObjectCacheEntry cachedEntry;\n'
         '    bool hasCached = CacheGetObject(name, cachedEntry);\n'
         '    bool objectExists = false;\n'
         '    if(hasCached && cachedEntry.exists) {\n'
         '        double normPriceNow = NormalizeDouble(price, Digits);\n'
         '        bool priceChanged = (MathAbs(cachedEntry.lastPrice - normPriceNow) > GetCachedPoint() * 0.1);\n'
         '        bool lookChanged  = (cachedEntry.lastColor != clr) ||\n'
         '                            (cachedEntry.lastStyle != (int)style) ||\n'
         '                            (cachedEntry.lastWidth != width);\n'
         '        if(!priceChanged && !lookChanged) {\n'
         '            ApplyVisibilityStateIfUnchangedSkip(name, visibilityAsLine);\n'
         '            return false;\n'
         '        }\n'
         '        objectExists = (ObjectFind(0, name) >= 0);\n',
         "the steady HLine path skips the terminal probe entirely (BUG-05)"),
    ],
    "ObjectCache.mqh": [
        # P-PERF-DIOM1 (2026-10-12) - respect a caller-owned suppression window.
        # The MT4 body sets+clears the flag around every single delete, which
        # re-opens the event channel between loop iterations on MT5 (the events
        # MT4 never fires). Standalone deletes behave identically on both trees.
        (re.compile(
            r'    g_suppressDeleteEvents = true;\n'
            r'    g_suppressDeleteEventsUntilMs = GetTickCount\(\) \+ 250;\n'
            r'    bool deleted = ObjectDelete\(0, name\);\n'
            r'    g_suppressDeleteEvents = false;\n'
            r'    return deleted;'),
         '    bool ownedByUs = !g_suppressDeleteEvents;\n'
         '    if(ownedByUs) {\n'
         '        g_suppressDeleteEvents = true;\n'
         '        g_suppressDeleteEventsUntilMs = GetTickCount() + 250;\n'
         '    }\n'
         '    bool deleted = ObjectDelete(0, name);\n'
         '    if(ownedByUs) g_suppressDeleteEvents = false;\n'
         '    return deleted;',
         "only arm/clear the window when this call owns it"),
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
    # --- P-PERF-102 (2026-10-16) — THE LOG-SPAM DIET, module keys added with it:
    # three per-attach echoes that only served the startup verification and had
    # no business in a trading session's journal. MT5-only; MT4 keeps them.
    "InputValidator.mqh": [
        (re.compile(r'        Print\("  Structure Base Multiplier: ", baseMultiplier\);'),
         '        _LOG_GATE_D Print("  Structure Base Multiplier: ", baseMultiplier);',
         "the validated-input echo is DEBUG, not production"),
    ],
    "BasePriceManager.mqh": [
        (re.compile(
            r'    Print\("  Created new state for symbol: ", currentSymbol, " \(Index: ", newIndex, "\)"\);\n'),
         '    _LOG_GATE_D Print("  Created new state for symbol: ", currentSymbol, " (Index: ", newIndex, ")");\n',
         "the state-creation echo is DEBUG, not production"),
    ],
    "HistoricalDataFunctions.mqh": [
        (re.compile(
            r'            Print\("UpdateHistoricalValues: Waiting for historical data \(", EnumToString\(effectiveTimeframe\), "\)\.\.\."\);\n'),
         '            _LOG_GATE_D Print("UpdateHistoricalValues: Waiting for historical data (", EnumToString(effectiveTimeframe), ")...");\n',
         "the waiting-for-history notice is DEBUG, not production (the retry "
         "itself is by design, P-MT5-01b)"),
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
        # P-PERF-94 (BUG-02, 2026-10-13): the composite's provisional state.
        # MT5's iATR() serves a rates-based stand-in while the timeframe is
        # still being built; MT4's iATR is a direct call and never is - so the
        # "was that value provisional?" question only EXISTS on this side. A
        # provisional composite must not be cached (the cache would pin a
        # stand-in for a whole TTL AND hide the state from the next caller),
        # and the adaptive-scaling seed must not latch on it. MT4-equal the
        # moment the value is real; the flag is bookkeeping, not logic.
        (re.compile(
            r'(static bool g_multiTFCacheInitialized = false;\n)'),
         r'\1'
         '// P-PERF-94 (BUG-02, 2026-10-13) - was the last CalculateWeightedATR()\n'
         '// the terminal\'s own ATR, or the compat layer\'s rates-based stand-in?\n'
         '// Read through WeightedATRWasProvisional() by the adaptive-scaling\n'
         '// seed, which must not latch on a value that can still move.\n'
         'static bool g_lastCompositeProvisional = false;\n',
         "the composite's provisional state (MT5-only iATR fallback)"),
        (re.compile(
            r'double CalculateWeightedATR\(ENUM_TIMEFRAMES tf = PERIOD_CURRENT\) \{'),
         'double CalculateWeightedATR(ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {\n'
         '    g_lastCompositeProvisional = false;\n'
         '\n',
         "every composite starts by clearing the provisional flag"),
        (re.compile(
            r'        UpdateMultiTFCache\(tf, result, currentBars\);\n'),
         '        if(!g_lastCompositeProvisional) UpdateMultiTFCache(tf, result, currentBars);\n',
         "a provisional composite is not cached (BUG-02)"),
        (re.compile(r'//\| P-BK-79'),
         'bool WeightedATRWasProvisional() { return g_lastCompositeProvisional; }\n'
         '\n'
         '//| P-BK-79',
         "the provisional flag, readable by the adaptive-scaling seed"),
    ],
    "AdaptiveScaling.mqh": [
        # P-PERF-94 (BUG-02, 2026-10-13): the EMA seed must not latch on a
        # provisional ATR. The seed is what the first paint is drawn from and
        # a re-seed is a full redraw; MT5's stand-in ATR can still move, MT4's
        # iATR cannot. The guard returns "not updated yet", which is exactly
        # what the pre-seed state already answers.
        (re.compile(r'    double weightedATR = CalculateWeightedATR_Locked\(\);\n'),
         '    double weightedATR = CalculateWeightedATR_Locked();\n'
         '    bool atrProvisional = WeightedATRWasProvisional();\n'
         '\n',
         "read the composite's provisional state once per call"),
        (re.compile(
            r'    if\(!g_scalingInitialized\) \{\n'
            r'        // First time: seed EMA with current raw value\n'),
         '    if(!g_scalingInitialized) {\n'
         '        if(atrProvisional) return false;\n'
         '        // First time: seed EMA with current raw value\n',
         "a provisional value must not become the EMA's seed (BUG-02)"),
    ],
    "PerformanceOptimizations.mqh": [
        # P-PERF-94 (BUG-03, 2026-10-13): GetCachedPeriod() must answer the
        # LOCKED period on a locked chart. The lock's state lives in
        # GlobalVariables.mqh, which the entry includes AFTER this file, so the
        # two accessors are declared here and defined there - beside the state
        # they read. MT4's tree still answers the chart's period on this path
        # (it resolves the lock at its other call sites), so this one line
        # differs BY DESIGN: it is the MT5 side of BUG-03, where a locked
        # chart was served two different periods by two sibling paths.
        (re.compile(r'int GetCachedPeriod\(\) \{'),
         'bool CompatTimeframeLockActive();\n'
         'int  CompatLockedPeriod();\n'
         '\n'
         'int GetCachedPeriod() {',
         "the lock accessors the cached period reads through (BUG-03)"),
        (re.compile(r'    int currentPeriod = Period\(\);\n'),
         '    int currentPeriod = CompatTimeframeLockActive() ? CompatLockedPeriod() : Period();\n',
         "the cached period must respect the timeframe lock (BUG-03)"),
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
        # an else). Of the two sites marked "ungated on purpose" in MT4 (the
        # 1079 wipe-author line, the adopt probe), the WIPE-AUTHOR line is still
        # deliberately not in this list — but the ADOPT PROBE now is (P-PERF-102,
        # 2026-10-16): its verification is complete and the user runs this for
        # trading, so MT5 gates it to DEBUG while MT4 keeps the ungated line.
        (re.compile(r'Print\("\[P-VIEW\] probe=handoff'),
         '_LOG_GATE_D Print("[P-VIEW] probe=handoff',
         "the handoff probe is DEBUG, not production"),
        (re.compile(r'Print\("\[P-KEY\]'),
         '_LOG_GATE_D Print("[P-KEY]',
         "key-press diagnostics are DEBUG, not production"),
        (re.compile(r'Print\("\[P-DEL\]'),
         '_LOG_GATE_D Print("[P-DEL]',
         "the delete diagnostic is DEBUG, not production"),
        # P-PERF-95 (BUG-04, 2026-10-13): THE WITNESS THAT SURVIVES THE RELOAD.
        # On MT5 a timeframe switch UNLOADS the indicator, so the frame's own
        # static (`s_lastPeriod`) is re-initialised and the first frame after
        # the switch reads -1 - the old test called that "no change" and the
        # CACHE_INV_TIMEFRAME arm was unreachable on the one event it was
        # written for. MT4 keeps its instance state across the switch, so the
        # stamp has no MT4 twin: one GlobalVariable, written by the teardown
        # that is unloading and read once by the new instance.
        (re.compile(
            r'string CustomPriceGVName\(\) \{ return "Biotak_CustomPrice_" \+ GetCachedChartIdStr\(\); \}\n'),
         '//==============================================================================\n'
         '// P-PERF-95 (BUG-04, 2026-10-13) - the period stamp.\n'
         '//\n'
         '// `s_lastPeriod` cannot survive an MT5 timeframe switch: the terminal\n'
         '// unloads the indicator and every static is re-initialised, so the first\n'
         '// frame sees -1 and `(currentPeriod != s_lastPeriod && s_lastPeriod != -1)`\n'
         '// answers "no change" EVERY time - the arm written for the switch never\n'
         '// ran. The stamp is carried across the reload the same way the topology\n'
         '// stamp is (P-VIEW-05): written by the teardown that is unloading (the\n'
         '// same branch that already writes the topology stamp) and read once by\n'
         '// the new instance. One write per switch, one read per attach - no\n'
         '// per-frame cost, and no dependence on a static that MT5 guarantees is\n'
         '// gone. A first-ever attach has no stamp (`stored == 0`): not a change.\n'
         '//==============================================================================\n'
         'string LastPeriodStampName() { return "Biotak_LastPeriod_" + GetCachedChartIdStr(); }\n'
         '\n'
         'void SavePeriodStamp()\n'
         '{\n'
         '   GlobalVariableSet(LastPeriodStampName(), (double)Period());\n'
         '}\n'
         '\n'
         'void ResolvePeriodChangeAttach()\n'
         '{\n'
         '   int live = Period();\n'
         '   string n = LastPeriodStampName();\n'
         '   bool haveStamp = GlobalVariableCheck(n);\n'
         '   int stored = haveStamp ? (int)GlobalVariableGet(n) : 0;\n'
         '   g_periodChangedOnAttach = (haveStamp && stored > 0 && stored != live);\n'
         '   GlobalVariableSet(n, (double)live);\n'
         '   _LOG_GATE_D Print("[P-PERF] probe=period stored=", stored, " live=", live,\n'
         '         " changed=", (g_periodChangedOnAttach ? 1 : 0), " reason=", UninitializeReason());\n'
         '}\n'
         '\n'
         'string CustomPriceGVName() { return "Biotak_CustomPrice_" + GetCachedChartIdStr(); }\n',
         "the cross-reload period stamp (MT5 reloads the indicator on a switch)"),
        # --- P-PERF-106 (2026-10-16) — THE RESOLUTIONS MOVED TO THE ENTRIES.
        # Inside OnInitHandler the topology fingerprint read the 144 seed
        # (`inpMaxLevels` is `g_maxLevels` there) while the instance that died
        # for the chart change had written the OV_ override's 352 - so EVERY
        # attach printed a stamp mismatch and adoption fell back to a
        # whole-chart family walk (measured 344-1344 ms per attach). Both
        # entries now call the two resolutions LAST, after the OV_ overrides
        # load; the family walk is skipped when the stamp already answered.
        (re.compile(r'    ResolveTopologyAdoption\(\);\n'),
         '    // P-PERF-106 (2026-10-16) — the two cross-reload resolutions moved\n'
         '    // to the entries, after the OV_ runtime overrides load.\n',
         "P-PERF-106: the cross-reload resolutions run in the entries"),
        (re.compile(r'   int preexist = LevelFamilyObjectsOnChart\(\);\n'),
         '   int preexist = stampOk ? -1 : LevelFamilyObjectsOnChart();\n',
         "P-PERF-106: the stamp answers, so the family walk is skipped"),
        (re.compile(r'        SaveTopologyAdoptionStamp\(\);\n'),
         '        SaveTopologyAdoptionStamp();\n'
         '        SavePeriodStamp();\n',
         "write the period stamp on the branch that unloads for a chart change"),
        (re.compile(
            r'    bool timeframeChanged = \(currentPeriod != s_lastPeriod && s_lastPeriod != -1\);\n'),
         '    bool timeframeChanged = (s_lastPeriod == -1)\n'
         '                            ? g_periodChangedOnAttach\n'
         '                            : (currentPeriod != s_lastPeriod);\n',
         "the first frame of an instance asks the cross-reload stamp (BUG-04)"),
        # --- P-PERF-102 (2026-10-16) — THE LOG-SPAM DIET. The user runs this
        # indicator for trading; the per-attach wall (banner + build lines +
        # probes + deferral notices) is DEBUG material, not production output.
        # Every entry here is MT5-only: MT4 keeps its ungated lines (its tree is
        # the logic reference). NOTE for the author: the replacement text must
        # reproduce the gated line VERBATIM (the module-report matches it after
        # comment-stripping - a truncated line reads as drift).
        (re.compile(r'   Print\("\[P-VIEW\] probe=adopt'),
         '   _LOG_GATE_D Print("[P-VIEW] probe=adopt stamp=", (haveStamp ? 1 : 0), " stored=", stored,',
         "the adoption probe is DEBUG after its verification (P-PERF-102)"),
        (re.compile(
            r'    Print\("\[BUILD\] TH3 src=", TH3_BUILD_TAG, " files=", TH3_SRC_FILES, " LITE compiled=",\n'),
         '    _LOG_GATE_D Print("[BUILD] TH3 src=", TH3_BUILD_TAG, " files=", TH3_SRC_FILES, " LITE compiled=",\n',
         "the LITE build stamp is DEBUG, not production"),
        (re.compile(
            r'    Print\("\[BUILD\] TH3 src=", TH3_BUILD_TAG, " files=", TH3_SRC_FILES, " FULL compiled=",\n'),
         '    _LOG_GATE_D Print("[BUILD] TH3 src=", TH3_BUILD_TAG, " files=", TH3_SRC_FILES, " FULL compiled=",\n',
         "the FULL build stamp is DEBUG, not production"),
        (re.compile(r'    Print\("\[BUILD\] ramp t0=", \(int\)BioCardTone\(0\.0\),\n'),
         '    _LOG_GATE_D Print("[BUILD] ramp t0=", (int)BioCardTone(0.0),\n',
         "the ramp probe line is DEBUG, not production"),
        (re.compile(r'    PrintBuildInfo\(\);\n'),
         '    _LOG_GATE_D PrintBuildInfo();\n',
         "the 10-line version banner is DEBUG, not production (gate at the call "
         "site: BuildConfig is included before Logger, so the macro does not "
         "exist where the printer lives)"),
        (re.compile(
            r'_LOG_GATE_W Print\("\[W\]\[GEN\] OnInit: historical data not ready \(err ",\n'),
         '_LOG_GATE_D Print("[W][GEN] OnInit: historical data not ready (err ",\n',
         "the history-deferral notice printed every attach; DEBUG (P-PERF-102)"),
        (re.compile(
            r'_LOG_GATE_W Print\("\[W\]\[GEN\] OnInit: previous-day prices not ready \(D1 series still loading\) - deferring"\);\n'),
         '_LOG_GATE_D Print("[W][GEN] OnInit: previous-day prices not ready (D1 series still loading) - deferring");\n',
         "the prev-day-deferral notice printed every attach; DEBUG (P-PERF-102)"),
        (re.compile(
            r'_LOG_GATE_W Print\("\[W\]\[GEN\] RedrawAllObjects: UpdateHistoricalValues failed, retrying later\.\.\."\);\n'),
         '_LOG_GATE_D Print("[W][GEN] RedrawAllObjects: UpdateHistoricalValues failed, retrying later...");\n',
         "the redraw-retry notice printed every attach; DEBUG (P-PERF-102)"),
        # P-PERF-TMP (2026-10-16): the two stamps and the threshold print measure
        # the CHART_CHANGE branch PART the phase ledger does not cover (the ride +
        # the pre-throttle head). Remove with the strip-close probes once the
        # slow-event owner is named.
        (re.compile(
            r'        if\(IsIndicatorHidden\(\)\) return;\n'
            r'        HandsetMarkersRide\(\);[^\n]*\n'),
         '        if(IsIndicatorHidden()) return;\n'
         '        uint p_tmpCc0 = GetTickCount();   // P-PERF-TMP (remove after attribution)\n'
         '        HandsetMarkersRide();   // P-UI-98d v2: the handles ride every layout change\n'
         '        uint p_tmpCc1 = GetTickCount();   // P-PERF-TMP\n',
         "P-PERF-TMP: chart-change pre-ledger head stamps"),
        (re.compile(r'        uint p28t = GetTickCount\(\);\n'),
         '        uint p28t = GetTickCount();\n'
         '        // P-PERF-TMP (remove after attribution): the part of the branch the\n'
         '        // phase ledger below does not cover \u2014 the ride and the pre-throttle head\n'
         '        // (throttle read, chart reads, the prime). The TF-switch event that took\n'
         '        // 1141 ms showed a 78 ms phase sum, so its owner is in here.\n'
         '        if((p28t - p_tmpCc0) >= 100)\n'
         '           Print("[W][PERF-TMP] cc pre: ride=", (int)(p_tmpCc1 - p_tmpCc0),\n'
         '                 "ms head=", (int)(p28t - p_tmpCc1), "ms total=", (int)(p28t - p_tmpCc0), "ms");\n',
         "P-PERF-TMP: chart-change pre-ledger threshold probe"),
        # P-PERF-105 (2026-10-16) - THE FIRST INTERVAL AFTER ATTACH SEEDS THE
        # CLEANUP BASELINE. `g_objectCountLast` is 0 on every fresh instance, so
        # the growth test was true on the first coop tick of EVERY attach and
        # the emergency walk spent up to 300 per-call object reads on a chart
        # that had not grown at all: `coop job=obj-cleanup ran=890ms` on the
        # live D1 attach. The seed is one ObjectsTotal call; the net arms from
        # the second interval.
        (re.compile(
            r'void RunIncrementalObjectCleanup\(\)\n\{\n'
            r'    if\(g_customPriceLineDragging\) return;\n'
            r'    datetime currentTime = TimeGMT\(\);\n'
            r'    if\(currentTime - g_lastObjectCleanup <= CLEANUP_INTERVAL_SECONDS\) return;\n'),
         'void RunIncrementalObjectCleanup()\n'
         '{\n'
         '    if(g_customPriceLineDragging) return;\n'
         '    datetime currentTime = TimeGMT();\n'
         '    if(currentTime - g_lastObjectCleanup <= CLEANUP_INTERVAL_SECONDS) return;\n'
         '    if(g_lastObjectCleanup == 0)\n'
         '    {\n'
         '        g_objectCountLast = ObjectsTotal(0, -1, -1);\n'
         '        g_lastObjectCleanup = currentTime;\n'
         '        return;\n'
         '    }\n',
         "P-PERF-105: the first interval after attach seeds the baseline, no walk"),
        # --- P-PERF-108 / P-VIEW-05 (2026-10-16) - THE PAINT WAITS FOR REAL
        # HISTORY, AND THE VIEWPORT WINDOW IS GONE FROM THE STAGE PIPELINE.
        # R1-R2: the wrapper and its pipeline call no longer carry vpTop/vpBottom
        # (P-VIEW-05). R3: the viewport fetch + stage-1 freeze became the
        # history-hold (P-PERF-108). R4-R5: the render decision and the flag
        # clears consult the hold. R6: the hold bound, a const so it groups
        # with the #decls chunk instead of reading as an MT5-only symbol.
        (re.compile(re.escape(r"""void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice,
                           const double vpTop, const double vpBottom, const int buildStage)""")),
         r"""void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice,
                           const int buildStage)""",
         "P-VIEW-05: the wrapper no longer takes a cull window"),
        (re.compile(re.escape(r"""        ExecutePipeline(def.config, data.midpointPrice, sizes, def.stepSizeCount,
                       def.stepMode, def.classifyMode, def.lsFirst,
                       data.maxLevelsAbove, data.maxLevelsBelow,
                       vpTop, vpBottom, buildStage);""")),
         r"""        ExecutePipeline(def.config, data.midpointPrice, sizes, def.stepSizeCount,
                       def.stepMode, def.classifyMode, def.lsFirst,
                       data.maxLevelsAbove, data.maxLevelsBelow,
                       buildStage);""",
         "P-VIEW-05: the pipeline call no longer passes a cull window"),
        (re.compile(re.escape(r"""        double vpTop = 0, vpBottom = 0;
        GetViewportBounds(vpTop, vpBottom);
        // P-PERF-06: freeze the cull window for the whole staging sequence —
        // stages 2-4 render against the stage-1 snapshot so a pan mid-staging
        // cannot split families across two viewports.
        if(g_buildStage == BUILD_STAGE_LINES) {
            g_stageVpTop = vpTop;
            g_stageVpBottom = vpBottom;
        } else if(g_buildStage > BUILD_STAGE_LINES) {
            vpTop = g_stageVpTop;
            vpBottom = g_stageVpBottom;""")),
         r"""        static uint s_historyHoldStartMs = 0;
        bool historyHold = false;
        if(g_adoptPreviousTopology && !g_initialized) {
            if(s_historyHoldStartMs == 0) s_historyHoldStartMs = nowMs;
            historyHold = ((nowMs - s_historyHoldStartMs) < P_HISTORY_HOLD_MAX_MS);
        } else {
            s_historyHoldStartMs = 0;""",
         "P-PERF-108: the stage-1 viewport freeze became the history-hold"),
        # P-PERF-108a (2026-10-16): the hold moved ABOVE the wipe and the wipe
        # itself is gated on it, so a held frame touches nothing; the same edit
        # added the first-frame / wipe witnesses. Both MT4 wipe blocks
        # (`if(shouldClearLevels) {` x2) are consumed by the pattern.
        (re.compile(re.escape(r"""        if(shouldClearLevels) {
            TH3_PROF_START(LevelsClear);
            ClearAllLevels(objectPrefix, !skipZones);
            TH3_PROF_END(LevelsClear);
        }

        // P-PERF-06: ANY wipe rebuilds in stages (attach, TF switch, topology
        // toggle, custom-price re-anchor — all of them materialise ~900
        // objects). Unconditional restart: a toggle that wipes mid-staging
        // must rebuild from stage 1, or the wiped families never come back.
        if(shouldClearLevels) {
            g_buildStage = BUILD_STAGE_LINES;
        }""")),
         r"""        static uint s_historyHoldStartMs = 0;
        bool historyHold = false;
        if(g_adoptPreviousTopology && !g_initialized) {
            if(s_historyHoldStartMs == 0) s_historyHoldStartMs = nowMs;
            historyHold = ((nowMs - s_historyHoldStartMs) < P_HISTORY_HOLD_MAX_MS);
        } else {
            s_historyHoldStartMs = 0;
        }

        bool shouldClearLevels = g_forceClearOnNextDraw || levelTopologyChanged;

        static bool s_f1WitnessLogged = false;
        if(!s_f1WitnessLogged) {
            s_f1WitnessLogged = true;
            _LOG_GATE_W Print("[W][PERF] f1 adopt=", (g_adoptPreviousTopology ? 1 : 0),
                  " init=", (g_initialized ? 1 : 0),
                  " clear=", (shouldClearLevels ? 1 : 0),
                  " topo=", (levelTopologyChanged ? 1 : 0),
                  " hold=", (historyHold ? 1 : 0),
                  " stg=", (int)g_buildStage,
                  " base=", DoubleToString(g_dailyClosePriceForTH, Digits));
        }

        if(shouldClearLevels && !historyHold) {
            static uint s_lastWipeWitnessMs = 0;
            if(nowMs - s_lastWipeWitnessMs > 2000) {
                s_lastWipeWitnessMs = nowMs;
                _LOG_GATE_W Print("[W][PERF] levels WIPE: force=", (g_forceClearOnNextDraw ? 1 : 0),
                      " topo=", (levelTopologyChanged ? 1 : 0),
                      " adopt=", (g_adoptPreviousTopology ? 1 : 0),
                      " init=", (g_initialized ? 1 : 0),
                      " objs=", ObjectsTotal(0, -1, -1));
            }
            TH3_PROF_START(LevelsClear);
            ClearAllLevels(objectPrefix, !skipZones);
            TH3_PROF_END(LevelsClear);
        }

        // P-PERF-06: ANY wipe rebuilds in stages (attach, TF switch, topology
        // toggle, custom-price re-anchor — all of them materialise ~900
        // objects). Unconditional restart: a toggle that wipes mid-staging
        // must rebuild from stage 1, or the wiped families never come back.
        if(shouldClearLevels && !historyHold) {
            g_buildStage = BUILD_STAGE_LINES;
        }""",
         "P-PERF-108a: the hold gates the wipe too + first-frame/wipe witnesses"),
        (re.compile(re.escape(r"""            if(!g_initialized && thBasePrice > 0) {
                // We have a base price, so we can at least try to draw something
                g_highestHigh = thBasePrice * 1.01;""")),
         r"""            if(!g_initialized && thBasePrice > 0) {
                static uint s_lastSyntheticWitnessMs = 0;
                if(nowMs - s_lastSyntheticWitnessMs > 2000) {
                    s_lastSyntheticWitnessMs = nowMs;
                    _LOG_GATE_W Print("[W][PERF] synthetic band: history not ready base=",
                          DoubleToString(thBasePrice, Digits),
                          " adopt=", (g_adoptPreviousTopology ? 1 : 0));
                }
                // We have a base price, so we can at least try to draw something
                g_highestHigh = thBasePrice * 1.01;""",
         "P-PERF-108a: witness when the ±1% synthetic band stands in for history"),
        (re.compile(re.escape(r"""        bool mustRender = (shouldClearLevels || geometryChanged ||
                           (g_renderAllNeeded && !visOnly));
        if(mustRender && g_buildStage != BUILD_STAGE_BLOCK && !visOnly)
        {
            TH3_PROF_START(LevelsDrawByMode);
            DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH, vpTop, vpBottom, g_buildStage);""")),
         r"""        bool mustRender = (shouldClearLevels || geometryChanged ||
                           (g_renderAllNeeded && !visOnly)) && !historyHold;
        if(mustRender && g_buildStage != BUILD_STAGE_BLOCK && !visOnly)
        {
            TH3_PROF_START(LevelsDrawByMode);
            DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH, g_buildStage);""",
         "P-PERF-108: a held frame must not paint (or seal) the transient ladder"),
        (re.compile(re.escape(r"""        g_p3MsLevels += GetTickCount() - g_p3MsLastTick;
        g_p3MsLastTick = GetTickCount();
        g_forceClearOnNextDraw = false;
        g_redrawTHLevelsNeeded = false;""")),
         r"""        g_p3MsLevels += GetTickCount() - g_p3MsLastTick;
        g_p3MsLastTick = GetTickCount();
        // P-PERF-108: a HELD frame consumed nothing - the debt and the wipe
        // request must survive it, or the release frame would find no reason
        // to run and the picture would stay on the adopted family forever.
        if(!historyHold) {
            g_forceClearOnNextDraw = false;
            g_redrawTHLevelsNeeded = false;
        }""",
         "P-PERF-108: a held frame consumes nothing, so it clears nothing"),
        (re.compile(re.escape(r"""#define BUILD_STAGE_GATE_MS 60   // P-PERF-34b: spacing between staged rebuild frames""")),
         r"""#define BUILD_STAGE_GATE_MS 60   // P-PERF-34b: spacing between staged rebuild frames

// P-PERF-108 (2026-10-16) — HOW LONG AN ADOPTED FAMILY MAY HOLD THE PAINT WHILE
// HISTORY IS STILL SYNTHETIC. `!g_initialized` means RedrawAllObjects is
// standing in a ±1% band around the base price (its own fallback) and any
// ladder built from it is a fraction of the real one. On a handoff the chart
// already carries the previous instance's family (g_adoptPreviousTopology),
// which is a REAL ladder — so the paint waits for real history instead of
// overwriting it with the synthetic rungs and swapping again a frame later.
// The pump owes a frame every 250 ms while `!g_initialized`, so the normal
// wait is one or two frames; the bound exists only for a symbol whose history
// genuinely never lands — after it, the synthetic ladder paints (as it always
// did) and the cleanup/sweep gates keep it from deleting anything.
const uint P_HISTORY_HOLD_MAX_MS = 2000;""",
         "P-PERF-108: how long an adopted family may hold the paint"),
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
        # P-PERF-95 (BUG-04, 2026-10-13): the cross-reload period-change flag,
        # declared here because EventHandlers is included after this file (an
        # MQL4 file has no forward reference for a global). See the period-stamp
        # patches in EventHandlers.mqh: on MT5 the witness static is wiped by
        # the reload a timeframe switch performs, so the answer must be carried
        # in a GlobalVariable. MT4 keeps its instance state and has no flag.
        (re.compile(r'bool g_adoptPreviousTopology = false;\n'),
         'bool g_adoptPreviousTopology = false;\n'
         '// P-PERF-95 (BUG-04, 2026-10-13) - "the chart period is not what the\n'
         '// instance before me was showing", resolved ONCE per instance at the end\n'
         '// of OnInitHandler (ResolvePeriodChangeAttach, EventHandlers) from the\n'
         '// stamp the teardown wrote.\n'
         'bool g_periodChangedOnAttach = false;\n',
         "the cross-reload period-change flag (BUG-04)"),
        # P-PERF-94 (BUG-03, 2026-10-13): the timeframe-lock accessors, defined
        # beside the state they read (PerformanceOptimizations.mqh, included
        # before this file, forward-declares them). MT4 resolves the lock at its
        # call sites instead, so the pair is MT5-only.
        (re.compile(r'static int g_lockedPeriod = 0;\n'),
         'static int g_lockedPeriod = 0;\n'
         'bool CompatTimeframeLockActive() { return (g_timeframeLocked && g_lockedPeriod > 0); }\n'
         'int  CompatLockedPeriod()        { return g_lockedPeriod; }\n',
         "the timeframe-lock accessors the cached period reads through (BUG-03)"),
        # --- P-VIEW-05 (2026-10-16) - THE STAGE VIEWPORT SNAPSHOT IS GONE.
        # The window never decided what the stages paint (the build's
        # inViewport flags had no consumer), so the freeze could only split a
        # family across a window nothing read. P-PERF-108's history-hold
        # guards the transient-build window instead.
        (re.compile(re.escape(r"""// Viewport snapshot taken on the stage-1 frame: stages 2-4 cull against the
// SAME window so a pan mid-staging cannot split families across viewports.
// Stale at most ~1 s by construction; the next viewport-driven render heals it.
static double g_stageVpTop = 0.0;
static double g_stageVpBottom = 0.0;""")),
         r"""// P-VIEW-05 (2026-10-16): `g_stageVpTop`/`g_stageVpBottom` stood here — the
// window snapshot that froze stages 2-4 to the stage-1 frame's viewport. The
// window never decided what the stages paint (the build's `inViewport` flags
// had no consumer), so the freeze could only split a family across a window
// nothing read. The stages now share the build lists alone (PipelineGeometryKey),
// and P-PERF-108's history-hold guards the transient-build window instead.""",
         "P-VIEW-05: the stage viewport snapshot has no consumer"),
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
        # P-PERF-92 (BUG-08, 2026-10-13): the BACK re-ownership probe rides
        # the text gate. The probe ran on EVERY pass - one kernel round trip
        # per label per render, all answering "false" on a healthy chart,
        # because the create branch above sets BACK=false at birth. The state
        # it repairs (a stale label left with BACK=true) can exist only while
        # the label is being REWRITTEN, so it is asked exactly then. MT4 keeps
        # the unguarded form; the verdict cannot change (a repair pass still
        # repairs, and a skipped pass had nothing to repair).
        (re.compile(
            r'        if\(!hasCachedLabel \|\| cachedText != labelText\)\n'
            r'            ObjectSetString\(0, name, OBJPROP_TEXT, labelText\);\n'),
         '        bool labelTextChanged = (!hasCachedLabel || cachedText != labelText);\n'
         '        if(labelTextChanged)\n'
         '            ObjectSetString(0, name, OBJPROP_TEXT, labelText);\n',
         "name the text-changed condition once; the BACK probe rides it"),
        (re.compile(
            r'        if\(\(bool\)ObjectGetInteger\(0, name, OBJPROP_BACK\)\)\n'),
         '        if(labelTextChanged && (bool)ObjectGetInteger(0, name, OBJPROP_BACK))\n',
         "the BACK probe only when the text was just rewritten"),
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
            r'if\(above != s_wA \|\| below != s_wB\) \{ s_wA = above; s_wB = below; Print\("\[LVL\] split N=", N, " above=", above, " below=", below\); \}'),
         'if(above != s_wA || below != s_wB) { s_wA = above; s_wB = below; _LOG_GATE_D Print("[LVL] split N=", N, " above=", above, " below=", below); }',
         "the split-count witness is DEBUG, not production (P-PERF-102)"),
        (re.compile(
            r'            CreatePipDistanceLabel\(labelName, lines\[i\]\.price, pips,\n'
            r'                                   lines\[i\]\.isTrigger \? lblClr : lineClr,\n'
            r'                                   lines\[i\]\.labelText\);\n'),
         '            CreatePipDistanceLabel(labelName, lines[i].price, pips,\n'
         '                                   lines[i].isTrigger ? lblClr : lineClr,\n'
         '                                   lines[i].labelText, PipDistanceLabelLift());\n',
         "one lift per render pass, not three chart reads per level"),
        # P-PERF-97 (BUG-10, 2026-10-13): one reservation for the whole walk.
        # The sweep visits every chart object and can collect nearly all of
        # them, and `doomed[]` was grown ONE ELEMENT AT A TIME - up to ~1000
        # reallocations of a growing string array inside the walk that already
        # pays an ObjectName per object. `total` is the exact upper bound, so
        # it is reserved once and the growth calls below stay only as guards.
        (re.compile(r'    string doomed\[\];\n    int nd = 0;\n'),
         '    string doomed[];\n'
         '    int nd = 0;\n'
         '    if(total > 0) ArrayResize(doomed, total);\n'
         '\n',
         "reserve the whole walk's doomed[] once (BUG-10)"),
        (re.compile(r'ArrayResize\(doomed, nd \+ 1\);'),
         'if(nd >= ArraySize(doomed)) ArrayResize(doomed, nd + 1);',
         "guarded growth; the reservation above is the normal path"),
        # --- P-PERF-107 (2026-10-16) - THE HANDOFF SWEEP IS RESUMABLE.
        # The whole-chart walk cost 1016-1062 ms on the user's chart and blocked
        # the FIRST RENDER of the handoff frame (the new chart stayed empty for
        # a full second on top of the ~1 s OnInit walk). The walk and the
        # deletions now run SWEEP_FOREIGN_CHUNK objects per frame and return -1
        # while still running; the caller latches the handoff only when the
        # sweep returns >= 0, and it runs OUTSIDE the stepSig block so it can
        # advance on every frame. Same deletion set as P-LEVEL-FOREIGN-02.
        # P-PERF-107b: the "cannot judge yet" early-outs return -1, not 0 - the
        # first post-handoff frames have no base price yet, and a 0 there let
        # the caller latch before the real build landed (nothing swept).
        # P-PERF-108 adds `g_initialized` to that readiness question (the old
        # window test was a proxy for it), and gates the whole sweep entry.
        (re.compile(re.escape(r"""int SweepForeignLadderObjects(const SModeConfig &config,
                              const STriggerLine &lines[],
                              const int lineCount,
                              const SZoneDefinition &zones[],
                              const int zoneCount,
                              const double vpTop,
                              const double vpBottom)
{
    if(!(vpTop > vpBottom) || vpBottom <= 0) return 0;   // unusable window: no judgement
    if(lineCount <= 0) return 0;                        // nothing produced: nothing to say

    // What this build owns, by NAME (labels included: a line and its pip label
    // are one decision, and RenderTriggerLines writes both).
    string produced[];
    int pc = 0;
    ArrayResize(produced, lineCount * 2 + zoneCount);
    for(int l = 0; l < lineCount; l++)
    {
        produced[pc++] = lines[l].name;
        produced[pc++] = lines[l].name + "_Label";
    }
    for(int z = 0; z < zoneCount; z++)
        produced[pc++] = zones[z].name;

    const string fam = config.objectPrefix + config.modeName + "_";
    const int total = ObjectsTotal(0, -1, -1);
    string doomed[];
    int nd = 0;

    // P-PERF-55: the membership question is asked once per family name below, so
    // the list is turned into a SET here — one O(pc) build, one probe per name.
    // `false` = the list is too big for the table: every test below then uses the
    // original exact scan, so the verdict cannot change with the shape.
    const bool producedSet = LadderSetBuild(produced, pc);

    for(int i = total - 1; i >= 0; i--)
    {
        const string nm = ObjectName(0, i, -1, -1);
        if(!LadderFamilyName(nm, fam)) continue;

        if(LadderNameIsZoneBand(nm))
        {
            if(producedSet ? LadderSetHas(nm) : ProducedLadderName(nm, produced, pc)) continue;
            ArrayResize(doomed, nd + 1);
            doomed[nd++] = nm;
            continue;
        }
        if(StringFind(nm, "_Zone_") >= 0) continue;   // a border sub-object: its band decides

        if(producedSet ? LadderSetHas(nm) : ProducedLadderName(nm, produced, pc)) continue;
        ArrayResize(doomed, nd + 1);
        doomed[nd++] = nm;
    }

    if(nd == 0) return 0;

    g_suppressDeleteEvents = true;
    int removed = 0;
    for(int d = 0; d < nd; d++)
    {
        if(StringFind(doomed[d], "_Zone_") >= 0)
        {
            if(DeleteManagedZoneObjects(doomed[d], true)) removed++;
        }
        else if(DeleteIndicatorObjectManaged(doomed[d], true)) removed++;
    }
    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
    g_suppressDeleteEvents = false;
    return removed;
}""")),
         r"""const int SWEEP_FOREIGN_CHUNK = 250;
static bool   s_fsActive  = false;
static int    s_fsPhase   = 0;
static int    s_fsCursor  = 0;
static string s_fsFam     = "";
static string s_fsProduced[];
static int    s_fsPc      = 0;
static bool   s_fsSet     = false;
static string s_fsDoomed[];
static int    s_fsNd      = 0;
static int    s_fsRemoved = 0;

int SweepForeignLadderObjects(const SModeConfig &config,
                              const STriggerLine &lines[],
                              const int lineCount,
                              const SZoneDefinition &zones[],
                              const int zoneCount)
{
    if(!s_fsActive)
    {
        // P-PERF-107b (2026-10-16): "cannot judge yet" is NOT a verdict. The
        // hoisted caller runs on EVERY frame - including the first frames
        // after a handoff, where there is no base price yet (centerPrice<=0
        // above leaves lineCount at 0). Returning 0 there made the caller
        // latch `s_foreignSweepDone` before the real build ever landed, so
        // the previous timeframe's ladder was never swept (no FOREIGN print
        // in the whole 15:20-15:28 tour). -1 = "retry next frame".
        // P-VIEW-05 (2026-10-16): the old gate here asked whether the CULL
        // WINDOW was usable — a proxy for "the build is real". It is the
        // readiness flag itself now: the window never decided what this
        // sweep may delete, and `g_initialized` names the fact the proxy
        // was standing in for (history landed, the ladder is final).
        if(!g_initialized) return -1;                        // transient ladder: not judged
        if(lineCount <= 0) return -1;                        // nothing produced yet: not judged

        // What this build owns, by NAME (labels included: a line and its pip
        // label are one decision, and RenderTriggerLines writes both).
        s_fsPc = lineCount * 2 + zoneCount;
        ArrayResize(s_fsProduced, s_fsPc);
        int pc = 0;
        for(int l = 0; l < lineCount; l++)
        {
            s_fsProduced[pc++] = lines[l].name;
            s_fsProduced[pc++] = lines[l].name + "_Label";
        }
        for(int z = 0; z < zoneCount; z++)
            s_fsProduced[pc++] = zones[z].name;

        s_fsFam = config.objectPrefix + config.modeName + "_";
        // P-PERF-55: the membership question is asked once per family name, so
        // the list is turned into a SET here — one O(pc) build, one probe per
        // name. `false` = the list is too big for the table: every test below
        // then uses the original exact scan, so the verdict cannot change.
        // The set is NOT rebuilt per chunk: nothing else calls LadderSetBuild
        // while a sweep is active.
        s_fsSet = LadderSetBuild(s_fsProduced, s_fsPc);

        // P-PERF-97 (BUG-10, 2026-10-13): ONE ALLOCATION FOR THE WHOLE WALK —
        // `total` is the exact upper bound on the names the walk can collect.
        const int total = ObjectsTotal(0, -1, -1);
        s_fsNd = 0;
        if(total > 0) ArrayResize(s_fsDoomed, total);
        s_fsCursor = total - 1;
        s_fsRemoved = 0;
        s_fsPhase = 0;
        s_fsActive = true;
    }

    if(s_fsPhase == 0)
    {
        // Phase 0: walk, SWEEP_FOREIGN_CHUNK objects this frame.
        int examined = 0;
        while(s_fsCursor >= 0 && examined < SWEEP_FOREIGN_CHUNK)
        {
            const string nm = ObjectName(0, s_fsCursor, -1, -1);
            s_fsCursor--;
            examined++;
            if(!LadderFamilyName(nm, s_fsFam)) continue;

            if(LadderNameIsZoneBand(nm))
            {
                if(s_fsSet ? LadderSetHas(nm) : ProducedLadderName(nm, s_fsProduced, s_fsPc)) continue;
                if(s_fsNd >= ArraySize(s_fsDoomed)) ArrayResize(s_fsDoomed, s_fsNd + 1);
                s_fsDoomed[s_fsNd++] = nm;
                continue;
            }
            if(StringFind(nm, "_Zone_") >= 0) continue;   // a border sub-object: its band decides

            if(s_fsSet ? LadderSetHas(nm) : ProducedLadderName(nm, s_fsProduced, s_fsPc)) continue;
            if(s_fsNd >= ArraySize(s_fsDoomed)) ArrayResize(s_fsDoomed, s_fsNd + 1);
            s_fsDoomed[s_fsNd++] = nm;
        }
        if(s_fsCursor >= 0) return -1;   // more to walk — the caller must not latch
        if(s_fsNd == 0) { s_fsActive = false; return 0; }
        s_fsPhase = 1;
    }

    // Phase 1: delete, SWEEP_FOREIGN_CHUNK names this frame (popped from the
    // end of the doomed list — the order never mattered).
    g_suppressDeleteEvents = true;
    int deleted = 0;
    while(s_fsNd > 0 && deleted < SWEEP_FOREIGN_CHUNK)
    {
        const string nm = s_fsDoomed[s_fsNd - 1];
        s_fsNd--;
        deleted++;
        if(StringFind(nm, "_Zone_") >= 0)
        {
            if(DeleteManagedZoneObjects(nm, true)) s_fsRemoved++;
        }
        else if(DeleteIndicatorObjectManaged(nm, true)) s_fsRemoved++;
    }
    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
    g_suppressDeleteEvents = false;
    if(s_fsNd > 0) return -1;   // more to delete — the caller must not latch
    const int removed = s_fsRemoved;
    s_fsActive = false;
    return removed;
}""",
         "P-PERF-107: the handoff sweep walks/deletes in resumable chunks"),
        (re.compile(re.escape(r"""                if(g_adoptPreviousTopology && !s_foreignSweepDone)
                {
                    s_foreignSweepDone = true;   // this frame IS the handoff
                    int stale = SweepForeignLadderObjects(config, lines, result.lineCount,
                                                          zones, result.zoneCount,
                                                          vpTop, vpBottom);
                    if(stale > 0)
                        _LOG_GATE_W Print("[W][GEN] P-LEVEL-FOREIGN-02: deleted ", stale,
                                          " ladder object(s) this build does not produce ",
                                          "(handoff, family=", config.modeName, ")");
                }""")),
         r"""    if(g_adoptPreviousTopology && g_initialized && !s_foreignSweepDone
       && !g_s1DragLive && !g_customPriceLineDragging)
    {
        int stale = SweepForeignLadderObjects(config, lines, result.lineCount,
                                              zones, result.zoneCount);
        if(stale >= 0)
        {
            s_foreignSweepDone = true;   // the handoff's sweep has finished
            if(stale > 0)
                _LOG_GATE_W Print("[W][GEN] P-LEVEL-FOREIGN-02: deleted ", stale,
                                  " ladder object(s) this build does not produce ",
                                  "(handoff, family=", config.modeName, ")");
        }
    }""",
         "P-PERF-107: the handoff sweep runs outside the stepSig block"),
        # --- P-VIEW-05 (2026-10-16) - THE VIEWPORT WINDOW IS GONE FROM THE
        # PIPELINE. The window never decided what the pipeline paints: the
        # inViewport flags it set had no consumer (the render does its own
        # mask), and the geometry key never read it either - it could only
        # re-key a rebuild that the build itself would produce identically.
        # Every vpTop/vpBottom parameter, field, assignment and census term is
        # removed here; the build's readiness is named by g_initialized alone
        # (P-PERF-108).
        (re.compile(re.escape(r"""    bool   outline;         // draw the edge (three border segments)
    bool   inViewport;      // false = skip render, geometry is valid""")),
         r"""    bool   outline;         // draw the edge (three border segments)
""",
         "P-VIEW-05: the zone's inViewport flag had no consumer"),
        (re.compile(re.escape(r"""                            // so its pip label wears the TRIGGER LABEL surface
    bool   inViewport;      // false = skip render
    bool   isMidpoint;""")),
         r"""                            // so its pip label wears the TRIGGER LABEL surface
    bool   isMidpoint;
""",
         "P-VIEW-05: the line's inViewport flag had no consumer"),
        (re.compile(re.escape(r"""void BuildZonesAndLines(
    const SLevelClassified &classified[],
    const int classifiedCount,
    const SModeConfig &config,
    const double vpTop,
    const double vpBottom,
    const double fixedZoneStepSize,""")),
         r"""void BuildZonesAndLines(
    const SLevelClassified &classified[],
    const int classifiedCount,
    const SModeConfig &config,
    const double fixedZoneStepSize,""",
         "P-VIEW-05: the build no longer takes a cull window"),
        (re.compile(re.escape(r"""        zones[zIdx].inViewport = (zones[zIdx].renderTop >= vpBottom && 
                       zones[zIdx].renderBottom <= vpTop);""")),
         "",
         "P-VIEW-05: the center zone no longer computes an inViewport flag"),
        (re.compile(re.escape(r"""            zones[zIdx].inViewport = (zones[zIdx].renderTop >= vpBottom && 
                                      zones[zIdx].renderBottom <= vpTop);""")),
         "",
         "P-VIEW-05: the above/below zones no longer compute inViewport flags"),
        (re.compile(re.escape(r"""        lines[lIdx].inViewport = (lineMidPrice >= vpBottom && lineMidPrice <= vpTop);
""")),
         "",
         "P-VIEW-05: the above/below lines no longer compute inViewport flags"),
        (re.compile(re.escape(r"""void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config,
    const double vpTop,
    const double vpBottom)""")),
         r"""void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config)""",
         "P-VIEW-05: RenderZones no longer takes a cull window"),
        (re.compile(re.escape(r"""void RenderTriggerLines(
    const STriggerLine &lines[],
    const int lineCount,
    const SModeConfig &config,
    const bool makeLines,
    const bool makeLabels,
    const double vpTop,
    const double vpBottom)""")),
         r"""void RenderTriggerLines(
    const STriggerLine &lines[],
    const int lineCount,
    const SModeConfig &config,
    const bool makeLines,
    const bool makeLabels)""",
         "P-VIEW-05: RenderTriggerLines no longer takes a cull window"),
        (re.compile(re.escape(r"""void CleanupSurplusPipeline(
    const SModeConfig &config,
    const int maxLogicalStep){
""")),
         r"""void CleanupSurplusPipeline(
    const SModeConfig &config,
    const int maxLogicalStep)
{
    // ══════════════════════════════════════════════════════════════════════
    // P-PERF-108 (2026-10-16) — NO SURPLUS DELETE AGAINST A TRANSIENT BUILD.
    //
    // `maxLogicalStep` arrives from the build that just ran, and on the first
    // frame after a timeframe switch that build can be SYNTHETIC: history has
    // not landed yet, so RedrawAllObjects stands in a ±1% band around the base
    // price (EventHandlers, the `!g_initialized` fallback) and the ladder that
    // comes out is a fraction of the real one. This walk then deleted every
    // adopted object above that fraction — names the REAL build produces and
    // the very next frame re-creates — which is the delete-and-reappear blink
    // the user reported («حذف و ظاهر میشه مثل چشم زدن»), on EVERY switch.
    //
    // `!g_initialized` is the exact name of "history is not trustworthy yet":
    // it is false from attach/switch until UpdateHistoricalValues succeeds,
    // and RedrawAllObjects retries it every heavy frame (the pump owes one
    // every 250 ms on a tick-less chart), so the moment it flips, the next
    // frame's cleanup runs against the real ladder. Nothing accumulates: the
    // real build's own frame deletes the true surplus in one pass.
    // ══════════════════════════════════════════════════════════════════════
    if(!g_initialized) return;""",
         "P-PERF-108: cleanup must not judge a transient ladder"),
        (re.compile(re.escape(r"""string PipelineGeometryKey(const SModeConfig &config,
                           const double centerPrice,
                           const double &stepSizes[],
                           const int stepSizeCount,
                           const ENUM_LEVEL_STEP_MODE stepMode,
                           const ENUM_CLASSIFY_MODE classifyMode,
                           const bool lsFirst,
                           const int maxLevelsAbove,
                           const int maxLevelsBelow,
                           const double vpTop,
                           const double vpBottom,
                           const int baseMultiplier)""")),
         r"""string PipelineGeometryKey(const SModeConfig &config,
                           const double centerPrice,
                           const double &stepSizes[],
                           const int stepSizeCount,
                           const ENUM_LEVEL_STEP_MODE stepMode,
                           const ENUM_CLASSIFY_MODE classifyMode,
                           const bool lsFirst,
                           const int maxLevelsAbove,
                           const int maxLevelsBelow,
                           const int baseMultiplier)""",
         "P-VIEW-05: the geometry key no longer reads the cull window"),
        (re.compile(re.escape(r"""    key += "|" + DoubleToString(vpTop, 8) + "," + DoubleToString(vpBottom, 8);
""")),
         "",
         "P-VIEW-05: the key line for the cull window is gone"),
        (re.compile(re.escape(r"""                                       maxLevelsBelow, vpTop, vpBottom,
""")),
         r"""                                       maxLevelsBelow,
""",
         "P-VIEW-05: the key call no longer passes the cull window"),
        (re.compile(re.escape(r"""SPipelineResult ExecutePipeline(
    const SModeConfig &config,
    const double centerPrice,
    const double &stepSizes[],
    const int stepSizeCount,
    const ENUM_LEVEL_STEP_MODE stepMode,
    const ENUM_CLASSIFY_MODE classifyMode,
    const bool lsFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const double vpTop,
    const double vpBottom,
    const int buildStage)""")),
         r"""SPipelineResult ExecutePipeline(
    const SModeConfig &config,
    const double centerPrice,
    const double &stepSizes[],
    const int stepSizeCount,
    const ENUM_LEVEL_STEP_MODE stepMode,
    const ENUM_CLASSIFY_MODE classifyMode,
    const bool lsFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const int buildStage)""",
         "P-VIEW-05: ExecutePipeline no longer takes a cull window"),
        (re.compile(re.escape(r"""        BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
""")),
         r"""        BuildZonesAndLines(classified, classifiedCount, config,
""",
         "P-VIEW-05: the build call no longer passes the cull window"),
        (re.compile(re.escape(r"""    if(buildStage == BUILD_STAGE_LINES) {
        RenderTriggerLines(lines, result.lineCount, config, true, false, vpTop, vpBottom);
    } else if(buildStage == BUILD_STAGE_ZONES) {
        RenderZones(zones, result.zoneCount, config, vpTop, vpBottom);
    } else if(buildStage == BUILD_STAGE_LABELS) {
        RenderTriggerLines(lines, result.lineCount, config, false, true, vpTop, vpBottom);
        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    } else {
        RenderZones(zones, result.zoneCount, config, vpTop, vpBottom);
        RenderTriggerLines(lines, result.lineCount, config, true, true, vpTop, vpBottom);

        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    }""")),
         r"""    if(buildStage == BUILD_STAGE_LINES) {
        RenderTriggerLines(lines, result.lineCount, config, true, false);
    } else if(buildStage == BUILD_STAGE_ZONES) {
        RenderZones(zones, result.zoneCount, config);
    } else if(buildStage == BUILD_STAGE_LABELS) {
        RenderTriggerLines(lines, result.lineCount, config, false, true);
        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    } else {
        RenderZones(zones, result.zoneCount, config);
        RenderTriggerLines(lines, result.lineCount, config, true, true);

        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    }""",
         "P-VIEW-05: the stage renders no longer pass the cull window"),
        (re.compile(re.escape(r"""        string shape = IntegerToString(result.lineCount) + ":" + IntegerToString(result.zoneCount) + ":" +
                       DoubleToString(vpTop - vpBottom, GetCachedDigits());""")),
         r"""        string shape = IntegerToString(result.lineCount) + ":" + IntegerToString(result.zoneCount);
""",
         "P-VIEW-05: the view census no longer keys on the window height"),
        (re.compile(re.escape(r"""                  " win=", DoubleToString(vpBottom, GetCachedDigits()), "..", DoubleToString(vpTop, GetCachedDigits()),
""")),
         "",
         "P-VIEW-05: the view census no longer prints the window"),
        (re.compile(re.escape(r"""            if(stepSig != s_lastStepSig && !g_s1DragLive && !g_customPriceLineDragging)
""")),
         r"""            if(stepSig != s_lastStepSig && g_initialized
               && !g_s1DragLive && !g_customPriceLineDragging)""",
         "P-PERF-108: the foreign-step latch must not fire on a transient ladder"),
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
        # P-PERF-104 (2026-10-16) - THE RETIRED MARKER NAMESPACE IS ONE PREFIX
        # WIPE. The old loop walked every chart object by index (~1200 calls at
        # ~3ms on the live terminal) to find a namespace nothing recreates
        # (P-TH3-DISC), twice per timeframe switch - the ledger charged the
        # teardown side `knot=687ms`. The delete set is identical: the loop's
        # `StringFind(nm, prefix) == 0` IS ObjectsDeleteAll's documented match.
        (re.compile(
            r'void TH3PivotMarkersClear\(\)\n\{\n'
            r'    for\(int i = ObjectsTotal\(0, -1, -1\) - 1; i >= 0; i--\)\n'
            r'    \{\n'
            r'        string nm = ObjectName\(0, i, -1, -1\);\n'
            r'        if\(StringFind\(nm, TH3_P6_PREFIX\) == 0\) ObjectDelete\(0, nm\);\n'
            r'    \}\n'
            r'\}\n'),
         'void TH3PivotMarkersClear()\n'
         '{\n'
         '    ObjectsDeleteAll(0, TH3_P6_PREFIX, -1, -1);\n'
         '}\n',
         "P-PERF-104: the retired marker namespace is one prefix wipe"),
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
    "BaseKnotTool.mqh": [
        # P-MT5-SELKEEP (2026-10-23) - THE BOX KEEPS ITS SELECTION ACROSS OUR OWN
        # WRITES. Reported: «بیس نات چرا سلکت بودنش خودکار بسته میشه هی». MT4
        # keeps a rectangle highlighted while a program writes its properties;
        # MT5 drops OBJPROP_SELECTED on the write, so the 500 ms pump (plus every
        # drag step and TF switch) handed the user a box that let go of itself
        # twice a second - and its four corner markers (they ARE the resize
        # handles) went with it. Two halves, both this project's own law: the two
        # property writes read first (never write what would not change), and the
        # selection is read before them and put back only if OUR OWN write was
        # what dropped it - a click that walked away deselects before this
        # function runs, so it is never re-selected. The MT4 text this replaces
        # is its unconditional pair of ObjectSetInteger calls.
        (re.compile(
            r'   long tfMask = BaseKnotTFMask\(tfMin\);\n'
            r'   ObjectSetInteger\(0, box, OBJPROP_TIMEFRAMES, tfMask\);\n'
            r'   BaseKnotStyleBox\(box\);   // fill layer \+ drag handle[^\n]*\n'
            r'   ObjectSetInteger\(0, box, OBJPROP_SELECTABLE, !g_bkBoxes\[k\]\.locked\);   // lock heal[^\n]*\n'),
         '   //--- P-MT5-SELKEEP (2026-10-23) — THE BOX KEEPS ITS SELECTION ACROSS OUR OWN WRITES.\n'
         '   bool wasSel = (bool)ObjectGetInteger(0, box, OBJPROP_SELECTED);\n'
         '   if((long)ObjectGetInteger(0, box, OBJPROP_TIMEFRAMES) != tfMask)\n'
         '      ObjectSetInteger(0, box, OBJPROP_TIMEFRAMES, tfMask);\n'
         '   BaseKnotStyleBox(box);   // fill layer + drag handle — the VISIBLE border is the 4 edges below\n'
         '   bool wantSel = !g_bkBoxes[k].locked;   // lock heal: handle follows the registry\n'
         '   if((bool)ObjectGetInteger(0, box, OBJPROP_SELECTABLE) != wantSel)\n'
         '      ObjectSetInteger(0, box, OBJPROP_SELECTABLE, wantSel);\n'
         '   if(wasSel && wantSel && !(bool)ObjectGetInteger(0, box, OBJPROP_SELECTED))\n'
         '      ObjectSetInteger(0, box, OBJPROP_SELECTED, true);\n',
         "MT5 drops OBJPROP_SELECTED on any property write; keep the box's selection"),
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
