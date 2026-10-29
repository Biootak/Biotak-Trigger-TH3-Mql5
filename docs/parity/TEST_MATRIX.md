# TEST MATRIX

Every row states **what the test actually proves** and **what it does not**. A test
that cannot distinguish "correct" from "plausible" is labelled as such.

Types:
* **BUILD** — compile + load fact.
* **STATIC** — source-structure invariant, checked by script.
* **NUMERIC** — formula replayed on numbers from the source constants.
* **DIFF** — cross-tree line/symbol/call comparison.
* **RUNTIME (manual)** — requires a human clicking the chart. **None were executed.**

---

## 1. Build / load

| ID | Type | Command | Proves | Does not prove |
|---|---|---|---|---|
| B1 | BUILD | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-reload.ps1` | both entries compile (`0 errors, 0 warnings`) **and** the terminal restarted onto the new `.ex5` | any behaviour. A compile is not a reload, and neither is a test. |
| B2 | BUILD | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -NoRestart` | the Full entry builds alone | the Lite entry |
| B3 | BUILD | same, with `-Compiler "C:\Program Files (x86)\RoboForex MT4 Terminal\metaeditor.exe"` | the MT4 twin still compiles | that the two trees agree behaviourally |

Last result: B1 green twice during the session (after DEL4+PRESENT-01, and after the
caption/BASE-01 port). `Biotak Trigger TH3.ex5` 2 623 654 → 2 623 6xx bytes,
`Biotak Trigger TH3 Lite.ex5` 991 744 → 991 814 bytes.

---

## 2. Structural / static

| ID | Type | Command | Proves | Does not prove |
|---|---|---|---|---|
| S1 | STATIC | `python tools/check-pp-balance.py <one file>` | `#if/#ifdef` depth returns to 0 — no unclosed block | that the guarded code is correct |
| S2 | STATIC | `python tools/bughunt/dead-locals.py` | no local is written and never read | that the *read* locals are used correctly |
| S3 | STATIC | `python tools/parity/caption-latch-check.py` | exactly one writer of `TH3InfoOffAdd`, exactly one caller of `TH3InfoFamilyDismiss`, and every caption paint path either asks `TH3InfoOff` or is on a declared allow-list with a named guarded owner | that the latch is *reached* at runtime for a given user gesture. It proves the code **cannot** repaint a dismissed readout, not that a dismissal is triggered. |
| S4 | STATIC (grep) | `Select-String -Pattern "TH3NodeStepAt|TH3MacroSpanStep"` | both had exactly one occurrence (their definition) before deletion — zero callers | that nothing referenced them *by string* (it did not: they are not exposed) |

Last results: S1 `final depth = 0` on `TH3Renderer.mqh`, `TH3Pivots.mqh`,
`TH3Tool.mqh`. S2 `DEAD LOCALS: 0`. S3 `OK: one latch writer, one dismissal caller,
every paint path asks.` S4 zero callers confirmed in both trees.

---

## 3. Numeric

