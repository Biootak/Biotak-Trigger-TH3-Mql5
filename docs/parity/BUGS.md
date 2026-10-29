# BUG REGISTER

Status vocabulary:

* **FIXED (static)** — the defect is proven gone by a script-checked structural
  invariant and both entries build. **Runtime confirmation is still outstanding.**
* **FIXED (numeric)** — a formula defect is reproduced and re-evaluated on numbers.
* **OPEN** — not fixed. Either unexamined or examined and deliberately deferred.
* **EXPLAINED / UNVERIFIED** — a divergence has a defensible platform reason, but the
  behaviour was not observed. Not the same as "fine".
* **REJECTED** — investigated, concluded *not* a defect. Recorded so it is not
  re-investigated from scratch.

---

## MT5-PAR-001 — deleting the caption destroyed the whole ABCD pattern

| | |
|---|---|
| **Severity** | high — data loss from a display gesture |
| **Status** | **FIXED (static)**; runtime pending (R1–R5) |
| **Symptom (MT4's report, still true here)** | «اینو حذف میزنم حذف نمیشه به درستی» — the AB=CD caption would not go away when deleted. On MT5 the opposite happened: the delete took the pattern with it. |

**MT4 reference.** `Biotak/TH3/TH3Renderer_A.mqh:604-679` (`P-TH3-DEL4`,
2026-10-24) and `Biotak/TH3Tool_C.mqh:1430`. MT4's rule: a hand-delete of a caption
member **dismisses the readout** — rows and plate go, the pattern, its ladder and its
zones stay, and no later pass brings the readout back for that base. A new pattern is
a new base and gets its own caption; that is the way back.

**MT5 root cause.** Three independent facts, all in MT5's source:

1. `TH3ROPlateAt` created the plate with `OBJPROP_SELECTABLE = false`
   (`Biotak/TH3/TH3Renderer.mqh:239` before the fix), so the terminal could never
   name it — neither the Delete key nor right-click → Delete reached the handler.
2. The delete handler had **no caption branch at all**. `P-MT5-TH3DEL`
   (`Biotak/TH3Tool.mqh:4803`, 2026-10-21) had removed MT4's `P-TH3-DEL3` guard and
   replaced every delete with `TH3FamilyDeleteAll(baseName)`, deliberately, because
   MT5's compat layer swallows our own object events. That reasoning is **correct**
   for the platform and was left in place — see DECISIONS D3.
3. `TH3InfoFamilyDraw` / `Verify` / `SetVisible` rebuilt the family on the next
   pattern pass, so even a successful drop would not have persisted.

`P-TH3-DEL4` is dated 2026-10-24; `P-MT5-TH3DEL` is dated 2026-10-21. MT5 was three
days stale on this rule.

**Fix applied**

* `Biotak/TH3/TH3Renderer.mqh` — the latch family ported from MT4: `TH3_INFO_OFF_MAX`
  (ring of 8), `g_th3InfoOff[]`, `g_th3InfoOffN`, `TH3InfoOff`, `TH3InfoOffAdd`,
  `TH3InfoRowsLit`, plus `TH3InfoFamilyDismiss` and `TH3InfoOnMemberDelete`.
* Guards added at the head of every path that can paint the family:
  `TH3InfoFamilySetVisible`, `TH3InfoFamilyVerify`, `TH3InfoVisitArm`,
  `TH3InfoCaptionHeal`, `TH3InfoFamilyDraw`.
* `Biotak/TH3Tool.mqh` — the delete branch asks first:
  `if(TH3IsInfoLabelName(sparam) && TH3FamilyAnchorsAlive(baseName)) { TH3InfoOnMemberDelete(sparam, baseName); return; }`
  Every other door still takes MT5's whole-family rule.

**Verification**

* `tools/parity/caption-latch-check.py` → `OK: one latch writer, one dismissal
  caller, every paint path asks.` The allow-listed exception is
  `TH3InfoFamilyPlateGrow`, reachable only from `TH3InfoFamilySetVisible` and
  `TH3InfoFamilyVerify`, both guarded.
* Both entries build `0 errors, 0 warnings`; terminal reloaded.
* **Not verified:** that a click on the plate actually produces the delete. See
  TEST_MATRIX R1–R5.

**Residual risk.** `TH3InfoOnMemberDelete` also requires `TH3InfoRowsLit(base)`. If a
future path drops the plate *without* masking the rows first, a hand delete would be
misread as our own maintenance and the readout would not be dismissed. MT4 carries
the identical discriminator, so this is parity, not a new hazard — but it is the
assumption to check first if R1 fails.

---

## MT5-PAR-002 — the caption plate was not selectable, so it could not be deleted

| | |
|---|---|
| **Severity** | high (this is the mechanism behind PAR-001) |
| **Status** | **FIXED (static)** |

MT4 `Biotak/TH3/TH3Renderer_A.mqh:218-240` creates the plate with
`OBJPROP_SELECTABLE = true` and re-owns it:

```mql5
if(!(bool)ObjectGetInteger(0, plate, OBJPROP_SELECTABLE))
    ObjectSetInteger(0, plate, OBJPROP_SELECTABLE, true);
```

MT5 had `false` and no re-own guard, so even a chart carrying a plate born from an
older build would never become deletable.

**Fix.** `Biotak/TH3/TH3Renderer.mqh` `TH3ROPlateAt`: creation flag set to `true`,
plus MT4's guarded re-own (one read, one write only on a chart that needs it — the
perf law's "never write a property you would not change" is preserved).

**Verification.** Source parity with MT4 at the same symbol; `module-report.py` no
longer flags this symbol. Runtime: R1.

---

## MT5-PAR-003 — the hand-typed base was silently rewritten by the retrace reading

| | |
|---|---|
| **Severity** | high — every ladder target, mid and step is derived from this number |
| **Status** | **FIXED (numeric + static)**; live-pattern confirmation pending (R6) |

**MT4 reference.** `Biotak/TH3/TH3Renderer_B.mqh:73-125` (`P-TH3-BASE-01`,
2026-10-24): *"THE TYPED NUMBER IS THE BASE, 1:1 … the base the hand typed is the
base the formula uses, and the retrace state is still measured and reported (`ret
4/3` in the log) as a READING."*

**MT5 root cause.** `Biotak/TH3/TH3Renderer.mqh` `DrawABCDPattern` adopted the
candidate:

```mql5
double pbRaw = motherSize;
double pbStep = pbRaw;
...
if(TH3RetraceBestStep(pbRaw, retRef, seedRung, bS, bQ, bI) && bS > 0)
{
    pbStep = bS;                    // <-- the instruction was replaced by a guess
    retHow = StringFormat("ret %s", TH3RetraceQName(bI));
}
```

`TH3RetraceBestStep` scores eight candidates `S = R / q` for `q ∈ {1/3, 2/3, 1, 4/3,
5/3, 2, 3, 5}` against the closed CD step (60 %) and the owner TF's rung (40 %). When
the market's CD leg is a third of the typed base, the winner is `S = R/3` — the
trader's number, divided by three, without a word on the chart. This is exactly the
`/3` that `P-TH3-BASE-01` retired one layer up; it had survived here.

**Fix.** `pbRaw = baseSize; pbStep = pbRaw;` and `retHow` is set as a reading only.
Also ported MT4's `seedHow` format (`base=` + `TH3StepPatternComponent(...)`, not
`mom=` + raw `CD_Distance`), so the caption and the log describe the same number the
formula used.

