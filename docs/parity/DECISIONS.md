# DECISIONS

Judgement calls made during the 2026-10-28 parity session, with the alternative that
was rejected and why. Ordered by how much they constrain later work.

---

## D1 — MT4 is the reference; a newer MT4 patch beats an older MT5 patch

**Decision.** Where MT4 and MT5 disagree and MT4's rule is *newer and deliberate*,
MT5 is stale and gets the port. Where MT5's rule is newer and deliberate, MT4 is
stale and MT5 stays.

**Applied to.** `P-TH3-BASE-01`/`BASE-02`/`DEL4` are dated **2026-10-24**.
MT5's `P-MT5-TH3DEL` is dated **2026-10-21**. Three days of MT4 work — the 1:1 base
rule, the deletion of the two dead `/3` readers, the caption dismissal latch, and the
`Mother` → `Base` vocabulary — had never reached this tree. All four were ported.

**Rejected alternative.** "The trees have forked; leave MT5 alone." Rejected because
these are not stylistic forks: `P-TH3-BASE-01` changes every ladder target, and
`P-TH3-DEL4` changes whether deleting a label destroys the user's pattern.

**Consequence to remember.** This rule runs both ways. `P-MT5-TH3DEL` (below) is an
MT5-newer decision that MT4 does not have, and it was preserved.

---

## D2 — Port the caption dismissal, but *not* MT4's `P-TH3-DEL3` guard

**Decision.** Add only the user-facing half of `DEL4` to MT5: a caption delete
dismisses the readout. Do **not** re-add MT4's guard that treats every caption drop
as routine maintenance.

**Why.** MT5's `P-MT5-TH3DEL` comment claims our own object deletes never reach the
handler, because the compat layer drops events this program queued. That claim was
checked, not assumed:

* `MT5Compat/MQL5Compat.mqh:1434-1441` — *"an event is invisible iff this program
  performed the operation that queued it"*, one-shot tokens per name, 10 s TTL.
* `MT5Compat/MQL5Compat.mqh:1520-1523` — the entry calls `CompatConsumeObjEvent`
  **before any dispatch** and returns without dispatching on a match.
* `MT5Compat/MQL5Compat.mqh:1525-1538` — bulk sweeps record a prefix instead of
  walking names; a delete matching a live record is swallowed.

So on MT5 the handler only ever sees the user. MT4's `DEL3` guard would have no work
to do and could only ever *undo* the user — which is precisely the MT5 bug report
«وقتی پاک میکنم بقیه ها باقی میمونه» that `P-MT5-TH3DEL` fixed.

**Rejected alternatives.**

* *Port MT4's delete branch verbatim.* Would re-introduce the regression above.
* *Do nothing.* Leaves MT5 deleting a whole pattern when the user only wanted the
  caption gone — worse than MT4 in the opposite direction.

**Result.** The delete branch now asks one question first (is this a caption member
of a family whose anchors are alive?), and everything else keeps MT5's whole-family
rule.

---

## D3 — Making the plate selectable is worth the click it now consumes

**Decision.** `TH3ROPlateAt` sets `OBJPROP_SELECTABLE = true`, matching MT4.

**Trade-off, stated explicitly.** A selectable `OBJ_RECTANGLE_LABEL` intercepts mouse
clicks over its area. Before this change, a click on the caption fell through to the
chart and fired `CHARTEVENT_CLICK`, which is what places an ABCD pivot while the tool
is armed. After it, the terminal reports an object click instead (the dispatcher at
`Biotak/EventHandlers.mqh:7389` only acts on named objects, so the click is simply not
a pivot).

**Why that is acceptable.** MT4 has behaved this way since `P-TH3-DEL4`, and the
whole point of the flag is that *"a readout the terminal can name is a readout the
hand can delete"*. Without it the dismissal is unreachable and the entire fix is
dead code. The consequence is a small dead zone over the caption box, identical to
MT4's.

**Rejected alternative.** Keep the plate non-selectable and add a menu command to
dismiss the caption. Rejected: it invents a control MT4 does not have and leaves the
Delete key unresponsive on an object that is visibly on the chart.

**Watch for.** If the user reports "I can't place a pivot on the caption", this is
the change, and the answer is MT4's answer, not a bug.

