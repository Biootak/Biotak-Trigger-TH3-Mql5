# MT4 → MT5 PARITY INVENTORY

**Session:** 2026-10-28
**MT4 reference:** `../Biotak-Trigger-TH3-mql4` @ `1a497e6 P-BK-135`
**MT5 subject:** this repository @ `369a97f` + the working-tree changes described below
**Rule applied:** MT4 is the behavioural reference. An MT5 deviation is a suspected
defect until it is explained — explained either as a *declared platform adapter*
(MT5 events/semantics genuinely differ) or as a *fix* (MT4 is wrong and MT5 is
right). "It compiles" and "the source looks the same" are not evidence.

---

## 1. What was actually compared

| Layer | Tool | What it answers | Read-only |
|---|---|---|---|
| Module line diff | `tools/parity/module-report.py` | per-module shared / one-sided / bad line counts, lost symbols, extra symbols | yes |
| Symbol body diff | `tools/parity/sym-diff.py` (`--sym`, `--scan`) | the lines of ONE function, MT4 vs MT5; `--scan` ranks every symbol and calls a body `SAME` when it is identical after comments/whitespace are stripped | yes |
| Function reachability | `tools/parity/dead-doors.py` | functions MT5 defines that nothing in MT5 calls; `MT4 calls it` ⇒ a lost door, not dead code | yes |
| Call wiring | `tools/parity/wiring-report.py` | for each shared function, which MT4 calls MT5 does not make (or makes with different arguments) | yes |
| **MQL4-series emulation state machine** | `tools/research/series_sync_parity.py` | whether `CompatRefreshChartData()` maps `Time/Open/High/Low/Close/Bars` onto the **same bar** MT4's predefined arrays name, tick by tick, through a new bar, a history append, a throttled bar-open, and a 1-bar-at-a-time backfill | yes (session 2) |
| **Compat-layer semantic audit** | manual read of `MT5Compat/MQL5Compat.mqh:561-1130` against the official MQL4/MQL5 reference, each divergence then tested for a live call site by grep | §6 — what the shim promises vs delivers, and which divergences are reachable | yes (session 2) |
| Unused locals | `tools/bughunt/dead-locals.py` | locals that are written and never read | yes |
| Preprocessor balance | `tools/check-pp-balance.py` | `#if/#ifdef` depth per file (one file per invocation) | yes |
| Compile | `tools/mt5-build.ps1`, `tools/mt5-reload.ps1` | that both entries build and the terminal is running the new bytes | no |
| Caption latch invariant | `tools/parity/caption-latch-check.py` | one latch writer, one dismissal caller, every caption paint path asks | yes |
| Base-step numbers | `tools/research/base_step_parity.py` | what the typed base becomes, before and after `P-TH3-BASE-01` | yes |

**Scope limit, stated up front:** there is no automated GUI driver for either
terminal. No test in this session *clicks* a chart. Every behavioural claim below
is either (a) a source-structure invariant checked by a script, (b) a numeric
reproduction of a formula, or (c) a build/load fact. Interactive confirmation of
the caption delete is **outstanding** and marked as such in `BUGS.md`.

---

## 2. Module inventory at session start

`module-report.py` baseline:

```
VERDICT: 5 RED, 0 YELLOW, 83 GREEN, 0 MT5-only files
```

| RED module | Bad lines | Verdict after this session |
|---|---|---|
| `Biotak/DrawStrip.mqh` | 65 | **RED — untouched, open** |
| `Biotak/EventHandlers.mqh` | 91 | **RED — untouched, open** |
| `Biotak/TH3Tool.mqh` | 164 | **RED — reduced in scope, still open** |
| `Biotak/TH3/TH3Pivots.mqh` | 17 | **GREEN** (dead `/3` readers deleted) |
| `Biotak/TH3/TH3Renderer.mqh` | 90 | **GREEN** (DEL4 + BASE-01 portraits) |

After this session:

```
VERDICT: 3 RED, 0 YELLOW, 85 GREEN, 0 MT5-only files
```

---

## 3. The three remaining RED modules — triaged 2026-10-28

These stay **RED** in `module-report.py`, and the reason is now known for every one of
them: the detector blames comment/whitespace drift and documented MT5-only work. That
is not the same statement as "the chart behaves identically" — none of the three has
been exercised at runtime (R8–R10).

