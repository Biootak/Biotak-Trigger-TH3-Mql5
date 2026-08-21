# Render Engine Architecture — Immediate-Mode Canvas (v3.11)

> خلاصه فارسی: ریشهٔ کندی، ساخت صدها شیء گرافیکی (Object) روی چارت بود — هر شیء چندین فراخوانی IPC به ترمینال دارد. در MT5، تنها چیزی که به‌صورت بومی (بدون هیچ کدی) با اسکرول/زوم چارت حرکت می‌کند، اشیاءِ لنگرشده به زمان/قیمت (`OBJ_RECTANGLE`، `OBJ_HLINE`، ...) هستند — دقیقاً همان مکانیزمی که نسخهٔ MT4 شما استفاده می‌کند (در MT5، برخلاف MT4، ترمینال بیت‌مپ‌ها را بازپروجکت نمی‌کند). پس برای «مثل MT4 شدن» پیش‌فرض روی همان موتور اشیاء (`Objects`) است: اسکرول عمودی/افقی و زوم همگی بومی و صفر-کارِ اندیکاتور هستند. دو حالت Canvas (`Canvas Anchored` و `Canvas`) هم به‌عنوان گزینه‌های آزمایشیِ رندر سریع‌تر باقی مانده‌اند. ورودی جدید `Rendering Engine` در تنظیمات: `Objects` (پیش‌فرض — دقیقاً همان MT4)، `Canvas Anchored` (بیت‌مپ لنگرشده)، یا `Canvas` (صفحه‌ای — با شیفت پیکسلی).

## The root cause this architecture removes

The old render path was a **retained object graph**:

- Each zone = 1 `OBJ_RECTANGLE` (+ up to 3 border segments for hollow boxes)
- Each level/trigger line = 1 `OBJ_HLINE` (+ optional label)
- Every `ObjectCreate` / `ObjectSet*` call is an **IPC round-trip** into the terminal process.

At the default `Max Levels = 144`, one redraw creates ~500+ objects and **thousands of IPC calls**. That is the lag you feel on mode changes, timeframe switches, scroll and price-line drags — not the math (the geometry is a few hundred floating-point operations).

## The new architecture

**Immediate-mode rasterization into a single full-chart bitmap** (`OBJ_BITMAP_LABEL` + `ResourceCreate`, no standard-library dependency):

```
Geometry (pure math, no platform calls)     View (pixels, in-process memory)
─────────────────────────────────────       ─────────────────────────────────
Stage 1  CalculateLevels              ─┐    CBiotakCanvas (1 object)
Stage 2  ClassifyLevels               ├─►   ├─ zones   : alpha-blended rects
Stage 3/4 BuildZonesAndLines          ─┘    ├─ lines   : horizontal styled lines
                                           └─ blit    : 1 ResourceCreate + ChartRedraw
        ▲ cached per signature                 ▲ re-rasterized on viewport change
        (mode | TF | base-price | flags)       (scroll / zoom / resize / drag)
```

Key properties:

1. **One object, one IPC per frame.** All zones/lines/midpoints become pixel writes in a local `uint[]` ARGB buffer. The only terminal call per frame is the single `ResourceCreate` blit (+ `ChartRedraw`).
2. **Geometry is cached, not recomputed.** A signature string (mode + timeframe + center price + step sizes + classification flags + zone config) keys a small model cache (6 slots). Mode toggles and TF switches reuse cached zones/lines instead of rebuilding.
3. **Viewport changes are re-rasterizes, not object toggles.** Scroll/zoom/resize re-map price→pixel and redraw the buffer in memory (µs per primitive). The old path re-issued per-object `OBJPROP_TIMEFRAMES` IPC on every scroll frame.
4. **Zero-work frames are O(1).** A frame skip-key (model signature + viewport bounds + lines/triggers/hidden state) makes tick-driven redraws complete no-ops.
5. **Interactive layer stays as real objects** (they are few and cheap): custom-price line, ATR/TH/mode/lock/factor/frequency labels, High/Low lines, TH3 tool drawings. Canvas never blocks mouse input (`SELECTABLE=false`).

## What changed

| File | Change |
|---|---|
| `Biotak/CanvasEngine.mqh` | **New.** `CBiotakCanvas` (bitmap-label canvas), model cache, rasterizer, viewport refresh, lifecycle. |
| `Biotak/PropertiesAndInputs.mqh` | New `input group 00) PERFORMANCE / RENDER ENGINE` → `inpRenderEngine` (`Canvas` default / `Canvas Anchored` / `Objects` legacy). |
| `Biotak/BuildConfig.mqh` | `RENDER_ENGINE_DEFAULT` macro → **`Objects`** (the exact MT4 native-object mechanism; Sync Compare forces `Objects` too). |
| `Biotak/EventHandlers.mqh` | Engine routing in `DrawLevelsBasedOnMode`, `RedrawAllObjects`, `CHARTEVENT_CHART_CHANGE`, F/L hotkeys, `OnDeinit`, and object-count safeguards. |
| `Biotak Sync Compare.mq5` | `#define SYNC_COMPARE_BUILD` keeps the retained-object path for CSV parity diffs. |

## Expected speed-up