---

## D4 — Port the caption rows, not just the formula

**Decision.** Rename `Mother`/`momleg` to `Base`/`baseleg` and adopt MT4's
`rowBase`/`rowCalc`/`rowLock` layout.

**Why it is not cosmetic.** MT5's `rowLock` printed the typed base **next to the
rewritten final step**:

```
base 30.0p LOCKED final 10.0p proved
```

That row was the bug, written on the chart in the user's own numbers. Keeping it
after fixing the formula would leave a caption that describes a behaviour the code no
longer has. It also carried the retired `/3` vocabulary into every screenshot.

**Result.** `module-report.py --only TH3Renderer.mqh` went from `BAD= 35` to
`BAD= 0` with this change alone — the strongest available evidence that the port is
faithful rather than approximate.

---

## D5 — Delete the dead `/3` readers, and say why in the source

**Decision.** Remove `TH3NodeStepAt` and `TH3MacroSpanStep` from
`Biotak/TH3/TH3Pivots.mqh`, carrying MT4's `P-TH3-BASE-02` header.

**Why.** Zero callers were confirmed by grep over `Biotak/**/*.mqh`, both entries, and
the MT4 twin. MT4 had already deleted them for the same reason. The cost is a
negative diff; the benefit is that the next person looking for "where does a step get
divided" finds a comment explaining it is gone, not two functions that do it.

**Guard against re-introduction.** The header states the rule (*they were the last
place a step could be built by dividing*) rather than just "unused, removed".

---

## D6 — Do not "fix" the leg-measure drag adapter to look like MT4

**Decision.** Leave `TH3Tool.mqh`'s `LegMeasure*` MT5-only layer alone, and record it
as **explained / unverified** rather than fixed.

**Why.** MT4 streams a drag as `CHARTEVENT_MOUSE_MOVE`; MT5 reports
`CHARTEVENT_OBJECT_DRAG` heartbeats. The MT5 layer is plumbing for a genuinely
different event model. `MT4-ONLY SYMBOLS (lost logic): 0` says nothing was dropped.
Rewriting it to match MT4's source would produce a module report that passes and a
drag that misbehaves — the exact failure mode the "one rule" warns about.

**What is owed.** A runtime comparison (drag a handle, compare ride/selection/release
frame by frame). It is listed as missing in `TEST_MATRIX` on purpose; the honest
status is unverified.

---

## D7 — Write the structural invariant as a script, not a comment

**Decision.** Add `tools/parity/caption-latch-check.py` alongside the fix.

**Why.** A comment saying "every path asks the latch" is the kind of claim that rots.
The script enforces three properties: exactly one writer of `TH3InfoOffAdd`, exactly
one caller of `TH3InfoFamilyDismiss`, and every caption paint path either guarded or
on a two-entry allow-list with a named guarded owner. Adding a new paint path now
fails the check until someone justifies it.

**Design note.** An early version flagged `LegInfoBoxPlace` (the leg meter's box,
`P-LM-17`) as an unguarded caption painter. It was wrong: that box is a different
readout with its own contract. The check was tightened to define "caption" by its
naming owners (`TH3InfoLineName`/`TH3InfoPlateName`) rather than by "paints a
rectangle label". Recorded because a detector that cries wolf gets ignored.

---

## D8 — Do not let the detectors' numbers become the goal

**Decision.** Stop at 3 RED rather than chase every bad line to zero, and record why.

**Why.** `wiring-report.py` was proven to produce false positives twice in this
session (both opened and read — `BUGS.md` MT5-PAR-009). Driving its count to zero
would mean editing code to satisfy a parser. The remaining 320 bad lines in
`TH3Tool`, `EventHandlers` and `DrawStrip` need per-symbol investigation against a
running chart, not line-count reduction.

**Consequence.** `RESULTS.md` reports 3 RED honestly and `BUGS.md` marks them OPEN.
No claim of parity for those modules is made anywhere.

---

## D9 — Do not commit

**Decision.** Leave everything uncommitted.