### 3.1 `Biotak/TH3Tool.mqh` — 164 bad lines → 147 — TRIAGED

`MT4-ONLY SYMBOLS (lost logic): 0`. The whole diff is line-level, inside shared
functions. Two real defects were found here (MT5-PAR-003, MT5-PAR-010); the rest is
explained:

* **`LegMeasure*` (12 MT5-only symbols + most of the MT5-only lines).**
  `LEG_DRAG_FRAME_MS`, `LEG_DRAG_READ_MS`, `LEG_PRESS_HEAL_MS`, `LEG_RIDE_MS`,
  `LegMeasureDragFrame`, `LegMeasureOnInit/OnDeinit/OnObjectDrag`,
  `LegMeasurePressFlagOn/Off`, `LegMeasureRideOne/RideTick`. MT4 delivers drag as a
  continuous `CHARTEVENT_MOUSE_MOVE` stream; MT5 delivers `CHARTEVENT_OBJECT_DRAG`
  heartbeats. The module bridges the two. *Explained, unverified.*
* **`LegMeasureHandles` (41 → 7 lines).** The rings were deleted at the user's request
  (P-LM-27). `LegMeasureHitTest` still projects the anchors, so the grab targets are
  unchanged. *Explained.*
* **`OnABCDMouseEvent` (+83/-144).** MT4's inline `OBJECT_DRAG` branch (5-pip OHLC
  magnet + re-derive) is extracted into `TH3PointDragApply`, which carries the same
  snap. *Explained.*
* **`AutoSelectBestFrequency`, `BuildPatternNamesFromRegistry`,
  `SetActiveABCDPattern`, `TH3RestorePatternsFromChart`, `LegMeasureUpgradeLegacy`.**
  MT4's logic plus the canvas-aware read (`TH3ReadPatternAnchors`) and P-PERF-114's
  one-per-chart stamp. *Explained.*
* **`TH3_ExportCurrentSample`.** The one place where the drift was a live defect:
  a private `/3` base rule MT4 had already deleted. Fixed (MT5-PAR-010).

### 3.2 `Biotak/EventHandlers.mqh` — 91 bad lines — TRIAGED

