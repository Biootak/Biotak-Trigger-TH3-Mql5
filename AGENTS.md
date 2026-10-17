# AGENTS.md — Biotak Trigger TH3 (MQL5)

MT5 build of the Biotak Trigger TH3 indicator (Prof. Khakestar's TH levels).
Since 2026-09-17 this repository is a **stand-alone fork, not a shell**: it
owns its `Biotak/` product modules and its `Files/` icon assets as real
tracked copies. An edit here can never change MT4 behaviour — the MT4 tree is
no longer reachable from this repository by any path.

## The one rule

`Biotak/` and `Files/` are **owned copies**, separated from
`../Biotak-Trigger-TH3-mql4` on 2026-09-17 (junctions removed, contents copied
byte-for-byte, then the MT4 tree reverted to pristine), and forked outright on
2026-10-12 (the GENERATED MIRROR headers removed; nothing regenerates them).
`../Biotak-Trigger-TH3-mql4` remains the LOGIC reference and
`tools/parity/module-report.py` (read-only) flags any drift, but a problem in
one tree can no longer become a problem in the other through regeneration.
This repository never writes back into MT4.

Corollary: **edit modules here freely.** MT5-only work (R-TF-UNIT, the compat
ledger, the ATR memo, prefix-sweep teardowns, gated censuses) lives in this
copy and does not need a twin in MT4. When porting an MT4 change over, copy
the file, diff it, rebuild both MT5 entries, and say so in the commit message.

## Layout

- Entries: `Biotak Trigger TH3.mq5` (Full), `Biotak Trigger TH3 Lite.mq5`
  (`#define BUILD_LITE` inside it). Both mirror their `.mq4` twin line for line:
  same include order, same five handlers, same `P4Report*` ledgers, same UI-kit
  half (`InitializeUIStates` / `InitializeBiotakKit` / `InitializeHTFCandles` /
  `CreateMenu`, and the matching teardown). Both carry
  `#define BIOTAK_RENDER_ENGINE` (R-RENDER-ENGINE, 2026-10-17): the ladder's
  trigger lines and the ZONE family (fill band + edge segments on a
  dedicated BACK layer) are painted by the canvas engine instead of one chart
  object per element — comment that ONE line out for the object-path A/B.
  (The pip-distance labels the engine also painted in phase 1 were removed
  outright in P-LBL-11, same day; the engine's text family stayed, dormant.)
- `Biotak/` — owned product modules (68 `.mqh`). MT5-only fixes live here;
  they must stay behaviour-identical to MT4 on MT4-equivalent inputs, and any
  MT5-only divergence is marked `MT5-ONLY` or `R-TF-UNIT`.
- `Engine/` — MT5-only canvas render engine (not product modules):
  `RenderPlatform.mqh` (bitmap layers, resources, layer masks),
  `RenderCore.mqh` (scene, price mapper, painters, Law 0), and
  `RenderBridge.mqh` (the product seam — staging/diff-commit for lines, labels
  and zones, the mask/paint pump; zones reuse the trigger-ink helpers, edge
  segments are stroked as thin rects and the band painters honour `filled`).
  `LevelPipeline.mqh` calls the bridge behind `BIOTAK_RENDER_ENGINE`; spec and
  laws in `docs/ENGINE-ARCH-FA.md`.
- `MT5Compat/MQL5Compat.mqh` — the **only** MT5-specific source. Every MQL4 API
  the shared modules use is bridged here. Included immediately after
  `Logger.mqh` and before every shared module.
- `_retired/mql5-biotak-aug21/` — the stale divergent copy this repository used
  to carry (frozen 2026-08-21). Kept for reference; never included.
- `tools/mt5-build.ps1` — MetaEditor compile helper (targets ONE terminal;
  see the preflight). `tools/mt5-verify.ps1` — the closed loop: build, prune
  old logs, restart that terminal, watch its fresh log, report a verdict.
  `tools/parity/module-report.py` — read-only drift detector against MT4.
  `tools/parity/_retired/resync-module.py` — the retired generator; its
  `--write` paths must never run (its MODULE_PATCHES list stays as data for
  the detector). `tools/check-pp-balance.py` and `tools/pp-trace.py` —
  preprocessor balance checks (see below).

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3.mq5"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3 Lite.mq5"
# MT4 sanity check (optional — this repo can no longer affect MT4, but run it
# after porting an MT4 change over, to prove the two trees still agree)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 `
  -Source "..\Biotak-Trigger-TH3-mql4\Biotak Trigger TH3.mq4" `
  -Compiler "C:\Program Files (x86)\RoboForex MT4 Terminal\metaeditor.exe"
```

Success = `Result: 0 errors` in `build-logs/`. **Both entries must be green;
the MT4 check is a bonus.** `compile-th3.ps1` also works but calls `Start-Process`
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
  `ArraySetAsSeries` on the `OnCalculate` arrays, `CompatRefreshChartData()`
  in `OnCalculate`/`OnTimer`, and the R-RENDER-ENGINE block
  (`#define BIOTAK_RENDER_ENGINE`, the `Engine\RenderBridge.mqh` include, the
  `RBridgeInit`/`RBridgeShutdown` calls and the `RBridgePump` calls in
  `OnChartEvent`/`OnTimer`). Nothing else in the entries is platform-specific.

## Working rules

- `git status` first. In *this* repository the tree is expected to be clean; in
  the MT4 repository it often is not. `Biotak/` edits commit here (they are
  this repo's own files now); this repo never writes into the MT4 tree.
- One user request = one commit. `feat(scope): …`, `fix(scope): …`.
  Never commit `.ex5` or `build-logs/`.
- Performance law is inherited unchanged from the MT4 repository: never write a
  chart property you would not change, teardown/show-hide are bulk operations,
  every saver writes through a shadow, one `GlobalVariablesFlush` only.