| ID | Type | Command | Proves | Does not prove |
|---|---|---|---|---|
| N1 | NUMERIC | `python tools/research/base_step_parity.py` | with the 8 retrace states **parsed from `TH3RetraceQ` in the MQL source**, the retired rewrite could shrink a typed base to 20 %–67 % of its value before it reached `TH3LockedStep`; the 1:1 rule holds on every row | the result on a *specific* live pattern (that needs the pattern's real CD/BC numbers and rung) |
| N2 | NUMERIC | `python tools/research/th3_step_numbers.py` | the TH3 movement-step formula on real EURUSD bars | the ABCD master step (different formula) |
| N3 | NUMERIC | `python tools/research/parity_numbers.py` | Pine TRex vs ours on the ATR ladder | the caption or the base |
| N4 | NUMERIC | `python tools/research/series_sync_parity.py` | **both** histories of `CompatRefreshChartData()`'s sync state machine — the one that shipped and the one that now ships — replayed tick by tick against a terminal whose arrays are always MT4 truth, grading every slot `OK` / `SHORT(n)` / `TORN` / `SHIFTED(n)` | that this terminal actually produced the triggering event (it argues reachability from the MT5 API contract, not from a captured log), and nothing above the layer: a correct series can still feed a wrong formula |

N1 output (session record):

```
typed   closed    rung     | MT5 BEFORE (adopted)     | MT5/MT4 AFTER (1:1)
30.00   10.00     10.00    | 10.00    3       -66.7   | 30.00    1       0.0
30.00   15.00     15.00    | 15.00    2       -50.0   | 30.00    1       0.0
24.00   12.00     10.00    | 12.00    2       -50.0   | 24.00    1       0.0
40.00   20.00     18.00    | 20.00    2       -50.0   | 40.00    1       0.0
50.00   10.00     12.00    | 10.00    5       -80.0   | 50.00    1       0.0
20.00   20.00     20.00    | 20.00    1       0.0     | 20.00    1       0.0
```

N4 output (session record, 2026-10-28 — `BEFORE` = the code that shipped until this
session, `AFTER` = P-MT5-SERIES-01/-01b as now written):

```
=== S1  attach, then a new bar 40 ms later ===
attach: full sync          full-copy+live[0] -> OK    full-copy+live[0] -> OK
new bar @40ms              hold (throttle)+live[0] -> TORN   shift+live[0] -> OK    <== DIVERGES
retry @600ms               shift+live[0] -> OK        steady+live[0] -> OK

=== S2  the terminal adds one older bar ===
attach: full sync (complete) full-copy+live[0] -> OK    full-copy+live[0] -> OK
history +1 older bar @1000ms shift+live[0] -> SHIFTED(50) full-copy+live[0] -> OK   <== DIVERGES
retry @1600ms              steady+live[0] -> SHIFTED(50) steady+live[0] -> OK        <== DIVERGES
the next real new bar      shift+live[0] -> SHIFTED(50) shift+live[0] -> OK          <== DIVERGES

=== S3  steady state, 12 bars (control) ===
12 consecutive new bars    shift+live[0] -> OK        shift+live[0] -> OK

=== S4  a 1-bar-at-a-time backfill ===
4 history appends (100ms apart) hold (throttle)+live[0] -> SHIFTED(30) hold (throttle) -> SHORT(3)  <== DIVERGES
throttle released          full-copy+live[0] -> OK    full-copy+live[0] -> OK
```

Read the three verdicts as the harness defines them: **TORN** = index 0 carries the new bar's
High/Low/Close and the old bar's Time/Open (MT5-PAR-014); **SHIFTED** = `Time[i]` is the wrong
*bar* for that index and the error never heals, because the state machine only re-syncs on the
next count change (MT5-PAR-013); **SHORT** = `Bars` lags the chart, which is the honest residual
of the fix — a bounded, self-healing lag the replay shows in place of the permanent mis-map, and
the reason `SHORT` is listed as a divergence instead of being claimed as parity. S3 is the
control: the common path is untouched.

---

## 4. Cross-tree

| ID | Type | Command | Proves | Does not prove |
|---|---|---|---|---|
| D1 | DIFF | `python tools/parity/module-report.py` | per-module shared / one-sided line counts, lost symbols, extra symbols | behaviour. See inventory §4 for the ways it can be GREEN and still wrong. |
| D2 | DIFF | `python tools/parity/module-report.py --only <basename>` | one module plus its bad-line listing | split modules that MT4 ships as `_A`/`_B` — use the MT5 basename |
| D3 | DIFF | `python tools/parity/wiring-report.py` | candidate missing/argument-changed calls | ground truth: it has confirmed false positives (inventory §4.1) |

Baseline → after:

| Metric | Start | After |
|---|---|---|
| RED modules | 5 | 3 |
| GREEN modules | 83 | 85 |
| `TH3Renderer.mqh` bad lines | 90 | **0** |
| `TH3Pivots.mqh` bad lines | 17 | **0** |
| `TH3Tool.mqh` bad lines | 164 | 164 |
| `EventHandlers.mqh` bad lines | 91 | 91 |
| `DrawStrip.mqh` bad lines | 65 | 65 |
| Wiring: shared functions | 2704 | 2704 |
| Wiring: functions with a missing MT4 call | 42 | 38 |
| Wiring: drift rows | 361 | 348 |

---

## 5. Runtime (manual, NOT EXECUTED)

These are the tests that would turn the DEL4 fix from "structurally proven" into
"behaviourally proven". None were run; there is no GUI driver, and the running chart
carried no live ABCD pattern (`objs=37`, i.e. one horizontal line and 36 bitmap
labels) so the caption did not even exist to delete.

| ID | Type | Steps | Expected | Status |
|---|---|---|---|---|
| R1 | RUNTIME | draw an ABCD, wait for the caption; click the caption plate; press Delete | caption rows + plate disappear; A/B/C/D points, legs, ladder targets and zones remain | **not run** |
| R2 | RUNTIME | after R1, change timeframe away and back (forces `OnInit` + `TH3RestorePatternsFromChart`) | caption stays gone for that base | **not run** |
| R3 | RUNTIME | after R1, wait one `inpModeLabelDuration` cycle | nothing reappears; the 250 ms heal net does not resurrect it | **not run** |
| R4 | RUNTIME | after R1, delete a `_Point_A` | the **whole** family leaves (the caption carve-out must not have swallowed the point path) | **not run** |
| R5 | RUNTIME | draw a new ABCD after R1 | the new base gets its own caption normally | **not run** |
| R6 | RUNTIME | type a base of 30 pips with a CD leg whose step is ~10 pips; read `TH3LOG ... pb=`, `R=`, `step=` | `pb` equals the typed 30; `q` may report `ret 3`; `step` is derived from the unified equation, **not** forced to 10 | **not run** |
| R7 | RUNTIME | click *on* the caption plate while the ABCD tool session is armed | no pivot is placed (plate now consumes the click, as MT4 already does) | **not run** |
| R8 | RUNTIME | drag a leg-meter handle: an end, then the middle, then the body | the line follows the hand, the selection face survives the drag, the release sticks; on MT5 no rings are drawn (P-LM-27) | **not run** |
| R9 | RUNTIME | press `M` with a pattern selected; open `Files\` CSV | the row's `Mother_Pips` equals the typed base and `Step_Mother` equals the component the ladder drew (MT5-PAR-010) | **not run** |
| R10 | RUNTIME | press `K` with a knot selected; list the sample folder | one folder per press: `shot.png` + the 38-key `sample.txt`, filed the way `tools/bk-shot-sync.js --list` expects (MT5-PAR-011) | **not run** |
| R11 | RUNTIME | on a chart with the ladder drawn, watch it **through one genuine bar open** (no interaction) and compare the level lines/zones before and after the open | nothing jumps by one bar: the lines hold their price, the zone's right edge lands on the new bar's time, and the caption's pip distances change only by the tick. Would close the MT5-PAR-013 *normal* path (the shift on a real new bar). | **not run** |
| R12 | RUNTIME | attach on a chart whose history is still downloading (open a fresh TF with a long history, or restart onto a cold chart) and watch the log/`Bars` until the download seals, then let one bar open | after the download finishes the series is aligned: the oldest bar the caption reports and `Time[Bars-1]` agree, and the *first* new bar after the seal does not step the ladder by one. Would exercise the exact MT5-PAR-013 trigger (`+1` count from the oldest end) that the replay only argues. | **not run** |
| R13 | RUNTIME | attach (or restart onto) a chart **within ~500 ms of a bar open** on a 1-minute TF and read the first painted frame | the first frame is coherent — a zone whose end edge and price come from the same bar, no line drawn at the previous bar's close. Would close MT5-PAR-014, whose window is a full-copy stamp followed by a bar open inside 500 ms. (An ordinary TF switch is NOT a trigger: the indicator reinits on `REASON_CHARTCHANGE` and the throttle resets — the timeframe-**lock** toggle is the surviving variant, since it moves `Period()` without a reload.) | **not run** |
| R14 | RUNTIME | leave a chart running across two or three bar opens on a TF whose history is at the terminal's bar limit, and compare `Bars` before/after each open (the `TH3LOG` line or a one-shot `Print(Bars, Time[0])` in a debug build) | `Bars` rises by exactly one per bar open and `Time[0]` advances. If `Bars` ever stayed constant while `Time[0]` moved, the count-keyed re-sync would skip a shift and MT5-PAR-014 reopens from the other side — this is the witness the documentation alone cannot supply | **not run** |

R11–R14 were added 2026-10-28 with `P-MT5-SERIES-01`/`-01b` and its independent review. They are the difference between
**FIXED (numeric replay)** and **verified**: N4 proves the state machine's two histories on
synthetic terminals, and cannot show that this terminal produced the event.

R8–R10 were added on 2026-10-28 with the defects they would close. R9 and R10 are the
only rows that touch MT5-PAR-010/011; until they run those two fixes are structural.

Manual confirmation hook for R1–R3: the dismissal prints exactly one line

```
TH3CAP dismissed <base> st=<epoch>
```

and a resurrection would show the existing heal line

```
TH3CAP healed <base> st=<epoch> rows=<n> masked=<0|1> plate=<0|1>
```

So a "it came back" report has a number to read rather than a description.

---

## 6. Why the MT5 Strategy Tester is not this harness

The programme asks that every test type be recorded **with its own limits**. The tester was
considered for the runtime rows and deliberately not used, because on this indicator its
limits cancel the very things R1–R14 have to show:

* **Graphical objects do not exist the way they do live.** In a non-visual run there is no
  chart to hold them: no `OBJ_RECTANGLE_LABEL` caption plate to click, no `CHARTEVENT_OBJECT_DELETE`
  to receive, no rectangle band to measure. R1–R5, R7 and R8 are all object-and-mouse tests,
  so a tester pass over them would be a pass over nothing.
* **Indicator calculation depends on the run mode and on which buffers are requested.** The
  modelled tick stream, `OnCalculate`'s arrival pattern and the history available to the
  indicator all differ from a live chart. That is precisely the surface MT5-PAR-013/014 sit on
  — a state machine driven by *when the terminal hands over a new count* — so a tester result
  could neither reproduce nor refute them. A green tester run would be an artefact of the
  harness, not evidence about the chart.
* **No user events.** The tester feeds prices, not clicks, keys or drags, so the `M`/`K` rows
  (R9/R10) and the leg-measure drag (R8) are out of reach by construction.

What the tester CAN do, later and in its own commit: grade a *numeric* series against replayed
history (the ladder's price levels per bar), which is a Phase 3 §F job, not a parity job. Until
then: the tests recorded above are static, numeric-replay and cross-tree; the behavioural
verdicts are the live chart's, and rows R1–R14 are the honest list of what has not been said
about them.
