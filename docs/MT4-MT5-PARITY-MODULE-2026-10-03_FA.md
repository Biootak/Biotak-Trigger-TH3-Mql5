# مقایسهٔ ماژولبهماژول MT4 ↔ MT5 — ۲۰۲۶-۱۰-۰۳

**فرمان کاربر:** «دقیقاً مثل متاتریدر ۴ باشه، نه چیزی کم نه چیزی زیاد — چیزهای اضافی متاتریدر ۵ هم حذف بشه.»

**روش:** MT4 تنها مرجع است. برای هر ماژول، MT4 اول با همهٔ جزءهایش (part files) بازسازی می‌شود، بعد هر دو طرف به نمادهای نامدار تقسیم می‌شوند و **مجموعهٔ خطوط کد** (کامنت و فاصله و ترتیب حذف‌شده) مقایسه می‌شود. هیچ خطی بی‌دلیل مجاز نیست: تنها عذر پذیرفته‌شده «آداپتور پلتفرم» است که هر کدام با دلیل فهرست شده‌اند.

**نتیجه:** 69 ماژول سبز، 0 قرمز، 0 فایل اضافی MT5. هیچ نمادی از MT4 گم نشده و هیچ نماد/فیلی مخصوص MT5 باقی نمانده.

## ۱. تنها تفاوت‌های باقی‌مانده (همه آداپتور پلتفرم، بدون اثر روی عدد)

| دلیل | خطوط یک‌طرفه | نمونه |
|---|---|---|
| MQL5 arrays are not timeseries by default, MQL4's always were | 8 | `ArraySetAsSeries(close, true);` |
| MQL4 Bars(symbol,timeframe) call | 2 | `Print(" CalculateTrueRange: barIndex exceeds Bars (", barIndex, "/", B` |
| MQL4 Bars() -> MQL5 iBars() | 2 | `Print(" CalculateTrueRange: barIndex exceeds iBars(", barIndex, "/", B` |
| MQL4 untyped ObjectCreate overload | 2 | `if(!ObjectCreate(0, ch, type, 0, t1, p1, t2, p2)) return false;` |
| MQL5 ObjectCreate needs the explicit enum cast | 2 | `if(!ObjectCreate(0, ch, (ENUM_OBJECT)type, 0, t1, p1, t2, p2)) return ` |
| MT4 timeframe cast in CopyTime | 1 | `got = CopyTime(Symbol(), (ENUM_TIMEFRAMES)timeframe, 0, count, times);` |
| MT4 timeframe number mapped through CompatTF | 1 | `got = CopyTime(Symbol(), CompatTF(timeframe), 0, count, times);` |
| MT5 compatibility shim call | 1 | `CompatRefreshChartData();` |

جمع: **19 خط یکتا** در کل درخت (ورودی‌ها + ماژول‌ها) که فقط همین آداپتورها هستند؛ بقیهٔ کد بایت‌به‌بایت مثل MT4 است.

## ۲. جدول ماژول‌به‌ماژول