| Action | Old (objects) | New (canvas) |
|---|---|---|
| Full levels redraw (144 levels, filled zones) | ~500 objects / thousands of IPC | 1 blit + in-memory rasterize (~1 ms) |
| Mode change (E key) | delete + recreate ~500 objects | re-rasterize cached/new model |
| Timeframe switch | teardown + full rebuild | model swap + 1 rasterize |
| Scroll / zoom | per-object TIMEFRAMES IPC | in-memory re-rasterize (see scroll note) |
| Custom-price drag (50 ms cadence) | heavy object churn | smooth sub-ms rasterize |

### Scroll behavior (vertical / horizontal)

A canvas is screen-anchored, so unlike MT4 objects it does not follow the chart
by itself — every scroll frame must re-sync it. Two mechanisms make this
invisible and cheap:

1. **The 100 ms `CHART_CHANGE` throttle is bypassed for the canvas engine.**
   The throttle exists for the object path (per-object visibility IPC per
   frame); the canvas re-syncs in memory, so it processes **every** scroll/
   zoom frame. Without this, the levels appeared to stay fixed while the
   chart scrolled.
2. **Vertical scroll with constant zoom uses a pixel-shift fast path**
   (`CBiotakCanvas::ShiftRows`): the existing buffer is translated by the
   price delta (a row copy, not a re-rasterize) and only the newly exposed
   band is redrawn (`CanvasRasterizeEx` with band clipping). Zoom, resize,
   first draw and page jumps fall back to a full rasterize. Horizontal
   scroll is a no-op — all primitives are full-width, so the content is
   already correct.
| Tick while nothing changed | throttled pipeline work | O(1) skip |

## Why MT4 has no scroll problem (and how we close the gap)

MT4 objects (`OBJ_HLINE`, `OBJ_RECTANGLE`, ...) are anchored in **chart
space (time/price)**. The terminal itself re-projects every object against
the viewport on every repaint — scrolling/zooming is done natively, with
sub-pixel accuracy, and the indicator does nothing. That is why "everything
is correct" in MT4.

Our first canvas (`OBJ_BITMAP_LABEL`) is anchored in **screen space**, so the
indicator must re-sync it on every viewport change itself (the 100 ms throttle
+ pixel-shift fix described above). We then added an **anchored mode**
(`Canvas Anchored`) using `OBJ_BITMAP` bound to a chart point — but live
testing showed MT5 does **not** re-project bitmaps on scroll like MT4 does
with objects (scroll still forces our own re-rasterize, which visually
"jumps"). So the only true MT4-identical behavior in MT5 is the **`Objects`
engine**: time/price-anchored objects that the terminal itself moves on every
repaint, with zero indicator work during scroll. **Default = `Objects`.** The
two canvas modes remain selectable experimental fast-render options.

### Why the default is `Objects`, not a canvas

| Engine | Space | Scroll behavior in MT5 | Indicator work while scrolling |
|---|---|---|---|
| **`Objects` (default)** | time/price (native) | terminal re-projects objects natively, sub-pixel, like MT4 | **zero** |
| `Canvas Anchored` (`OBJ_BITMAP`) | chart point | bitmap is **not** re-projected natively; indicator must re-rasterize | per-frame re-rasterize (visible jumps) |
| `Canvas` (`OBJ_BITMAP_LABEL`) | screen | indicator must re-sync every frame | pixel-shift (~1 ms/frame) |

## Trade-offs (documented)

- **Zone transparency is blended against the chart background** (like a flat tint), not per-pixel over candles. Visually near-identical for filled boxes; hollow boxes and lines are exact.
- **No per-zone tooltips / no per-line pip-distance labels** in canvas mode (lines/zones are pixels, not objects). Mode/status labels and the custom-price line keep tooltips.
- **The canvas is one chart object** — the object list shows `..._Canvas_<chartid>` instead of hundreds of zone objects. F key hide/show still works (single `OBJPROP_TIMEFRAMES` toggle).
- If any visual nuance matters more than speed for a given setup, switch `Rendering Engine = Objects` in the indicator inputs — the legacy path is fully intact.

## Validation

- `Biotak Trigger TH3.mq5`, `Biotak Trigger TH3 Lite.mq5`, `Biotak Sync Compare.mq5` all compile with **0 errors** (4 pre-existing warnings in `BasePriceHistoryManager.mqh`).
- **Default engine = `Objects`** — the exact MT4 native-object mechanism: time/price-anchored objects the terminal moves itself, so scrolling/zooming is zero-work for the indicator and levels always sit on the correct price (verified against the MT4 code: `OBJ_RECTANGLE`/`OBJ_HLINE`/`OBJ_TREND` in chart space, no scroll handler at all). `Canvas Anchored` and `Canvas` remain selectable experimental fast-render options with an automatic fallback if bitmap creation fails.
- Manual MT5 validation checklist:
  1. Attach on H1 → zones/lines appear instantly; object count stays ~1 (plus labels).
  2. E key mode cycling, T (triggers), L (lines), F (hide/show) — all sub-frame.
  3. Scroll/zoom — smooth, no object churn in the terminal log.
  4. Switch timeframe M1→D1→M1 — levels redraw instantly; labels relayout as before.
  5. Drag the custom-price line — live levels track the drag at 50 ms cadence without stutter.
  6. `Rendering Engine = Objects` → verify identical geometry via the legacy path.