**Verification.** `tools/research/base_step_parity.py` parses the eight `q` values
out of `TH3RetraceQ` in the MQL source and replays the scoring:

```
typed   closed    rung     | MT5 BEFORE (adopted)     | MT5/MT4 AFTER (1:1)
30.00   10.00     10.00    | 10.00    3       -66.7   | 30.00    1       0.0
50.00   10.00     12.00    | 10.00    5       -80.0   | 50.00    1       0.0
```

Worst case on those rows: the ladder was built on **20 %** of the typed base.
`module-report.py --only TH3Renderer.mqh` → `BAD= 0`.

**Not verified:** the same numbers on a live pattern. Needs a drawn ABCD and a read of
the `TH3LOG` line (R6).

---

## MT5-PAR-004 — the caption and the pivot badge still spoke the retired "Mother" vocabulary

| | |
|---|---|
| **Severity** | medium — user-visible text that describes a concept the formula no longer has |
| **Status** | **FIXED (static)** |

MT4 renamed the readout under the same `P-TH3-BASE-01` patch. MT5 still printed:

| Row | MT5 before | MT4 (now MT5) |
|---|---|---|
| base | `Mother: none` / `Mother hand 30.0p` | `Base 30.0p \| Pattern 10.0p \| Step 10.0p` |
| calc | `pattern 10.0p rung 12.0p uni 10.0p` | `rung 12.0p \| closed 10.0p` |
| lock | `base 30.0p LOCKED final 10.0p proved` | `lock LOCKED \| proved` |
| live | `… \| momleg 0.33` | `… \| baseleg 0.33` |
| pivot badge | `[ H1 Mother Pivot \| 8.7p \| FRESH ]` | `[ H1 Base \| 8.7p \| FRESH ]` |

