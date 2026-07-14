# Repository Guidelines

## Project Structure & Module Organization
This repository contains an MT5 custom indicator for Biotak Trigger TH3. The main entry points are `Biotak Trigger TH3.mq5` and `Biotak Trigger TH3 Lite.mq5` at the repository root. Shared MQL5 modules live in `Biotak/` as `.mqh` files, grouped by responsibility such as calculation (`THCalculations.mqh`, `ATRCalculations.mqh`), rendering (`ZoneRenderer.mqh`, `DrawingPipeline.mqh`), state (`GlobalVariables.mqh`, `ObjectCache.mqh`), and event handling (`EventHandlers.mqh`). Documentation and analysis notes are in `docs/` and root Markdown files. Build outputs (`*.ex5`) and logs in `build-logs/` are generated artifacts.

## Build, Test, and Development Commands
Use PowerShell from the repository root.

- `.\compile-th3.ps1` compiles the default workspace indicator.
- `.\compile-th3.ps1 -Project all` compiles workspace and installed variants.
- `.\compile-th3.ps1 -SourceFile "C:\path\to\file.mq5"` compiles a specific source file.
- `.\compile-th3.ps1 -PrintLog $true -LogTailLines 120` prints the latest compile diagnostics.

Set `MT5_METAEDITOR` and `MT5_MQL5_DIR` if the script cannot auto-detect MetaEditor or the terminal MQL5 directory.

## Coding Style & Naming Conventions
Follow existing MQL5 style. Use PascalCase for functions and module-level concepts, descriptive globals matching current `g_` patterns, and uppercase constants/enums where already established. Keep `.mqh` files focused on one domain and include only the dependencies they need. Prefer explicit bounds checks, clear error logging, and existing helpers over duplicating utility logic. Keep comments short and useful for trading logic, formula assumptions, or non-obvious platform behavior.

## Testing Guidelines
There is no standalone automated test suite. Treat a clean MetaEditor compile as the minimum validation step. For behavior changes, attach the compiled indicator in MT5 and verify chart rendering, timeframe changes, object cleanup, alerts, and runtime logs. Check `build-logs/` after compilation for warnings, errors, and runtime snapshots.

## Commit & Pull Request Guidelines
Recent history uses short messages plus conventional prefixes, for example `fix: enhance ATR fallback...`, `refactor: use built-in PeriodMinutes()...`, and `fix(visibility): ...`. Prefer `type(scope): summary` when practical. Pull requests should include the changed indicator/module area, compile results, manual MT5 validation notes, and screenshots or log excerpts for visual or runtime behavior changes.

## Agent-Specific Instructions
Do not overwrite user work in modified `.mq5` or `.mqh` files. Before editing shared modules, inspect current includes and call sites with `rg`. Keep generated files, build logs, and compiled `.ex5` updates separate from source changes unless explicitly requested.