**Why.** The tree already carried an unfinished `BaseKnot` modularisation
(`BaseKnotTool.mqh` reduced ~8 024 lines, ten new `BaseKnot_*.mqh` files, entries and
several modules touched) when the session began. `AGENTS.md` says one user request =
one commit; that work is not this request, and these edits sit on top of it. Splitting
them cleanly needs a decision from the user about how the two changes should be
separated — not an assumption by the agent.

**Also not done.** No MT4 write, no `git add`, no `.ex5` staged, no `build-logs/`
staged.

---

## D10 — Leave the dismissed caption's per-redraw delete sweep unguarded

**Decision.** `TH3InfoFamilyDraw`'s new latch guard calls
`TH3InfoFamilyDelete(base)` on **every** redraw for a dismissed base, and
`TH3InfoFamilyDelete` issues 11 unguarded `ObjectDelete` calls (ten rows + plate).
Every one of those fails after the first dismissal. No guard was added.

**Why.** MT4's `TH3InfoFamilyDelete` is equally unguarded and its `DEL4` draw guard
calls it the same way, so guarding here would make MT5 *diverge* from the reference
to buy a micro-optimisation. This session's mandate keeps behavioural parity separate
from performance work, and the module report is now GREEN precisely because the
symbol matches MT4.

**Cost, measured honestly.** 11 no-op `ObjectDelete` calls per chart event, only
while at least one pattern has a dismissed caption. The render loop is one frame per
chart event (not per tick), so this is not a per-tick cost — but it is a real,
recurring one and it did not exist before the fix.

**Follow-up worth doing, in its own commit with its own before/after measurement:**
make `TH3InfoFamilyDelete` existence-guarded (`ObjectDelete` only when
`ObjectFind >= 0`). That is behaviour-identical on both platforms and removes the
no-op calls entirely — but it is an optimisation, and it should not ride in on a
parity commit where it cannot be measured against a stable baseline.

---

## D11 — Keep the export's `Mother_*` column NAMES while fixing their VALUE

**Decision.** `TH3_ExportCurrentSample` now computes
`stepBase = TH3StepBaseComponent(baseIn, rung)` like MT4, and the local variable is
renamed `motherIn`/`stepMother` → `baseIn`/`stepBase`. The CSV header strings stay
`Mother_Pips` and `Step_Mother`.

**Why.** MT4 renamed the variables and kept the column names, and says so in
`TH3DatasetHeader`: *"the two Mother_* NAMES stay. They are a stored-data contract
(every sample on disk carries this header, and four tools read them by name)"*.
Renaming a column would break every sample already on disk to fix a vocabulary the
user never sees in the file. The meaning is stated beside the header instead.

**Consequence for this audit.** `EventHandlers`-style "vocabulary drift" (MT5-PAR-004)
does not extend to these two strings — they are data, not UI.

---

## D12 — Port the `K` key verbatim, including MT4's comment

**Decision.** Insert MT4's `if((int)lparam == 75)` block — text and guard unchanged —
after the `M` handler in `EventHandlers.mqh`, with one added paragraph recording that
the subsystem had been ported on 2026-10-27 without its door.

**Why.** This is the one class of defect where "match MT4 exactly" is unambiguous:
there is no platform difference to adapt to. The key code, the call, the redraw and the
`#ifndef BUILD_LITE` guard have no MQL5 equivalent question. Writing a new door (say, a
panel button) would have been an MT5-only feature, not a parity fix.

**Not done.** No test of the capture itself. The door is reachable; its contents are
R10.

---

## D13 — Record the lost `why=` decoder instead of porting it

**Decision.** MT4's `g_p3ArmMask` (one bit per pending-work flag) and the
`" why=" + PerfArmWhy(...)` field on the `OnCalculate` overrun line were **not**
ported. `PerfArmWhy` stays dead in `GlobalVariables.mqh`; MT5-PAR-012 records it.

**Why.** It changes no chart behaviour — it only makes an overrun log line say more.
This session's commit is behavioural (two defects that reach the user), and mixing a
diagnostic port into it would make the before/after of the behaviour fixes harder to
read. It is also not free: the mask has to be assigned on the same line that already
reads the eight flags, which is inside the frame-hot path.

**If it is done later:** it belongs with a measurement, because the value is only in
the log line it improves.

---

## D14 — Extend the existing symbol differ instead of shipping a second one

