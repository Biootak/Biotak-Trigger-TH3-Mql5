# AGENTS.md — Biotak Trigger TH3 (MQL5 mirror)

MT5 build of the Biotak Trigger TH3 indicator (Prof. Khakestar's TH levels).
This repository is a **shell, not a fork**. The product code lives in the MQL4
repository and is compiled by both terminals.

## The one rule

`Biotak/` is a **directory junction** into `../Biotak-Trigger-TH3-mql4/Biotak`.
It is gitignored and must never be replaced by a copy. Both the MT4 and the MT5
entry include the same 65 `.mqh` files, so the two platforms cannot drift: there
is no second source to fall out of date. `Files/` is a junction to the same
repository's icon assets for the same reason.

Corollary: **never edit a module through this path.** An edit made here is an
edit to the MT4 source, on a tree that may carry unrelated work in progress.
Change `Biotak-Trigger-TH3-mql4/Biotak/*.mqh`, then rebuild both terminals.

## Layout

- Entries: `Biotak Trigger TH3.mq5` (Full), `Biotak Trigger TH3 Lite.mq5`
  (`#define BUILD_LITE` inside it). Both mirror their `.mq4` twin line for line:
  same include order, same five handlers, same `P4Report*` ledgers, same UI-kit
  half (`InitializeUIStates` / `InitializeBiotakKit` / `InitializeHTFCandles` /
  `CreateMenu`, and the matching teardown).
- `MT5Compat/MQL5Compat.mqh` — the **only** MT5-specific source. Every MQL4 API
  the shared modules use is bridged here. Included immediately after
  `Logger.mqh` and before every shared module.
- `_retired/mql5-biotak-aug21/` — the stale divergent copy this repository used
  to carry (frozen 2026-08-21). Kept for reference; never included.
- `tools/mt5-build.ps1` — MetaEditor compile helper. `tools/check-pp-balance.py`
  and `tools/pp-trace.py` — preprocessor balance checks (see below).

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3.mq5"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3 Lite.mq5"
# MT4 regression check (mandatory after any shared-module edit)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 `
  -Source "..\Biotak-Trigger-TH3-mql4\Biotak Trigger TH3.mq4" `
  -Compiler "C:\Program Files (x86)\RoboForex MT4 Terminal\metaeditor.exe"
```

Success = `Result: 0 errors` in `build-logs/`. **Both entries and both
platforms must be green.** `compile-th3.ps1` also works but calls `Start-Process`
without quoting, so paths containing spaces break it; `tools/mt5-build.ps1`
quotes them and drops the duplicate `http_proxy`/`HTTP_PROXY` environment entry
that makes `Start-Process` throw on this machine.

Before compiling: the 244 icons must exist in the terminal data folder under
`MQL5\Files\Icons` (253 `#resource "\\Files\\Icons\\*.bmp"` directives resolve
there at compile time; the bytes are then embedded in the `.ex5`).

## MT5 traps found the hard way

- **A missing `#endif` is fatal here.** `ExtendedDrawingFunctions.mqh` shipped
  with an unclosed `#ifndef EXTENDED_DRAWING_FUNCTIONS_MQH`; the MT4 compiler
  auto-closes at EOF, MT5 reports `error 372` and then cascades **244 spurious
  `invalid resource path` errors** on top. Always run `tools/check-pp-balance.py`
  over `Biotak/*.mqh` before blaming a resource.
- **`#define Bars <var>` clobbers the built-in `Bars(symbol, timeframe)`.** The
  MQL4 predefined-array emulation defines `Bars`; every *function-form* call in
  the shared source must therefore be written `iBars(...)`, which is valid on
  both platforms.
- **A one-parameter macro also matches an empty argument list.** `#define
  PeriodSeconds(tf) …` rewrites the zero-argument `PeriodSeconds()` into
  `PeriodSeconds((ENUM_TIMEFRAMES)())`. Do not define it; cast at the call site.
- **`StringTrimLeft`/`StringTrimRight` differ in *meaning*, not just signature.**
  MQL4 returns the trimmed string; MQL5 returns the number of characters removed
  and trims in place. The shared source uses the MQL4 return-value form in eight
  places, so `MQL5Compat.mqh` re-points the names at string-returning helpers.
  Proven by compiling both forms against the MT4 compiler (`int n = …` warns
  180, `string r = …` is clean).
- **`int` timeframes need explicit casts.** `iBarShift`, `CopyTime`,
  `PeriodSeconds` and `ObjectCreate`'s type argument accept a raw `int` in MQL4
  and require `ENUM_TIMEFRAMES` / `ENUM_OBJECT` in MQL5. Cast at the call site
  so both compilers accept the same line.
- **MT5 additions to the entries are unavoidable and are marked `MT5-ONLY`:**
  `ArraySetAsSeries` on the `OnCalculate` arrays, and `CompatRefreshChartData()`
  in `OnCalculate`/`OnTimer` to feed the `Time[]/Open[]/…/Bars` emulation.
  Nothing else in the entries is platform-specific.

## Working rules

- `git status` first. In *this* repository the tree is expected to be clean; in
  the MT4 repository it often is not, so never commit shared-module edits from
  here — hand them to the MT4 working session.
- One user request = one commit. `feat(scope): …`, `fix(scope): …`.
  Never commit `.ex5`, `build-logs/`, or the junction contents.
- Performance law is inherited unchanged from the MT4 repository: never write a
  chart property you would not change, teardown/show-hide are bulk operations,
  every saver writes through a shadow, one `GlobalVariablesFlush` only.