Beyond the vocabulary, the old `lock` row printed the typed base next to the
*rewritten* final step, so the caption itself showed PAR-003 happening.

**Fix.** Rows, labels, the `mlMotherSize` → `mlBaseLeg` rename (5 sites, all local to
`DrawABCDPattern`) and the badge string ported from MT4.

**Verification.** `module-report.py --only TH3Renderer.mqh`: `BAD= 0`,
`GREEN — IDENTICAL to MT4 modulo declared platform idioms`. Runtime: R6.

---

## MT5-PAR-005 — two dead `/3` step readers still shipped in `TH3Pivots.mqh`

| | |
|---|---|
| **Severity** | low — unreachable code |
| **Status** | **FIXED (static)** |

`TH3NodeStepAt` and `TH3MacroSpanStep` were defined at
`Biotak/TH3/TH3Pivots.mqh:1670` and `:1709` with **zero callers** (grep over
`Biotak/**/*.mqh`, both entries). MT4 had already deleted them under
`P-TH3-BASE-02` (2026-10-24) with the note *"They were the last place a step could be
built by dividing, so they go with the division they carried."*

**Fix.** Deleted, with MT4's header explaining why. `module-report.py --only
TH3Pivots.mqh` → `BAD= 0`, `GREEN`.

**Why it is not a behaviour fix:** they were unreachable, so deleting them changes
nothing on the chart. It removes the *next* place someone would reintroduce the
division.

---

## MT5-PAR-006 — `TH3Tool.mqh` leg-measure drag layer (164 bad lines → 147, triaged)

| | |
|---|---|
| **Severity** | unknown |
| **Status** | **TRIAGED — explained, no lost behaviour; not fixed** |

MT4 streams a drag as `CHARTEVENT_MOUSE_MOVE`; MT5 reports it as
`CHARTEVENT_OBJECT_DRAG` heartbeats. `TH3Tool.mqh` carries ~12 MT5-only symbols and
most of its MT5-only lines to bridge that. `MT4-ONLY SYMBOLS (lost logic): 0`, so
nothing was *dropped* — the difference is added plumbing.

Triage finished on 2026-10-28 with `sym-diff.py --scan` (every symbol, ranked) plus
`--scan`'s SAME test, which compares **comment-free** bodies (`module-report.norm_body`).
Result: of the 18 MT5-only symbols, 12 are the drag adapter (`LEG_DRAG_*_MS`,
`LegMeasureDragFrame`, `LegMeasureOnInit/OnDeinit/OnObjectDrag`,
`LegMeasurePressFlagOn/Off`, `LegMeasureRideOne/RideTick`), 3 are the canvas seam
(`TH3ReadPatternAnchors`, `TH3PointDragApply`, `TH3LiveDragHeartbeat`/`Unlatch`), 1 is
the documented delete door (`TH3FamilyDeleteAll`, P-MT5-TH3DEL) and 2 are constants.
Symbols the detector blamed that are in fact **identical code**: `LegMeasureBoxFromAnchors`
(19 lines). Symbols with real drift, each with its own header:

- `LegMeasureHandles` (41 → 7 lines) — P-LM-27, the rings were removed **at the user's
  request** («این دایره‌ها که روش گذاشتیم بردار»). `LegMeasureHitTest` still projects the
  anchors itself, so grabbing an end, the middle and the body all still answer.
  `LegHandleAt` is consequently dead (see MT5-PAR-012).
- `LegMeasureEditMouse` / `LegMeasureDragApply` / `DragAbort` / `DragEnd` /
  `ClickFinalize` / `PressFlagOn/Off` — P-MT5-LEGSEL: MT5 drops `OBJPROP_SELECTED` on a
  programmatic write and arms its own native drag on the press edge; the flag is parked
  on the press and restored on the button-up.
- `AutoSelectBestFrequency` (13/-12) — the body is MT4's; only the READ changed (legs
  first, then the point arrows) so a canvas pattern is found at all. The leg path reads
  `_Line_AB` 0/1 and `_Line_BC` 1, exactly like MT4.
- `OnABCDMouseEvent` (+83/-144) — MT4's inline `OBJECT_DRAG` branch (smart magnet +
  re-derive) was **extracted**, not dropped: it lives in `TH3PointDragApply`, which
  carries the same 5-pip OHLC snap.
- `LegMeasureUpgradeLegacy`, `SetActiveABCDPattern`, `TH3RestorePatternsFromChart`,
  `BuildPatternNamesFromRegistry`, `TH3_ExportCurrentSample` — documented MT5-only work
  (P-PERF-114, R-RENDER-ENGINE, P-MT5-TH3DRAG) except the last, which was a real defect
  (MT5-PAR-010).

**Why it was not "fixed":** rewriting a platform adapter to look like MT4 would
produce a diff that matches and a chart that does not. It has not been behaviourally
verified, and this register does not claim it works.

**What would settle it:** drag a leg-meter handle on MT5 and compare the ride,
selection and release against MT4 frame by frame (TEST_MATRIX R8).

---

## MT5-PAR-007 — `EventHandlers.mqh` (91 bad lines → triaged)

| | |
|---|---|
| **Severity** | unknown |
| **Status** | **TRIAGED — 1 real defect found (MT5-PAR-011), rest explained** |

327 MT5-only lines vs 48 MT4-only, and **0** of them "MT4-only code with no idiom" —
i.e. no MT4 line went missing without a counterpart. `sym-diff.py --scan` attributes the
volume to `RedrawAllObjects` (+174/-30), `OnChartEventHandler` (+86/-50) and
`OnInitHandler` (+78/-29). Each removal was checked individually against MT5:

| MT4 line | MT5 answer |
|---|---|
| `BaseKnotOnChartEvent(...)` | present at `:6336`, now wrapped to time the call (`s_usKnot`) |
| `HRayOnChartEvent(...) \|\| PathOnChartEvent(...)` | present at `:6341-6344`, timed (`s_usRay`) |
| `LegMeasureEditMouse(...)` | present at `:7142` (`_legHit`) |
| `g_lockedPeriod = GetCachedPeriod()` | `g_lockedPeriod = chartPeriodForLock` (`:7081`) — deliberate: MT5's `GetCachedPeriod` honours the lock, so asking it after the flip pinned the PREVIOUS period (documented at `:7068`) |
| `BaseKnotCaptureSample()` ('K') | **MISSING — the defect, see MT5-PAR-011** |

The remaining MT5-only symbols are the knot witnesses (`BaseKnot*Witness`, `BK_TW_MAX`,
`P4InitLedgerTag`, `P4LeftoverCensus`, `DiagUs*`) — MT5 instrumentation, no behaviour.

---

## MT5-PAR-008 — `DrawStrip.mqh` (65 bad lines → triaged)

| | |
|---|---|
| **Severity** | unknown |
| **Status** | **TRIAGED — explained, no lost behaviour** |

270 MT5-only vs 218 MT4-only, but only **2** MT4-only lines, and both are the same
statement: `DSTRIP_OPEN_PRESS_MAX_MS` (10 s) replaced by `DSTRIP_OPENER_TWIN_MS` (300 ms)
under P-MT5-OPENER — MT5 reports one click per release (`COMPAT_CLICK_TWIN_MS`), MT4 two,
so a 10-second token would let one click be spent by the previous gesture.

Two big diffs were checked for lost work:

- `DrawStripClose` (+50/-33) — MT4's trailing `DrawStripSkinPurge()` is replaced by one
  `DrawStripSweepStale()` prefix sweep. P-PERF-103 measured the purge finding **nothing**
  after the sweep (`d0=0 d1=0 d2=0` on every sample) while its ~270 `ObjectFind` misses
  cost 1.0–7.0 s. The sweep is the purge.
- `DrawStripGearObjectsPurge` (94 → 26 lines) — P-PERF-101 collapses ~330 missing-name
  probes into one `ObjectsDeleteAll(0, "PnlDrawS_G")`. It now always returns `true`
  instead of `dirty`; every call site either ignores the value or ORs it into a `dirty`
  it is already about to repaint with.

---

## MT5-PAR-009 — the parity detectors themselves produce false findings

| | |
|---|---|
| **Severity** | medium — a false finding costs a fix that is not needed |
| **Status** | **OPEN — documented, worked around** |

Two confirmed cases, both opened and read:

1. `wiring-report.py` → `TH3RestorePatternsFromChart` "missing
   `TH3InfoFamilyDelete(base)`". MT5 calls it at `Biotak/TH3Tool.mqh:1716` **and**
   `:1735`, with that exact text. The restore path already matches MT4 semantically.
2. `wiring-report.py` → `DrawABCDPattern` "missing
   `TH3StepPatternComponent(CD_Distance, uniRatio)`" **after** it was added at
   `Biotak/TH3/TH3Renderer.mqh:1273` — the call is a continuation-line argument.

Not fixed: the report is a diagnostic, and changing its parser mid-audit would
invalidate the before/after numbers. Recorded so the next reader does not chase them.

A **third** class was added on 2026-10-28: `module-report.py` blames a symbol when its
lines drift, even when the body is identical. `Biotak/TH3Tool.mqh::LegMeasureBoxFromAnchors`
was listed among the "mt4-only lines with no declared idiom"; the body is 19 identical
lines. Use `sym-diff.py --scan` (SAME = comment-free body equality) before believing a
line count.

---

## MT5-PAR-010 — the dataset export still wrote the retired `/3` base rule

| | |
|---|---|
| **Severity** | medium — the exported sample disagreed with the chart it described |
| **Status** | **FIXED (2026-10-28)**, `Biotak/TH3Tool.mqh::TH3_ExportCurrentSample` |
| **Test** | structural (`sym-diff.py`), numeric formula check; runtime export not run (R9) |

**Reproduction (source-level, both trees):**

```
tools/parity/sym-diff.py TH3Tool.mqh --sym TH3_ExportCurrentSample
- double baseIn      = TH3ManualBaseStep(inpTH3BaseRangePips, pip);   // MT4
+ double motherIn    = TH3ManualBaseStep(inpTH3BaseRangePips, pip);   // MT5
- double stepBase    = TH3StepBaseComponent(baseIn, rung);            // MT4
+ double stepMother  = (motherIn >= 2.5 * rung) ? (motherIn / 3.0) : motherIn;  // MT5
```

**Root cause:** MT4's `P-TH3-BASE-01` deleted the private `/3` copy from its export path
and routed both components through the formula's owners (`TH3StepBaseComponent`,
`TH3StepPatternComponent`). MT5 got the owners (R-TH3-STEP) and the renderer's half
(MT5-PAR-003) but this third copy survived, carrying its own header text: *"the dataset's
Step_Mother column could disagree with the step the chart drew"*. It did.

**Evidence it matters:** with `inpTH3BaseRangePips` ≥ 2.5 × the TF rung, the exported
`Mother_Pips`/`Step_Mother` columns were 1/3 of the value the ladder was drawn with, and
`Step_Pattern` could differ on the `k ≤ 0` edge. Every sample on disk keyed on those
columns inherits the error.

**Fix:** the two lines now call `TH3StepBaseComponent` / `TH3StepPatternComponent`, and
the four print sites use `baseIn`/`stepBase`. The CSV **column names stay**
(`Mother_Pips`, `Step_Mother`): MT4 keeps them too, because they are a stored-data
contract read by four tools by name.

**Regression risk:** export path only; the ladder, the readout and the drag do not call it.

---

## MT5-PAR-011 — the `K` key (capture the selected knot) did nothing

| | |
|---|---|
| **Severity** | medium — a whole ported feature was unreachable |
| **Status** | **FIXED (2026-10-28)**, `Biotak/EventHandlers.mqh` |
| **Test** | structural (`dead-doors.py`); key press not observed (R10) |

**Reproduction:** MT4 `EventHandlers_Router.mqh:525` has

```mql4
if((int)lparam == 75)   // 'K' — capture the selected knot as a sample
{ BaseKnotCaptureSample(); ThrottledChartRedraw(); return; }
```

MT5 had **no** `== 75` anywhere in the tree (`grep`, zero hits) while
`BaseKnotCaptureSample()` was fully ported (`Biotak/BaseKnot_Shot.mqh:363`, P-BK-124/P-BK-124b:
the shot, the 38-key sample, the receipt, the one-second flash) and `BaseKnotShotFlashTick()`
was already being called from `OnTimer` — watching a flag nothing could set.

**Root cause:** the 2026-10-27 port brought the subsystem and not its door. `dead-doors.py`
reports it as LOST DOOR: defined in MT5, zero call sites, MT4 calls it once.

**Fix:** MT4's block, verbatim, at the same place (after the `M` export handler), under the
same `#ifndef BUILD_LITE` guard.