**Decision.** A second tool (`symbol-diff.py`) was written, used for about an hour, and
**deleted**. Its only unique capability — rank every symbol by change size and classify
`SAME` on comment-free bodies — was added to `tools/parity/sym-diff.py` as `--scan`.

**Why.** `sym-diff.py` already answered "show me the lines of this symbol", and it had
the better comparison (`module-report.norm_body`, which strips comments and collapses
whitespace). Two tools with overlapping purposes is how a parity toolkit rots: the next
reader has to guess which one to trust. One tool, one answer.

**New tool that was NOT redundant:** `tools/parity/dead-doors.py`. Nothing in the kit
asked "is this function reachable at all", which is exactly the question MT5-PAR-011
turned on. It found five more candidates in its first run; all five are explained in
`BUGS.md`, and it no longer lists `BaseKnotCaptureSample` now that the door exists.

---

## D15 — The 500 ms floor now throttles the full-history copy only, not the shift

**Decision.** `COMPAT_FULL_SYNC_MIN_MS` gated the entire re-sync block, including the cheap
one-slot shift. It now gates the `CopyRates` path alone: `if(newBar || due)` enters the block,
and the shift branch runs on every genuine new bar whatever the clock says. `s_lastFullSyncMs`
was removed from the shift branch — it still stamps only after a *successful* copy, which is
where R-TF-UNIT already put it and for the reason R-TF-UNIT gave (a stamp before the copy made
a failed copy retry only after 500 ms, which on H4 meant hours with empty arrays).

**Why.** The throttle was bought to stop a history download turning every tick into a
full-history `CopyRates` — a 7 MB struct copy plus a 5 x bars field unpack. The shift is none
of those: O(bars) scalar moves, zero kernel crossings. Applying a copy-cost guard to a
different operation bought MT5-PAR-014 (a torn index 0) and saved nothing measurable.

**Rejected alternatives.** *Keep the whole block throttled.* That is the shipped bug. *Leave
the block alone and patch the foot block only.* Rejected: it treats the symptom — the foot
block writing into an unaligned slot is downstream of the shift being skipped, and the two
defects share a cause (rule: never fix symptoms).

**Watch for.** If a profile ever shows the shift costing real time on a 100k-bar chart, the
fix is to bound the shift (copy only the touched tail), never to re-add this gate.

---

## D16 — Hold the last consistent snapshot rather than tear index 0 — and do not call the residual parity

**Decision.** The live-value foot block now writes only when the arrays are aligned with the
count the caller reported (`bars == g_seriesSyncedAt`). When a count change was *not* applied
(throttled, or a copy that failed because history is still arriving), the emulated series
keeps its previous snapshot, so `Bars` can lag the chart for a few hundred ms.