| ماژول | خطوط کد MT4 | مشترک | فقط MT4 | فقط MT5 | وضعیت |
|---|---|---|---|---|---|
| `Biotak/ATRCalculations.mqh` | 909 | 908 | 1 | 1 | GREEN |
| `Biotak/AdaptiveScaling.mqh` | 163 | 163 | 0 | 0 | GREEN |
| `Biotak/AlertFunctions.mqh` | 72 | 72 | 0 | 0 | GREEN |
| `Biotak/BaseKnotTool.mqh` | 3418 | 3418 | 0 | 0 | GREEN |
| `Biotak/BasePriceHistoryManager.mqh` | 682 | 682 | 0 | 0 | GREEN |
| `Biotak/BasePriceManager.mqh` | 1250 | 1250 | 0 | 0 | GREEN |
| `Biotak/BiotakKit.mqh` | 195 | 195 | 0 | 0 | GREEN |
| `Biotak/BiotakMenu.mqh` | 2829 | 2829 | 0 | 0 | GREEN |
| `Biotak/BiotakPanels.mqh` | 6616 | 6616 | 0 | 0 | GREEN |
| `Biotak/BuildConfig.mqh` | 132 | 132 | 0 | 0 | GREEN |
| `Biotak/BuildHash.mqh` | 3 | 3 | 0 | 0 | GREEN |
| `Biotak/CalculationCache.mqh` | 279 | 279 | 0 | 0 | GREEN |
| `Biotak/CardMetrics.mqh` | 83 | 83 | 0 | 0 | GREEN |
| `Biotak/ComboEngine.mqh` | 308 | 308 | 0 | 0 | GREEN |
| `Biotak/ConstantsAndEnums.mqh` | 664 | 664 | 0 | 0 | GREEN |
| `Biotak/DrawStrip.mqh` | 5733 | 5732 | 1 | 1 | GREEN |
| `Biotak/DrawToolbar.mqh` | 1487 | 1486 | 1 | 1 | GREEN |
| `Biotak/DynamicTradingDayDetector.mqh` | 137 | 136 | 1 | 1 | GREEN |
| `Biotak/ErrorCodes.mqh` | 55 | 55 | 0 | 0 | GREEN |
| `Biotak/EventHandlers.mqh` | 3327 | 3327 | 0 | 0 | GREEN |
| `Biotak/ExtendedDrawingFunctions.mqh` | 1267 | 1267 | 0 | 0 | GREEN |
| `Biotak/FactorMode.mqh` | 101 | 101 | 0 | 0 | GREEN |
| `Biotak/FloatingPointHelper.mqh` | 148 | 148 | 0 | 0 | GREEN |
| `Biotak/FractalTimeframes.mqh` | 197 | 197 | 0 | 0 | GREEN |
| `Biotak/FrequencyOptimizer.mqh` | 671 | 671 | 0 | 0 | GREEN |
| `Biotak/GlobalVariables.mqh` | 651 | 651 | 0 | 0 | GREEN |
| `Biotak/HRayTool.mqh` | 437 | 437 | 0 | 0 | GREEN |
| `Biotak/HTFCandles.mqh` | 996 | 996 | 0 | 0 | GREEN |
| `Biotak/HistoricalDataFunctions.mqh` | 98 | 98 | 0 | 0 | GREEN |
| `Biotak/InputValidationEnhanced.mqh` | 167 | 167 | 0 | 0 | GREEN |
| `Biotak/InputValidator.mqh` | 311 | 311 | 0 | 0 | GREEN |
| `Biotak/LabelFunctions.mqh` | 1414 | 1414 | 0 | 0 | GREEN |
| `Biotak/LevelPipeline.mqh` | 1205 | 1205 | 0 | 0 | GREEN |
| `Biotak/Logger.mqh` | 236 | 236 | 0 | 0 | GREEN |
| `Biotak/MarketHoursDetector.mqh` | 89 | 89 | 0 | 0 | GREEN |
| `Biotak/MathConstants.mqh` | 2 | 2 | 0 | 0 | GREEN |
| `Biotak/ModeDefinitions.mqh` | 152 | 152 | 0 | 0 | GREEN |
| `Biotak/ObjectCache.mqh` | 527 | 527 | 0 | 0 | GREEN |
| `Biotak/ObjectCountManager.mqh` | 175 | 175 | 0 | 0 | GREEN |
| `Biotak/ObjectFunctions.mqh` | 147 | 147 | 0 | 0 | GREEN |
| `Biotak/PathTool.mqh` | 833 | 833 | 0 | 0 | GREEN |
| `Biotak/PerformanceOptimizations.mqh` | 329 | 329 | 0 | 0 | GREEN |
| `Biotak/Profiler.mqh` | 78 | 78 | 0 | 0 | GREEN |
| `Biotak/ProjectConstants.mqh` | 126 | 126 | 0 | 0 | GREEN |
| `Biotak/PropertiesAndInputs.mqh` | 284 | 284 | 0 | 0 | GREEN |
| `Biotak/PropertyChangeDetector.mqh` | 77 | 77 | 0 | 0 | GREEN |
| `Biotak/RuntimeSettings.mqh` | 1172 | 1172 | 0 | 0 | GREEN |
| `Biotak/StandardTimeframes.mqh` | 25 | 25 | 0 | 0 | GREEN |
| `Biotak/TH3Tool.mqh` | 2458 | 2457 | 1 | 1 | GREEN |
| `Biotak/THCalculations.mqh` | 176 | 176 | 0 | 0 | GREEN |
| `Biotak/TimeframeFunctions.mqh` | 52 | 52 | 0 | 0 | GREEN |
| `Biotak/TradePlanFormulas.mqh` | 206 | 206 | 0 | 0 | GREEN |
| `Biotak/UtilityFunctions.mqh` | 730 | 730 | 0 | 0 | GREEN |
| `Biotak/VisibilityManager.mqh` | 337 | 337 | 0 | 0 | GREEN |
| `Biotak/WaveAnalysis.mqh` | 268 | 268 | 0 | 0 | GREEN |
| `Biotak/ZoneCalculator.mqh` | 219 | 219 | 0 | 0 | GREEN |
| `Biotak/ZoneConfig.mqh` | 36 | 36 | 0 | 0 | GREEN |
| `Biotak/ZoneConstants.mqh` | 93 | 93 | 0 | 0 | GREEN |
| `Biotak/ZoneFactory.mqh` | 366 | 366 | 0 | 0 | GREEN |
| `Biotak/ZoneRenderer.mqh` | 197 | 197 | 0 | 0 | GREEN |
| `Biotak/ZoneValidator.mqh` | 138 | 138 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Controller.mqh` | 232 | 232 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Math.mqh` | 649 | 649 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3PatternStore.mqh` | 70 | 70 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Pivots.mqh` | 1236 | 1236 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Renderer.mqh` | 1537 | 1537 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Types.mqh` | 71 | 71 | 0 | 0 | GREEN |
| `ENTRY` | 123 | 123 | 0 | 11 | GREEN |
| `ENTRY-LITE` | 57 | 57 | 0 | 11 | GREEN |