**What is still unproven:** the capture has never been observed on MT5. The door is now
reachable; whether the shot and sample land with MT4's contents is TEST_MATRIX R10.

---

## MT5-PAR-012 — MT5 lost the "why did this frame overrun" decoder

| | |
|---|---|
| **Severity** | low — diagnostics only, no chart behaviour |
| **Status** | **OPEN — deliberately not fixed in a behaviour commit** |
| **Test** | structural (`dead-doors.py`) |

MT4 maintains `g_p3ArmMask` (one bit per pending-work flag, `EventHandlers_Calc.mqh:931`)
and prints `" why=" + PerfArmWhy(g_p3ArmMask)` on the `OnCalculate` overrun line. MT5 has
neither: no `g_p3ArmMask` in the tree, no `why=` in its overrun line (`EventHandlers.mqh:4779`),
so `PerfArmWhy` is dead.

The consequence is a diagnostic one: an MT5 overrun names the phases and the `rest`, but not
the flags that armed the frame. Recorded rather than fixed, to keep this session's commit
behavioural.

---

## MT5-PAR-013 — a history download that appended ONE bar shifted the whole series onto the wrong bars

| | |
|---|---|
| **Severity** | **critical — every historical bar, permanently, silently** |
| **Status** | **FIXED (numeric replay) — runtime confirmation owed (R11/R12)** |
| **Test** | `tools/research/series_sync_parity.py` (new) |
| **Class** | Phase 3 §A series indexing / off-by-one; §D historical-vs-live consistency |