327 MT5-only lines vs 48 MT4-only, and **zero** MT4-only code lines without a
counterpart. Every removed MT4 statement was located in MT5 (the router's `_bk`/`_rp`
dispatch, the leg-meter dispatch at `:7142`, the lock's `chartPeriodForLock`), except
one: `BaseKnotCaptureSample()` on the `K` key, which was simply missing (MT5-PAR-011,
fixed). The MT5-only mass is timing/instrumentation (`s_usKnot`, `s_usRay`), the knot
witnesses and the `P4*` ledgers.

### 3.3 `Biotak/DrawStrip.mqh` — 65 bad lines — TRIAGED

270 MT5-only vs 218 MT4-only, 1 engine line — but only **2** MT4-only code lines, and
both are the same statement (`DSTRIP_OPEN_PRESS_MAX_MS` → `DSTRIP_OPENER_TWIN_MS`,
P-MT5-OPENER). `DrawStripClose`'s missing `DrawStripSkinPurge()` and
`DrawStripGearObjectsPurge`'s collapse from 94 to 26 lines are both documented perf
work whose measurements are quoted in `BUGS.md` (MT5-PAR-008). No lost behaviour.

**What closed them:** `sym-diff.py --scan` for the per-symbol bodies, then a read of
each diffted hunk against the MT4 original. Runtime still not exercised (R8–R10).

---

## 4. Detector limitations found (affects how the numbers should be read)

1. **`wiring-report.py` is line-oriented and produces false positives on
   multi-line calls and on repeated identical calls.**
   Evidence: it reports `TH3RestorePatternsFromChart` as missing
   `TH3InfoFamilyDelete(base)`, but MT5 calls it twice —
   `Biotak/TH3Tool.mqh:1716` and `:1735`, both with exactly that text. It also
   reported `DrawABCDPattern` as missing `TH3StepPatternComponent(CD_Distance,
   uniRatio)` immediately after the call was added at
   `Biotak/TH3/TH3Renderer.mqh:1273` (it is a continuation-line argument, not a
   statement start).
   **Do not treat a wiring row as a finding without opening the file.**

2. **`module-report.py` compares whole function bodies.** A module can be GREEN
   while a *numeric* divergence hides inside a function whose replacement is
   line-for-line different but semantically wrong in a way the diff believes is
   "declared". The `P-TH3-BASE-01` bug survived a 90-line BAD count precisely
   because the diff saw a rewrite, not a missing call. Numbers need the numeric
   harness (`tools/research/`), not the line diff.

3. **`check-pp-balance.py` accepts one file per invocation.** A glob raises
   `OSError: Invalid argument`. Loop per file.

4. **`module-report.py` and `gap-report.py` disagree on split modules.** MT4 ships
   `TH3Renderer_A.mqh` + `TH3Renderer_B.mqh`; MT5 ships `TH3Renderer.mqh`. Use
   `module-report.py --only TH3Renderer.mqh`; `gap-report.py` answers "not on both
   sides".

5. **No cross-tree detector covers `MT5Compat/MQL5Compat.mqh`,** so the shim can
   change the meaning of every shared module while every module report stays GREEN.
   See §6 — this is where session 2's two highest-severity findings were hiding, and
   the `VERDICT: 3 RED / 85 GREEN` line did not move when they were fixed.

---

## 5. Repository state caveat

The MT5 working tree was **already dirty** when this session began: an in-progress
`BaseKnot` modularisation (`Biotak/BaseKnotTool.mqh` reduced, new
`Biotak/BaseKnot_*.mqh` files, entries and several modules touched). That work was
left intact. The changes described in `BUGS.md` are additional edits on top of it.
No `git add`/`commit` was performed in this session.

---

## 6. The compat layer as an audit unit (added session 2, 2026-10-28)

**Why it needed its own section.** `MT5Compat/MQL5Compat.mqh` is the only MT5-specific
source, and it is not a module: it is the layer that decides what every shared module's
`Time[]`, `Bars`, `Period()`, `iBarShift`, `MarketInfo`, `ObjectSet*` and `ChartRedraw`
*mean*. Cross-tree line comparison cannot see it (MT4 has no twin file), so a divergence
there is invisible to the toolkit — while sitting upstream of every number the indicator
draws. Until this pass the audit had compared 88 modules and never compared the ground they
stand on.

**What was read.** `MQL5Compat.mqh:561-1130` — the MQL4 predefined-variable shims
(`Bars/Time/Open/High/Low/Close/Volume`), the TF/minute model (`CompatTF`,
`CompatPeriodMinutes`, the `Period()` macro at the foot), `iBarShift`/`iTime`/`iHigh`/… the
`CopyRates`-backed helpers, the manual Wilder ATR engine (`:587+`), and the
`CompatRefreshChartData()` state machine — plus the object-property maps (`:1132+`,
`OBJPROP_RAY`/`TIME1`/`PRICE1`) and the string shims (`:217-236`), against the official MQL4
and MQL5 reference for each documented semantic difference (series indexing and the
EMPTY_VALUE convention, the bar-count contract, `StringTrimLeft/Right` meaning, the
`OBJPROP_RAY` split, `Bars` as a value rather than an array).

**What it found.** MT5-PAR-013 and MT5-PAR-014 (§8 of `RESULTS.md`), both in
`CompatRefreshChartData()`, both reachable from the platform rather than from a call site.

**How they were proved.** `tools/research/series_sync_parity.py` — the only harness that can
grade a *temporal* emulation without a terminal: it replays the state machine's own logic
against a synthetic terminal whose arrays are always MT4 truth, and grades every slot. Its
`BEFORE` column is the shipped-until-now code, so it doubles as the reproduction report.

**Scope limit, stated.** This pass covered the series/TF/count family and the object-API
property maps. It did **not** audit: the object-event filter (`:1434-1538`), the click dedupe
(`COMPAT_CLICK_TWIN_MS`), the frame coalescer (`CompatFrameBegin/CompatChartRedraw/
CompatFrameEnd`), `ChartSendEvent`, or the `ObjectsTotal/ObjectName/ObjectFind` rename
helpers. Those carry their own platform semantics and are the next unit of work — the event
layer is where a *UI* parity defect would hide, the same way the series layer was where a
*numeric* one did.

**The lesson for the toolkit.** A parity claim about "the modules" is a parity claim about a
layer whose contract nothing was checking. Any future `module-report` GREEN should be read as
"these files agree, given that the shim still means what §6 says it means".