**Trade-off, stated in the numbers the replay produced.** S4's `SHORT(3)` is that lag, and it
is recorded as a **divergence from MT4**, not as a fix. `Bars` is read as a *value* in the
shared code (BaseKnot's total, `Time[Bars-1]` as the oldest bar), so a short `Bars` is a
different answer, not merely a late one.

**Why it is still the right side of the trade.** The alternative that shipped wrote the live
High/Low/Close into a slot still carrying the previous bar's Time and Open: one object
describing two bars. `ZoneFactory` reads `Time[0]` for the zone's end edge and the shared code
reads `Close[0]` for `currentPrice`, so that frame's zone was drawn between a time and a price
that never coexisted. A stale-but-coherent bar self-heals on the next sync; a torn bar was
silent, and every consumer of that one frame made a decision on it.

**Rejected alternatives.** *Bypass the throttle for every count change* — that reintroduces
the per-`CopyRates` cost the floor exists to prevent, exactly during a download. *Fall through
and let the next frame correct it* — this is the user's standing "first frame must be final"
rule: a paint that needs correcting after it landed is a visible flicker, not a transient.

---

## D17 — A shim divergence with no reachable path is recorded, not "aligned"

**Decision.** Seven candidate divergences in `MQL5Compat.mqh` were each tested for a live call
site before being touched, and all seven were left exactly as they are, with the evidence in
`BUGS.md`.

**Why.** An unreachable branch cannot be tested — the only thing that can grade it is a
replay that never runs in the terminal — so "fixing" it trades a provable state for an
unprovable one and quietly redefines a contract for whoever adds the call site later. Rule 4
(forbid changing working behaviour to match an assumed reference) and rule 3 (no symptom
fixes) both point the same way here.

**The test that distinguishes this from MT5-PAR-013.** Reachability of the **layer**, not of
the **branch**, decides. `CompatRefreshChartData()` runs on every `OnCalculate` for every
chart — its state machine is reachable from the platform itself, no call site needed, so a
divergence there is a live defect however unglamorous the code looks. The `iBarShift`
`exact=true` arm is reachable only through an argument no shared module ever passes.

---

## D18 — Build with `-NoRestart`: the compile is ours, the terminal is the user's

**Decision.** `AGENTS.md` states a build must restart the terminal so the new `.ex5` is the
resident code, and forbids sending the user to flip the timeframe to load a build. The user's
standing instruction is that no agent may restart or close their trading terminal unasked.
This session ran `tools/mt5-reload.ps1 -NoRestart` — both entries compiled, the terminal was
left alone — and `RESULTS.md` says in those words that **the fix is compiled and not
resident**.

**Rejected alternatives.** *Run `tools/mt5-verify.ps1`* (kills and relaunches the terminal) —
explicitly forbidden by the user's rule. *Follow AGENTS.md and restart anyway* — a standing
project rule does not outrank the person whose live session it terminates. *Claim the
behaviour is fixed* — it is not even loaded.

**Consequence.** R11–R13 cannot be evaluated by this agent, and the record must keep saying
so until the user restarts and tests.

---

## D19 — "FIXED (numeric replay)" is a new status, and it is not "fixed"

**Decision.** MT5-PAR-013/014 carry the status **FIXED (numeric replay) — runtime confirmation
owed**, with R11–R13 named as the tests that would upgrade them.

**Why a new word was needed.** The kit already had FIXED(static) (a source invariant holds) and
FIXED(numeric) (a formula reproduces on parsed constants). The series state machine is neither:
it is a *temporal* object, and the only honest pre-runtime evidence is a replay of its own
logic against a terminal whose arrays are ground truth. That is stronger than reading the code
and weaker than a chart.

**Guard against the label doing what a detector's number does (D8).** The status names its own
limit, and the register says out loud that no log line in this audit records a one-bar history
append. Without a reproduction report, comparison data and a test result, a bug is not
declared fixed — so these two are declared *proven on replay*, pending the chart.

---

## D20 — When a review rejects a claim, correct the record and keep the rejected sentence visible

**Decision.** The independent review of `P-MT5-SERIES-01` rejected two things this session had
written as fact: that an ordinary timeframe switch could land inside the torn-frame window, and
that the harness's `AFTER` column mirrored the shipped code. Both were corrected — in the source
comment, in `MT5-PAR-014`, in R13, and by making the throttle stamp variant-dependent in
`series_sync_parity.py` — and the *wrong* first draft is quoted inside the corrected text
("The first draft of this entry said…") rather than deleted.

**Why not just fix it quietly.** A parity record's only value is that later readers can trust
its evidence. A claim that survives because nobody re-checked it is the same failure as a
detector's number being taken for ground truth (D8), and the TF-switch case was exactly the
kind of plausible trigger nobody had tested: the tree itself documents the reinit at
`EventHandlers.mqh:1204-1216`, ten files away from the comment that contradicted it.

**Also decided.** The review's most serious point — a new bar arriving with an *unchanged* bar
count would skip the re-sync and tear index 0 — was NOT answered from the code, because the
code cannot tell us what MT5 does. It went to the platform reference: `rates_total` is the
series available to the indicator, and the chart-bar limit affects the initial count only. Not
reachable ⇒ no fix, and the class statement plus R14 stay in the register. This is the
difference between an accepted platform difference and an unexamined one (rule: research the
docs when a platform semantic is uncertain).

**Rejected alternatives.** *Ship the review's residual as a fifth gate in the foot block* —
rejected: it would add a per-frame comparison to guard a case the documentation says cannot
happen, and the performance law forbids exactly that trade. *Leave the harness stamp alone* —
rejected: a harness that diverges from the source in the one place the fix changed is a harness
that cannot detect the regression it was written for.