`CompatRefreshChartData()` (`MT5Compat/MQL5Compat.mqh:920-1130`) is the only thing that makes
`Time[]/Open[]/High[]/Low[]/Close[]/Bars` behave like MT4's predefined arrays. When the bar
count changed it had two ways to re-sync: shift the emulated series one slot right (cheap, no
kernel crossing) or `CopyRates` the entire history again (expensive, correct). The choice was
made on the bar **count** alone:

```mql5
if(g_seriesBars > 0 && g_seriesBars == g_seriesSyncedAt && bars == g_seriesSyncedAt + 1)
```

**A count that went up by one is not yet a new bar.** On MT5 that arithmetic has two causes:

1. the terminal opened a bar at the **newest** end — the shift is right;
2. a history download appended one bar at the **oldest** end — the shift is wrong: every slot
   moves one bar too new, so `High[0]` is the current bar *and* `High[1]` is the current bar,
   while `High[49]` now answers the bar that used to live at `High[48]`.

MT4 cannot make this distinction by accident — the terminal owns its arrays and hands them
over already aligned. The compat layer emulates that contract from an API that reports only a
count, so it had to ask a question it never asked: **did the newest bar's time move?**

**Proof (replay, not assertion).** `tools/research/series_sync_parity.py` replays the state
machine against a terminal whose arrays are always MT4 truth, and grades each slot: `OK`,
`SHORT(n)`, `TORN`, `SHIFTED(n)`. Scenario S2 (one older bar arrives 1600 ms after the last
sync, so the 500 ms throttle releases):