## ۳. ماژول‌هایی که عدد می‌سازند و رسم می‌کنند

| ماژول | خطوط یک‌طرفه | فقط MT4 | فقط MT5 | وضعیت |
|---|---|---|---|---|
| `Biotak/ATRCalculations.mqh` | 2 | 1 | 1 | GREEN |
| `Biotak/AdaptiveScaling.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/BasePriceManager.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/ComboEngine.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/FractalTimeframes.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/LabelFunctions.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/LevelPipeline.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/THCalculations.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/TradePlanFormulas.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/ZoneCalculator.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/ZoneFactory.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/ZoneRenderer.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/ZoneValidator.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Math.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Pivots.mqh` | 0 | 0 | 0 | GREEN |
| `Biotak/TH3/TH3Renderer.mqh` | 0 | 0 | 0 | GREEN |

## ۴. بازنشسته‌شده‌ها (خارج از بیلد، در `_retired/mql5-extras-2026-10-03/`)

معماری MT5 قدیمی، از بیلد بیرون و آرشیو شد؛ MT4 نظیرشان را ندارد:

- `Biotak`
- `MT5Compat`

ویژگی‌هایی که حذف شدند (نه فقط فایل): نوار سنجاق‌شده (Ribbon)، پالت ChartTools و CardCover، حالت TH سه‌گانه، قفل سوم دید (auto-scroll)، گروه‌بندی اشیا، نوع رسم Price Note، فیلتر نوشتن تکراری، دامپ و پروب تشخیصی — همه از بیلد بیرون رفتند.

لایهٔ پلتفرم که لازم است: `MT5Compat/MQL5Compat.mqh` (شیم API مقلد MQL4). این فیچر نیست؛ فقط کاری می‌کند منبع MT4 روی MQL5 کامپایل و مثل MT4 رفتار کند.

## ۵. وضعیت بیلد

```
Biotak Trigger TH3.mq5      : 0 errors, 0 warnings
Biotak Trigger TH3 Lite.mq5 : 0 errors, 0 warnings
Biotak Sync Compare.mq5     : 0 errors, 0 warnings
tools/parity/Biotak Sync Compare.mq4 (AMarkets MT4): 0 errors, 1 warnings
                        (warning 46 در PathTool.mqh — از قبل روی هستهٔ MT4)
```

## ۶. بازتولید و بازبینی

```
python tools/parity/module-report.py            # جدول و حکم
python tools/parity/resync-module.py --write --all   # ماژول‌های قرمز را از MT4 بازساز
python tools/parity/resync-module.py --entry --write # ورودی‌های .mq5
python tools/parity/resync-module.py --refresh --write # اعمال پچ‌های جدید روی همه
python tools/parity/parity-doc.py               # همین سند
```

آزمون رفتاری پایان‌بخش: `Biotak Sync Compare` را روی یک چارت تازه و با تنظیمات یکسان در هر دو ترمینال بیندازید و سپس `python tools/parity/parity-diff.py --mt4 <MQL4/Files> --mt5 <MQL5/Files> --bar latest`.