```
history +1 bar      shift+live[0] -> SHIFTED(50)     full-copy+live[0] -> OK      <== DIVERGES
retry @1600ms       steady+live[0] -> SHIFTED(50)    steady+live[0]   -> OK      <== DIVERGES
the next real new bar  shift      -> SHIFTED(50)     shift            -> OK      <== DIVERGES
```

`SHIFTED(50)` = all 50 historical slots point at the wrong bar. The third line is the part
that makes it critical: the state machine only re-syncs when the count changes **again**, so
a corruption from cause (2) survives every following tick and the *next* genuine new bar
re-derives its shift from the already-wrong array. The ladder targets, every `iHigh/iLow`
read, the ATR window and the zone extents are then computed one bar off, forever, with no log
line. Control S3 (steady state, 12 bars) is `OK` before **and** after — the fix does not move
the common path.

**Fix (smallest defensible, `P-MT5-SERIES-01`).** The shift precondition is now
`newBar = grewByOne && newTime > g_seriesTime[0]`, where `newTime` is the live bar time the
caller already passed (`livTime`), falling back to one `iTime` read only in the rare `+1`
branch. A `+1` whose time did not advance is a history append and falls through to the full
copy. No subsystem was rewritten; three statements and one gate.

**Not established:** that *this* terminal produced a one-bar append during this audit. The
mechanism is proven by replay and the condition is reachable on MT5 by construction (history
arrives in chunks of any size, including one); the terminal log has no line for it, which is
exactly why R11/R12 exist. This entry is **FIXED (numeric)**, not runtime-verified.

---

## MT5-PAR-014 — the first frame of a new bar was painted from two bars at once

| | |
|---|---|
| **Severity** | high — one torn bar per throttled bar-open window |
| **Status** | **FIXED (numeric replay) — runtime confirmation owed (R13)** |
| **Test** | `tools/research/series_sync_parity.py` scenario S1 |
| **Class** | Phase 3 §A / §D; surfaced by the same gate as PAR-013 |

The shift lived **inside** `if(due)`, where `due` is the 500 ms `COMPAT_FULL_SYNC_MIN_MS`
floor. That floor exists to stop a history download turning every tick into a full
`CopyRates`, and it correctly gates the *copy* — but it was gating the *shift* too, and the
shift is O(bars) scalar moves with zero kernel crossings. When the throttle held on a genuine
new bar, control fell past the whole sync block into the foot block, which unconditionally
wrote this tick's High/Low/Close into index 0 while that slot still carried the **previous**
bar's `Time` and `Open`:

```
new bar @40ms   hold (throttle)+live[0] -> TORN     shift+live[0] -> OK     <== DIVERGES
```

One slot speaking two bars. `ZoneFactory` reads `Time[0]` for the zone's end edge and the
shared code reads `Close[0]` for `currentPrice`, so the first frame after that bar opened was
built from a pair that never existed on any chart. The reachable window is ~500 ms after any
count-change full copy — an **attach**, a **history append**, a **count jump** — that is then
crossed by a bar open. (The first draft of this entry said "or a timeframe switch"; the
independent review rejected it: MT5 deinitialises the indicator on `REASON_CHARTCHANGE` —
`Biotak/EventHandlers.mqh:1204-1216` documents exactly that for the sibling static — so a
fresh instance resets the throttle and a normal switch is always `due`. What does survive is
the rarer **timeframe-LOCK toggle**, which per that same comment moves `Period()` *without* a
reload.) So a defect reachable from the ordinary "flip the timeframe to load a build" gesture
is not on that list; the one that is, is attaching or restarting onto a chart a moment before a
bar opens.

**Fix (two halves, `P-MT5-SERIES-01b`).**
1. The throttle now gates the copy only: `if(newBar || due)` enters the sync block, the shift
   branch runs on every genuine new bar regardless of the floor, and `s_lastFullSyncMs` was
   removed from the shift branch (it stamps only after a successful copy, which is where R-TF-UNIT
   already put it for a reason).
2. The foot block is gated with `bars == g_seriesSyncedAt`: when a count change was **not**
   applied (throttled, or a copy that failed because history is still downloading), the arrays
   are not aligned with the count the caller just reported, so index 0 is left alone and the
   last consistent snapshot is held.

**The trade-off, stated.** Holding a snapshot makes MT5 disagree with MT4's live arrays for a
few hundred ms (`SHORT(3)` in S4's backfill: the emulated series briefly lags the terminal).
That is bounded, self-heals on the next sync, and is internally consistent — every slot still
describes the same bar it is named for. Tearing index 0 was a pair that never existed, was
silent, and every consumer of that frame made a decision on it. A stale-but-coherent bar beats
a fresh-but-fictional one.

**Residual the gate does not close (raised by the independent review, then doc-checked).**
Both halves still key the re-sync on *the count having changed at all*. A new bar that arrives
with an **unchanged** `rates_total` — a series that rolls (oldest discarded, count constant) —
would take neither branch, and the foot block would write live H/L/C over the previous bar's
Time/Open exactly as before. Whether MT5 can do that is a platform question, answered here
from the reference rather than from the code: `rates_total` is documented as "the size of the
price array **available to the indicator for calculation**"
([OnCalculate](https://www.mql5.com/en/docs/event_handlers/oncalculate)), and the terminal's
"Max bars in chart" is documented by the vendor as limiting the **initial** count, not the
grown one — "It does not limit the bar count. Rates_total does not become smaller, ever"
([forum 326512](https://www.mql5.com/en/forum/326512)), with counts exceeding `TERMINAL_MAXBARS`
reported as normal ([forum 471016](https://www.mql5.com/en/forum/471016)). So the roll case is
**not reachable through the display cap**, and no fix was made for it. It is recorded because
it is the *class*: the sync is count-keyed, so any future cause of an unchanged-count new bar
re-opens MT5-PAR-014 from the other side. R14 is the witness row.

---

## Dead functions left in place (cleanup, not parity)

`sym-diff.py --scan` + `dead-doors.py` now enumerate them. Everything below is dead on
**both** sides or superseded by a documented MT5 mechanism; none is a lost door:

| Function | Why it is dead |
|---|---|
| `LegHandleAt` | the rings were removed on MT5 (P-LM-27); MT4 still draws them |
| `DrawStripSkinPurge` | superseded by `DrawStripSweepStale`'s one prefix sweep (P-PERF-103) |
| `GetViewportBounds` | the cull window moved inline into `LevelPipeline.mqh:902-946` (P-VIEW-05) |
| `PerfArmWhy` | see MT5-PAR-012 |
| `Bars` (`MQL5Compat`) | MT5 routes function-form calls through `iBars(...)` by the platform rule |

---

## Rejected as "not a defect"

| Candidate | Why rejected |
|---|---|
| MT5's `P-MT5-TH3DEL` whole-family delete rule | Correct for the platform. MT5's compat layer swallows our own object events (`MT5Compat/MQL5Compat.mqh:1434-1441`, `:1520-1523`), so the handler only ever sees the user. MT4's `P-TH3-DEL3` guard would only ever undo the user here. **Left in place**; only the caption case was carved out. |
| `TH3FamilyAnchorsAlive` skipping the `_Line_AB`/`_Line_BC` probes under `BIOTAK_RENDER_ENGINE` | MT5-only and correct: a canvas pattern carries no leg objects, so probing them would report every healthy family as hand-broken. Declared `MT5-ONLY` in the source. |
| MT5's `No total-count gate` in `TH3InfoOrphanPlateSweep` | Matches MT4 after MT4 removed its gate; the comment explains why the gate is wrong. |
| `TH3InfoFamilyReposition` having no latch guard | It only moves objects that already exist (`TH3ROSetY` returns early when the object is gone). After a dismissal the rows and plate are deleted, so it is inert. MT4 is identical. |

### Compat-layer candidates (this pass audited `MQL5Compat.mqh` line by line)

Each of these is a place where the shim's semantics differ from MQL4's and a rule-4 "fix"
was tempting. All were checked for a **live call site** first; a divergence no code can reach
is not a defect, and "fixing" it edits a contract nobody consumes:

| Candidate | Why rejected |
|---|---|
| `MarketInfo(MODE_TIME)` → `SYMBOL_TIME` (mql4 returns a double price-scale value, mql5 an int epoch) | `MODE_TIME` has **zero** call sites in `Biotak/` or the entries — only the `#define` and the shim's own `case` (`MQL5Compat.mqh:258`, `:285`). The modes actually used are `MODE_BID`/`MODE_ASK`/`MODE_POINT` (LabelFunctions ×2, LevelPipeline ×2, UtilityFunctions ×4), each of which the shim maps correctly. |
| `iBarShift(..., exact=true)` divergence (MT5 returns `-1` for a time outside history where MT4 returns the nearest shift) | No call site in the shared modules passes `exact=true`; the 4-argument sites all pass `false`, which is the shim's own default. The untested branch is `iBarShiftCompat`'s exact path. |
| `ObjectType()` shim | No direct shared call site — object-type dispatch goes through `ObjectFind`/`ObjectSet*`. Unreachable, so unverifiable, so left alone rather than "aligned". |
| `DoubleToStr(value, digits)` with a `digits` default of 8 | MQL4 requires the argument, so no shared call omits it; the default only exists to make the shim's signature legal in MQL5. |
| `OBJPROP_RAY` → `OBJPROP_RAY_RIGHT` | Faithful: MQL4's single `RAY` property *is* the right-ray flag; MT5 split it into LEFT/RIGHT and this mapping selects the side MT4 drew. Verified against the official property tables, not from memory. |
| `WindowFirstVisibleBar()` / `WindowBarsPerChart()` returning chart-window rather than MT4 semantics | One consumer, `PnlCandleBandPx` (`BiotakPanels.mqh:5941-5962`), whose contract is a pixel band for card placement. It guards `first < 0` → `false` (caller then places the card exactly as before), clamps `bars` to the window, and skips empty price slots. A wrong reading degrades to a documented fallback, not to a wrong level. |
| Wilder ATR seed: MT5 computes from a 3000-bar `CopyRates` window (P-ATR-SYNC) where MT4 runs the recursion from the first bar | Bounded and already measured: convergence error `<1e-5` pips on the seeded value, recorded in the source and in `base_step_parity.py`'s tolerance. A genuine accepted platform difference, not an unexamined one. |
| **A new bar with an unchanged bar count** (a rolling series at the terminal's bar limit) would skip the re-sync entirely and tear index 0 — the count-keyed design seen from the other side | Raised by the independent review of the `-01` fix, then checked against the platform reference instead of answered from the code: `rates_total` is "the size of the price array available to the indicator for calculation" ([OnCalculate docs](https://www.mql5.com/en/docs/event_handlers/oncalculate)), and the vendor states that "Max bars in chart" limits the *initial* count only — "Rates_total does not become smaller, ever" ([forum 326512](https://www.mql5.com/en/forum/326512); counts above `TERMINAL_MAXBARS` reported normal in [471016](https://www.mql5.com/en/forum/471016)). Not reachable through the display cap ⇒ no code was changed. Kept as the class statement, with R14 as the runtime witness. |

**What this sweep DID find** is MT5-PAR-013/014 above — the series state machine, which is the
one part of the layer with no call-site guard to hide behind: every module in the product reads
those six arrays.
