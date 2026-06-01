# Biotak Trigger TH3 — پرامپت کامل مهاجرت MT5 → MT4

> **هدف:** نسخه MT4 این اندیکاتور را **دقیقاً** مثل MT5 کن، شامل تمام رفتارهای ریز.
> این پرامپت برای یک AI coding agent طراحی شده که بدون نیاز به توضیح اضافه،
> مستقیم کد بزند.

---

## ۱. زمینه پروژه

نام اندیکاتور: **Biotak Trigger TH3**
فرمول: استاد سعید خاکستار (MotiveWave Java implementation)
نسخه: 3.10
زبان مبدا: MQL5 (MT5)
زبان هدف: MQL4 (MT4)

### ۱.۱ ساختار فایل‌های MT5 (مرجع)

```
Biotak Trigger TH3.mq5              ← فایل اصلی (فقط entry points)
Biotak/
  BuildConfig.mqh                   ← کنترل debug/log کامپایل
  MQL5Compat.mqh                    ← لایه compatibility
  PropertiesAndInputs.mqh           ← همه inputs (گروه‌بندی ۱–۲۲)
  ConstantsAndEnums.mqh             ← تمام enum ها و constant های اصلی
  ProjectConstants.mqh              ← ثابت‌های پروژه + FrequencyResult struct
  MathConstants.mqh                 ← SS/LS/E/ATR multipliers
  FloatingPointHelper.mqh           ← EPSILON ها + IsZero/AreEqual
  GlobalVariables.mqh               ← تمام global state variables
  InputValidator.mqh                ← validate کردن inputs در OnInit
  UtilityFunctions.mqh              ← توابع کمکی عمومی
  CalculationCache.mqh              ← کش محاسبات TH و timeframe
  THCalculations.mqh                ← فرمول اصلی TH
  ATRCalculations.mqh               ← weighted ATR
  AdaptiveScaling.mqh               ← سیستم ATR adaptive scaling
  BasePriceHistoryManager.mqh       ← تاریخچه base price
  BasePriceManager.mqh              ← مدیریت base price (M30 blocks)
  MarketHoursDetector.mqh           ← تشخیص ساعت بازار
  DynamicTradingDayDetector.mqh     ← تشخیص session start
  TimeframeFunctions.mqh            ← توابع timeframe
  FractalTimeframes.mqh             ← نگاشت timeframe → fractal %
  WaveAnalysis.mqh                  ← XABC wave + Gilmore ratios
  FrequencyOptimizer.mqh            ← Spectral Resonance Engine (v5.1)
  TH3Tool.mqh                       ← ابزار AB=CD رسم و تعامل
  ObjectFunctions.mqh               ← ایجاد/حذف object های چارت
  ExtendedDrawingFunctions.mqh      ← توابع رسم پیشرفته
  UnifiedZoneSystem.mqh             ← سیستم zone یکپارچه
  ZoneFactory.mqh                   ← factory برای zone
  ZoneValidator.mqh                 ← اعتبارسنجی zone
  ZoneConstants.mqh                 ← ثابت‌های zone
  ZoneTrackingHelpers.mqh           ← کمک‌های tracking zone
  LevelPipeline.mqh                 ← pipeline محاسبه→zone→line
  LabelFunctions.mqh                ← رسم labels روی چارت
  AlertFunctions.mqh                ← سیستم alert
  HistoricalDataFunctions.mqh       ← high/low تاریخی
  VisibilityManager.mqh             ← hide/show بدون حذف object
  ObjectCache.mqh                   ← کش object های چارت
  ObjectCountManager.mqh            ← شمارش و cleanup objects
  PropertyChangeDetector.mqh        ← تشخیص تغییر property
  PerformanceOptimizations.mqh      ← بهینه‌سازی‌های عملکرد
  AdaptiveScaling.mqh               ← scaling بر اساس ATR
  Profiler.mqh                      ← profiling (debug only)
  Logger.mqh                        ← سیستم log چند سطحی
  EventHandlers.mqh                 ← OnInit/OnDeinit/OnCalculate/OnChartEvent/OnTimer
```

---

## ۲. تفاوت‌های اصلی MQL5 vs MQL4 که باید رفع شوند

### ۲.۱ API تفاوت‌های حیاتی

| موضوع | MQL5 | MQL4 معادل |
|-------|------|-------------|
| قیمت فعلی | `SymbolInfoDouble(_Symbol, SYMBOL_BID)` | `Bid` |
| تعداد کندل | `Bars(_Symbol, _Period)` | `Bars` |
| زمان کندل | `iTime(_Symbol, _Period, i)` | `iTime(NULL, 0, i)` |
| باز کندل | `iOpen(_Symbol, _Period, i)` | `iOpen(NULL, 0, i)` |
| بالا/پایین | `iHigh/iLow(_Symbol, _Period, i)` | `iHigh/iLow(NULL, 0, i)` |
| بسته کندل | `iClose(_Symbol, _Period, i)` | `iClose(NULL, 0, i)` |
| حجم | `iVolume(_Symbol, _Period, i)` | `iVolume(NULL, 0, i)` |
| کپی داده | `CopyTime/CopyClose/CopyHigh...` | حلقه مستقیم با iTime/iClose... |
| barshift | `iBarShift(_Symbol, _Period, time)` | `iBarShift(NULL, 0, time)` |
| نقطه | `SymbolInfoDouble(_Symbol, SYMBOL_POINT)` | `Point` |
| دیجیت | `SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)` | `Digits` |
| ATR | `iATR(_Symbol, _Period, period, i)` | `iATR(NULL, 0, period, i)` |
| Period seconds | `PeriodSeconds(ENUM_TIMEFRAMES)` | باید دستی پیاده شود |
| پریود عددی | `_Period` → enum | `Period()` → int |
| ObjectCreate | ۶ آرگومان | ۵ آرگومان (بدون subwindow) |
| OBJPROP_TIMEFRAMES | موجود | **موجود نیست** — بدیل: `OBJPROP_LEVELS` یا حذف+ایجاد مجدد |
| ChartSetInteger (MOUSE_MOVE) | موجود | `CHART_EVENT_MOUSE_MOVE` موجود نیست → فقط CHARTEVENT_MOUSEMOVE در OnChartEvent |
| EventSetTimer | موجود | موجود |
| GlobalVariable | یکسان | یکسان |
| StringSubstr | یکسان | یکسان |
| ArrayResize با reserve | `ArrayResize(arr, size, reserve)` | `ArrayResize(arr, size)` — بدون reserve |

### ۲.۲ ساختار indicator

**MT5:**
```mql5
#property indicator_chart_window
#property indicator_plots 0

int OnCalculate(const int rates_total, const int prev_calculated,
    const datetime &time[], const double &open[], const double &high[],
    const double &low[], const double &close[],
    const long &tick_volume[], const long &real_volume[], const int &spread[])
```

**MT4:**
```mql4
#property indicator_chart_window
#property indicator_buffers 0

int start()  // یا int OnCalculate با signature ساده‌تر
// MT4 signature:
int OnCalculate(const int rates_total, const int prev_calculated,
    const datetime &time[], const double &open[], const double &high[],
    const double &low[], const double &close[],
    const long &tick_volume[], const long &volume[], const int &spread[])
// real_volume در MT4 وجود ندارد → همان tick_volume استفاده شود
```

---

## ۳. ماژول‌ها و رفتارهای دقیق که باید عیناً port شوند

### ۳.۱ فرمول TH (هسته اصلی)

```
TH = (basePrice × fractalPercentage) / 100.0
```

**basePrice** = قیمت بسته شدن روز قبل (close) — از `ENUM_APPLIED_PRICE`

**fractalPercentages (MODIFIED_FRACTAL_PERCENTAGES):**
```
M1:          0.0208%
M4:          0.0417%
M16:         0.0833%
H1+M4:       0.1666%
H4+M16:      0.3333%
D2+H20+M16:  1.3332%
D11+H9+M4:   2.6664%
D45+H12+M16: 5.3328%
```

نگاشت timeframe → fractal (از `MinutesToFractalString` در TimeframeFunctions.mqh):
```
PERIOD_M1  (1 min)   → "M1"          → 0.0208%
PERIOD_M5  (5 min)   → "M4"          → 0.0417%
PERIOD_M15 (15 min)  → "M16"         → 0.0833%
PERIOD_M30 (30 min)  → "M16"         → 0.0833%  ← M30 هم M16 می‌شود
PERIOD_H1  (60 min)  → "H1+M4"       → 0.1666%
PERIOD_H4  (240 min) → "H4+M16"      → 0.3333%
PERIOD_D1  (1440 min)→ "D2+H20+M16"  → 1.3332%  ← (نه H17+M4!)
PERIOD_W1            → "D11+H9+M4"   → 2.6664%
PERIOD_MN1           → "D45+H12+M16" → 5.3328%
```

> **توجه مهم:** رشته `"H17+M4"` با percentage 0.6666% در جدول fractal percentages وجود دارد
> اما هیچ timeframe استانداردی با `MinutesToFractalString` به آن map **نمی‌شود**.
> این مقدار فقط در صورتی استفاده می‌شود که user مستقیماً custom TH frequency آن را انتخاب کند.

**ضرایب step:**
```
SS = TH × 1.5   (Short Step)
LS = TH × 2.0   (Long Step)
E  = TH × 0.75  (E Step)
TP = E  × 3.0   = TH × 2.25
```

### ۳.۲ حالت‌های محاسبه (ENUM_STEP_CALCULATION_MODE)

همه ۶ حالت باید پیاده‌سازی شوند:

| حالت | توضیح |
|------|--------|
| `TH_STEP` | خطوط با فاصله برابر TH |
| `SS_LS_STEP` | تناوب SS و LS (کنترل توسط `inpLSFirst`) |
| `M_STEP` | سطوح M بر اساس MSTEP_BASIS (C-based یا M-based) |
| `TP_STEP` | TP = TH × 2.25 |
| `COMBO_STEP` | ترکیب دو component با operator (Plus/Average/...) |
| `FACTOR_STEP` | `stepSize = (High - Low) / (Factor × 2)` |

### ۳.۳ Pipeline سطوح (LevelPipeline)

معماری **Zone-First** — این ترتیب باید حفظ شود:

```
Stage 1: CalculateLevels  → قیمت‌های خام (SCalculatedLevel[])
Stage 2: ClassifyLevels   → رنگ/سبک/structure/trigger تعیین شود
Stage 3: BuildZones       → zones اطراف سطوح (PRIMARY entity)
Stage 4: DeriveTriggers   → خطوط از مرز zones
Stage 5: RenderAll        → اول zones، بعد خطوط
```

**ساختار طبقه‌بندی Structure:**
```
L1 = base × 1
L2 = base × 2
L3 = base × 4  (base × 2^2)
L4 = base × 8  (base × 2^3)
L5 = base × 16 (base × 2^4)
```
هر سطح دقیقاً ۲ برابر قبلی (نسبت fractal حفظ شود).

### ۳.۴ Adaptive Scaling (ATR)

سه حالت `ENUM_ADAPTIVE_MODE`:

1. **FIXED**: `scalingFactor = 1.0` — بدون تغییر
2. **ATR_ADAPTIVE**: `scalingFactor = weightedATR / theoreticalTH`
3. **BLENDED**: `scalingFactor = blend_ratio × ATR_factor + (1 - blend_ratio) × 1.0`

smoothing با EMA: `α = 2 / (smoothingPeriod + 1)`
فقط روی bar close (نه هر tick) update شود.

### ۳.۵ Weighted ATR (ATRCalculations)

**Periods و Weights — دقیقاً یکسان با Java OptimizedCalculations:**
```
Period  5   → Weight 1
Period  10  → Weight 1
Period  21  → Weight 2
Period  66  → Weight 3
Period  132 → Weight 5
Period  264 → Weight 8
Total weight = 20  (Fibonacci: 1+1+2+3+5+8)
```

**فرمول:**
```
weightedATR = (ATR5×1 + ATR10×1 + ATR21×2 + ATR66×3 + ATR132×5 + ATR264×8) / 20
```

**True Range — دقیقاً این فرمول:**
```
prevClose = Close[barIndex+1]   (اگر barIndex == lastBar → از Open استفاده شود)
TR = max(High-Low, |High-prevClose|, |Low-prevClose|)
```

**Cache TTL:**
```
ATR_CACHE_TTL_SECONDS = 30
ATR_CACHE_BAR_TOLERANCE = 1
ATR_WARMUP_GATE_SECONDS = 90  ← اگر < 90s از warmup قبلی → skip
```

**MT5 vs MT4:**
- **MT5:** از handle cache 16-slot (`iATRMQL4()` در MQL5Compat.mqh)
- **MT4:** مستقیم `iATR(symbol, tf, period, shift)` → double بر می‌گرداند
  - کل ATR handle cache باید حذف/stub شود
  - `ReleaseATRHandle()`, `InitATRCache()`, `WarmupATRMultiTFCache()` → stub با بدنه خالی

### ۳.۶ Base Price Manager

**منطق دقیق:**
- base price = قیمت آخرین M30 bar **کامل** (نه جاری)
- هر ۳۰ دقیقه یک block جدید
- session start از `DynamicTradingDayDetector` تشخیص داده می‌شود
- gap > 120 دقیقه = آغاز session جدید
- در MT4: `iTime/iClose(NULL, PERIOD_M30, i)` برای M30 bars

**رفتار ریز critical:**
```
g_dailyClosePriceForTH = GetPriceForPreviousDay(inpTHPriceType)
```
این مقدار در OnInit محاسبه شود. اگر قابل دسترس نبود → `INIT_FAILED` برگرداند.

### ۳.۷ Base Price Threshold

```
if (|newBasePrice - currentBasePrice| / currentBasePrice < inpBasePriceThresholdPercent / 100)
    → تغییر نده (base price را ثابت نگه دار)
```

این رفتار جلوگیری از جهش‌های کوچک را می‌کند.

### ۳.۸ VisibilityManager — رفتار hide/show

در MT5 از `OBJPROP_TIMEFRAMES` استفاده می‌شود:
- `OBJ_ALL_PERIODS = 0xFFFFFFFF` → نمایش در همه timeframe
- `OBJ_NO_PERIODS = 0` → پنهان (بدون حذف)

**در MT4 این property موجود نیست.**
بدیل صحیح برای MT4:
- **hide:** object را حذف کن ولی state را در آرایه ذخیره کن
- **show:** دوباره بساز با همان property های ذخیره شده

یا از `OBJPROP_COLOR` با `clrNONE` برای fake-hide استفاده کن (اما این روش ناقص است).

**روش پیشنهادی:**
```mql4
// Cache the object properties, delete, and recreate on show
struct ObjectSnapshot {
    string name;
    ENUM_OBJECT type;
    double price1, price2;
    datetime time1, time2;
    color clr;
    int style, width;
    bool isHidden;
};
```

### ۳.۸.۱ Input Groups 17-22 (کامل — از PropertiesAndInputs.mqh)

**گروه 17 — Alerts:**
```
inpEnableHighLowAlerts   = false
inpEnableTHAlerts        = false
inpEnableStructureTHAlerts = false
inpAlertOnce             = true     ← فقط یکبار per bar
inpPlaySound             = false
inpAlertSoundFile        = "alert.wav"
inpSendNotification      = false
inpSendEmail             = false
```

**گروه 18 — Mode Label:**
```
inpShowModeChangeLabel   = true
inpModeLabelDuration     = MODE_LABEL_3_SEC  (3000ms)
inpModeLabelCorner       = CORNER_LEFT_UPPER
inpModeLabelXDistance    = 15
inpModeLabelYDistance    = 25
inpModeLabelFontSize     = 11
inpModeLabelColor        = clrNavy
```

**گروه 19 — Hotkeys (همه string، user-configurable):**
```
inpHideKey               = "F"
inpLinesToggleKey        = "L"
inpLockKey               = "G"
inpCustomPriceKey        = "C"
inpTriggerLevelsKey      = "T"
inpStepModeKey           = "E"
inpTH3ToolKey            = "V"
inpATRLabelsKey          = "A"
inpTHLabelsKey           = "S"
inpResetKey              = "Q"
```

**گروه 20 — Objects:**
```
inpObjectPrefix          = "THLevels"
inpTHLineObjectType      = OBJ_HLINE  (یا OBJ_TREND)
inpLabelCornerPosition   = CORNER_LEFT_UPPER
inpLabelArrangement      = LABEL_ARRANGE_VERTICAL
```
فرمت prefix نهایی: `inpObjectPrefix + "_" + currentTF + "_"` → مثال: `"THLevels_H1_"`

**گروه 21 — Label Layout Margins:**
```
inpLabelsMarginTop       = 25    (px از بالا)
inpLabelsMarginLeft      = 20    (px از چپ)
inpLabelsMarginBottom    = 5
inpTHLabelsMarginBottom  = 15
inpLabelRowGap           = 16    (فاصله بین rows)
inpLabelColumnGap        = 45    (فاصله بین ستون‌ها)
inpSectionGap            = 23    (فاصله بین sections)
inpMaxLabelWidth         = 250   (max width یک label)
```

**گروه 22 — History & Log:**
```
inpHistoricalTimeframe   = PERIOD_CURRENT
inpHistoricalPeriods     = 0      (0 = همه bars)
inpLogLevel              = LOG_LEVEL_WARN
```

### ۳.۹ TH3 Tool (AB=CD Pattern)

رفتارهای دقیق که باید port شوند:

**کلیک‌های keyboard (همه user-configurable, defaults):**
| کلید (default) | input | عملکرد |
|----------------|-------|---------|
| `F` | `inpHideKey` | toggle hide/show همه objects |
| `L` | `inpLinesToggleKey` | toggle نمایش lines |
| `G` | `inpLockKey` | toggle timeframe lock ← **(نه L!)** |
| `C` | `inpCustomPriceKey` | custom price click mode |
| `T` | `inpTriggerLevelsKey` | toggle trigger levels |
| `E` | `inpStepModeKey` | cycle step mode ← **(نه 1/2!)** |
| `V` | `inpTH3ToolKey` | TH3 tool (AB=CD) toggle |
| `A` | `inpATRLabelsKey` | toggle ATR labels |
| `S` | `inpTHLabelsKey` | toggle TH labels |
| `Q` | `inpResetKey` | reset همه به default |
| `3` | hardcode | `CycleTH3Frequency()` — index+1, بدون wrap, max=256 |
| `4` | hardcode | `DecrementTH3Frequency()` — index-1, بدون wrap, min=1 |
| `+` یا `=` | hardcode | `AdjustFactorValue(+step)` |
| `-` | hardcode | `AdjustFactorValue(-step)` |

**مهم در پیاده‌سازی `IsHotkeyPressed`:**
هم `lparam` (keycode) هم `sparam` (key text) بررسی شود تا keyboard layout های مختلف پشتیبانی شوند.

**Double-click روی چارت → شروع رسم AB=CD:**
- click اول: نقطه A
- click دوم: نقطه B
- click سوم: نقطه C → D محاسبه شود
- `D = C + (B - A)` برای bullish
- `D = C - (B - A)` برای bearish

**ثبت pattern در registry:**
```
g_th3PatternRegistry[] — string array از basename ها
```
این باید در MT4 هم دقیقاً حفظ شود چون bulk update از آن استفاده می‌کند.

### ۳.۱۰ Frequency Optimizer (Spectral Resonance)

**Binary Subdivision System:**
```
freq(index) = index × 1.5625%
range: index 1 (1.5625%) تا 256 (400%)
default index: 18 → 28.125%
```

**وزن‌های scoring:**
```
WEIGHT_MULTISTEP = 0.35
WEIGHT_PATTERN   = 0.12
WEIGHT_TIME      = 0.18
WEIGHT_SQRT      = 0.12  (Gann square root price harmony)
WEIGHT_HARMONIC  = 0.13
WEIGHT_HISTORY   = 0.10
```

**Steps محاسبه:**
```
baseUnit = |AB| × (freq / 100)
Step1 = C ± 1 × baseUnit
Step3 = C ± 3 × baseUnit  (هدف اصلی)
Step5 = C ± 5 × baseUnit
Step7 = C ± 7 × baseUnit
```

**History ring buffer:** آخرین ۸ pattern در `g_freqHistory[]` (FREQ_HISTORY_SIZE=8)

### ۳.۱۱ Wave Analysis (Gilmore Sacred Ratios)

ساختار WaveData شامل:
```
midArithmetic = (start + end) / 2
midGann       = (√start + √end)² / 4   ← Gann geometric midpoint
quarter25     = start + 0.25 × (end - start)
quarter75     = start + 0.75 × (end - start)
fib382        = start + 0.382 × (end - start)
fib618        = start + 0.618 × (end - start)   ← Golden Ratio
fib786        = start + 0.786 × (end - start)   ← √φ
```

در `BuildWaveData` از `iBarShift` برای `barDuration` استفاده می‌شود — در MT4 همین API موجود است.

### ۳.۱۲ Zone System

**Zone height formula:**
```
zoneHeight = stepSize × (heightPercent / 100) × 0.5
midPoint   = (prevLevel + currentLevel) / 2
upper      = midPoint + zoneHeight
lower      = midPoint - zoneHeight
```

**Zone styles:**
- `ZONE_STYLE_BOX_FILLED`  → `OBJ_RECTANGLE` با fill
- `ZONE_STYLE_LINES`       → دو `OBJ_HLINE` (بالا و پایین)
- `FACTOR_ZONE_HIDDEN`     → حذف zone

در MT4:
- `OBJ_RECTANGLE` → با OBJPROP_FILL (MT4 build >= 600 این را دارد)
- اگر نداشت: دو خط افقی جایگزین شود

### ۳.۱۳ Dynamic Trading Day Detector

```
session gap threshold: 120 دقیقه
7 روز lookback برای M1 bars
اگر gap > 120min بین دو bar → شروع session جدید
block size: 30 دقیقه
```

در MT4 از `iTime(NULL, PERIOD_M1, i)` در حلقه استفاده شود.
`CopyTime` در MT4 موجود نیست — جایگزین با حلقه.

### ۳.۱۴ Global Variables (state persistence بین reload)

همه state ها با `GlobalVariable` ذخیره می‌شوند:
```
Biotak_isHidden_{chartId}         ← hide state
Biotak_TriggerLevels_{chartId}    ← trigger toggle
Biotak_LinesVisible_{chartId}     ← lines toggle
Biotak_ATRLabels_{chartId}        ← ATR labels toggle
Biotak_THLabels_{chartId}         ← TH labels mode (0 یا 1)
Biotak_LockTF_{chartId}           ← timeframe lock bool
Biotak_LockTFPeriod_{chartId}     ← locked period int
Biotak_StepMode_{chartId}         ← step mode override (-1 تا 5)
Biotak_Factor_{chartId}           ← factor value override
Biotak_TH3Freq_{chartId}          ← TH3 frequency index
Biotak_CustomPrice_{symbol}       ← custom base price
Biotak_CustomPriceOverride_{symbol} ← آیا keyboard override فعال است
Biotak_LastTFSwitch_{chartId}     ← زمان آخرین تغییر timeframe
```

در MT4 عملکرد `GlobalVariable*` کاملاً یکسان است.

### ۳.۱۵ Object Naming Convention

همه object ها با prefix شروع می‌شوند:
```
"TH3_{symbol}_{timeframe}_{type}_{index}"
```
نام‌گذاری دقیق از `ObjectFunctions.mqh` استخراج شود.
**این naming باید عیناً در MT4 حفظ شود** چون cleanup بر اساس prefix کار می‌کند.

### ۳.۱۶ ChartRedraw Throttling

```
CHART_REDRAW_THROTTLE_MS = 100  ← حداکثر هر 100ms یک ChartRedraw
DRAG_REDRAW_THROTTLE_MS  = 50   ← در حین drag هر 50ms
```

رفتار ریز: `ThrottledChartRedraw()` باید tick count مقایسه کند.
در MT4 از `GetTickCount()` استفاده شود (یکسان است).

---

## ۴. رفتارهای ریز حیاتی (micro-behaviors)

### ۴.۱ Custom Price Line Drag
- کاربر یک `OBJ_HLINE` را drag می‌کند
- `CHARTEVENT_OBJECT_DRAG` شناسایی می‌شود
- `g_customPriceLineDragging = true` در هنگام drag
- پس از رها کردن، base price به موقعیت جدید خط update می‌شود
- `GlobalVariableSet(gvarName, newPrice)` فراخوانی می‌شود
- `g_customPriceKeyboardOverride = true` تنظیم می‌شود

### ۴.۲ Magnet (snap) برای custom price
```
inpEnableMagnet = true
inpMagnetSensitivityPips = 10
```
اگر قیمت click نزدیک‌تر از ۱۰ pip به یک سطح TH بود → snap به آن سطح

### ۴.۳ Timeframe Lock
- وقتی lock فعال است `g_timeframeLocked = true`
- محاسبات با `g_lockedPeriod` انجام می‌شود نه `_Period`
- label "🔒 TF: {period}" روی چارت نمایش داده می‌شود

### ۴.۴ Defer Heavy Init (TF switch optimization)
```
اگر آخرین تغییر TF کمتر از ۲۰ ثانیه پیش بود:
  g_initialized = false   (defer محاسبات سنگین)
  g_systemInitialized = false

در اولین OnCalculate:
  UpdateHistoricalValues() اجرا شود
  g_initialized = true
```

### ۴.۵ Object Delete Cascade Prevention
```
g_suppressDeleteEvents = true  قبل از حذف programmatic
```
این جلوگیری می‌کند از اینکه `CHARTEVENT_OBJECT_DELETE` برای حذف programmatic trigger شود.

### ۴.۶ Label Expiry (auto-clear labels بعد از چند ثانیه)
```
g_stepModeLabelCreateTime  ← tick count ایجاد
g_factorLabelCreateTime
g_th3FreqLabelCreateTime
```
در `OnTimer` (هر ۱ ثانیه):
- اگر بیش از X ثانیه گذشت → label را حذف کن

### ۴.۷ ATR Labels Visibility
اگر `inpShowATRLabels = false` باشد در Inputs:
- حتی اگر keyboard toggle فعال باشد، ATR labels نمایش نده
- `g_atrLabelsVisible` در OnInit force به false

### ۴.۸ TH Labels Mode (g_thLabelsMode)
```
0 = OFF
1 = FRACTAL (نمایش label برای Fractal THs)
```
هر بار keyboard `F` زده می‌شود: toggle بین 0 و 1
در `GlobalVariable` ذخیره می‌شود.

### ۴.۹ Hidden State Caching
```
HIDDEN_CACHE_TTL_MS = 100  ← هر ۱۰۰ms cache refresh شود  ← (نه 500!)
```
```mql
g_isHiddenCached    ← cached bool
g_isHiddenCacheTime ← tick count آخرین cache
```
`IsIndicatorHidden()` این cache را چک می‌کند.

### ۴.۱۰ Incremental Object Cleanup
```
CLEANUP_INTERVAL_SECONDS = 60  ← هر ۶۰ ثانیه cleanup اجرا شود
OBJECT_COUNT_INCREASE_THRESHOLD = 30  ← اگر object count 30 تا افزایش یافت
```
در `OnTimer` فراخوانی می‌شود — نه در OnCalculate.

### ۴.۱۱ Double Click Detection
```
DOUBLE_CLICK_THRESHOLD_MS = 300
```
دو click با فاصله کمتر از ۳۰۰ms = double click → ابت رسم AB=CD

### ۴.۱۲ Debounce برای ABCD clicks
```
ABCD_DEBOUNCE_MS = 300
```
بین هر click ABCD حداقل ۳۰۰ms فاصله

---

## ۵. ساختار سیستم Combo Step

```
Topology:
  TOPOLOGY_DUAL_GROUP  ← دو گروه component
  TOPOLOGY_TRIPLE      ← سه component

Components (ENUM_COMBO_COMPONENT_ITEM):
  COMP_TRIGGER_SS    ← SS از timeframe جاری
  COMP_TRIGGER_LS    ← LS از timeframe جاری
  COMP_TRIGGER_TH    ← TH از timeframe جاری
  COMP_PATTERN_TH    ← TH × 4 (pattern timeframe)
  COMP_STRUCTURE_TH  ← TH × 16 (structure timeframe)
  COMP_IGNORE        ← این slot خالی است

Operators (ENUM_COMBO_OPERATOR):
  OP_PLUS     ← A + B
  OP_MINUS    ← A - B
  OP_AVERAGE  ← (A + B) / 2
  OP_NONE     ← فقط A (B نادیده گرفته می‌شود)
```

**Presets در MT4 هم باید پیاده شوند:**
```
COMBO_PRESET_BALANCED_MEDIUM  ← پیش‌فرض
QUICK_PRESET_TRIGGER_PATTERN  ← quick test
```

---

## ۶. سیستم Logger

۴ سطح log:
```
LOG_LEVEL_ERROR   = 0  (E)
LOG_LEVEL_WARNING = 1  (W)
LOG_LEVEL_INFO    = 2  (I)
LOG_LEVEL_DEBUG   = 3  (D)
```

در release build:
```
ENABLE_DEBUG_LOGS  ← تعریف نشده → همه _LOG_GATE_D و DEBUG_PRINTF حذف می‌شوند
```

Macros مهم:
```mql5
_LOG_GATE_E    ← فقط اگر level >= ERROR
_LOG_GATE_W    ← فقط اگر level >= WARNING
_LOG_GATE_D    ← فقط اگر ENABLE_DEBUG_LOGS تعریف شده باشد
DEBUG_PRINTF   ← مثل _LOG_GATE_D
```

---

## ۷. Chart Events که باید handle شوند

```
CHARTEVENT_CLICK          ← کلیک روی چارت (custom price + ABCD)
CHARTEVENT_OBJECT_CLICK   ← کلیک روی object
CHARTEVENT_OBJECT_DRAG    ← drag custom price line
CHARTEVENT_OBJECT_DELETE  ← حذف object توسط کاربر (ABCD cleanup)
CHARTEVENT_KEYDOWN        ← تمام hotkeys
CHARTEVENT_CHART_CHANGE   ← تغییر اندازه/scroll چارت
CHARTEVENT_MOUSE_MOVE     ← حرکت موس (در MT5 باید enable شود)
```

در MT4: `CHARTEVENT_MOUSE_MOVE` به صورت خودکار fire نمی‌شود.

---

## ۸. نکات ویژه porting به MT4

### ۸.۱ struct constructor/method
در MQL4 **struct method** موجود نیست (قبل از MT4 build 600+).
```mql5
// MT5:
struct WaveData {
    void Reset() { ... }
};

// MT4 بدیل:
void ResetWaveData(WaveData &wave) { ... }
```
برای build های جدید MT4 (600+) struct methods پشتیبانی می‌شود.
**بررسی کن و اگر ممکن بود از struct methods استفاده کن.**

### ۸.۲ static در داخل function
```mql4
// MT4 پشتیبانی می‌کند:
void Func() {
    static double cached = 0.0;
}
```
این رفتار یکسان است.

### ۸.۳ #ifndef guards
دقیقاً یکسان در MT4 و MT5.

### ۸.۴ ArrayResize با reserve
```mql5
// MT5:
ArrayResize(arr, size, 16);  // reserve 16 slots

// MT4 (reserve parameter نداری):
ArrayResize(arr, size);
```

### ۸.۵ OBJPROP_FILL برای Rectangle
```mql4
// MT4 (build >= 600):
ObjectSetInteger(0, name, OBJPROP_FILL, true);

// MT4 قدیمی (اگر FILL نداشت):
// رنگ border = رنگ fill → visual fake effect
```

### ۸.۶ CopyTime/CopyClose جایگزین
```mql4
// MT4 بدیل CopyTime:
for(int i = 0; i < count; i++) {
    barTimes[i] = iTime(NULL, PERIOD_M1, startBar + i);
}
```

### ۸.۷ PeriodSeconds بدیل
```mql4
int PeriodSecondsCompat(int period) {
    switch(period) {
        case PERIOD_M1:  return 60;
        case PERIOD_M5:  return 300;
        case PERIOD_M15: return 900;
        case PERIOD_M30: return 1800;
        case PERIOD_H1:  return 3600;
        case PERIOD_H4:  return 14400;
        case PERIOD_D1:  return 86400;
        case PERIOD_W1:  return 604800;
        case PERIOD_MN1: return 2592000;
        default: return 60;
    }
}
```

### ۸.۸ GetCachedPeriod بدیل
```mql4
// MT5: _Period (ENUM_TIMEFRAMES)
// MT4: Period() returns int همان ENUM values
int GetCachedPeriod() { return Period(); }
```

---

## ۹. اولویت‌بندی پیاده‌سازی

**Phase 1 — Core (بدون این‌ها indicator کار نمی‌کند):**
1. `MQL5Compat.mqh` → `MQL4Compat.mqh` (تمام API shims)
2. `THCalculations.mqh` ← فرمول اصلی (مستقیم port شود)
3. `FractalTimeframes.mqh` ← نگاشت TF → percentage
4. `BasePriceManager.mqh` ← محاسبه base price
5. `LevelPipeline.mqh` ← pipeline اصلی
6. `EventHandlers.mqh` ← OnInit/OnCalculate
7. `ObjectFunctions.mqh` ← رسم خطوط

**Phase 2 — Features (قابلیت‌های کامل):**
8. `TH3Tool.mqh` ← AB=CD interactive tool
9. `FrequencyOptimizer.mqh` ← spectral scoring
10. `WaveAnalysis.mqh` ← wave analysis
11. `AdaptiveScaling.mqh` ← ATR adaptive
12. `UnifiedZoneSystem.mqh` ← zones

**Phase 3 — Polish (رفتارهای ریز):**
13. `VisibilityManager.mqh` ← hide/show بدون حذف
14. `AlertFunctions.mqh` ← alerts
15. `LabelFunctions.mqh` ← labels دقیق
16. `ObjectCountManager.mqh` ← cleanup
17. تمام hotkeys و keyboard events

---

## ۱۰. تست و اعتبارسنجی

### ۱۰.۱ Test Cases اجباری

**Test 1: TH محاسبه درست**
```
Symbol: XAUUSD (Gold)
basePrice: 2000.0
Timeframe: H1 → fractalPercentage = 0.1666
Expected TH: 2000 × 0.1666 / 100 = 3.332
```

**Test 2: Step modes**
```
TH = 3.332
SS = 3.332 × 1.5 = 4.998
LS = 3.332 × 2.0 = 6.664
TP = 3.332 × 0.75 × 3 = 7.497
```

**Test 3: Factor Step**
```
High = 2050, Low = 2000, Factor = 50
stepSize = (2050 - 2000) / (50 × 2) = 50 / 100 = 0.5
```

**Test 4: Base Price Threshold**
```
currentBase = 2000, newBase = 2001
threshold = 0.066%
diff% = (2001 - 2000) / 2000 × 100 = 0.05%
0.05% < 0.066% → base price تغییر نکند
```

**Test 5: Binary Subdivision**
```
index = 18 → freq = 18 × 1.5625 = 28.125%
index = 32 → freq = 32 × 1.5625 = 50.0%
index = 64 → freq = 64 × 1.5625 = 100.0%
```

### ۱۰.۲ Visual Comparison
روی یک چارت MT4 و MT5 همزمان:
- همان symbol، همان timeframe
- همان settings
- خطوط باید دقیقاً روی هم بیفتند (فاصله < 1 pip)

---

## ۱۱. چک‌لیست نهایی

- [ ] فرمول TH دقیقاً مطابق MotiveWave Java
- [ ] همه ۶ step mode پیاده‌سازی شده
- [ ] Base price از M30 bar صحیح محاسبه می‌شود
- [ ] Threshold check برای base price تغییر
- [ ] همه ۱۶ گروه input موجود هستند
- [ ] GlobalVariables state persistence کار می‌کند
- [ ] همه hotkeys کار می‌کنند
- [ ] AB=CD رسم و تعامل کامل
- [ ] Zone system کار می‌کند
- [ ] ATR adaptive scaling
- [ ] Frequency optimizer
- [ ] Hide/show بدون حذف object
- [ ] Timeframe lock
- [ ] Custom price drag
- [ ] Magnet snap
- [ ] Object cleanup هر ۶۰ ثانیه
- [ ] Label expiry auto-clear
- [ ] Cascade prevention در object delete
- [ ] Logger چند سطحی
- [ ] Debug compile mode
- [ ] Visual test با MT5 روی همان چارت

---

---

## ۱۲. موارد بحرانی که در بررسی دقیق کد پیدا شد (نسخه تکمیلی)

### ۱۲.۱ ATR Handle Cache — MT5 Specific (باید کامل بازنویسی شود)

در MT5 از `iATR(symbol, tf, period)` که یک **handle** برمی‌گرداند استفاده می‌شود.
در MT4 تابع `iATR` مستقیماً مقدار برمی‌گرداند.

**Cache که در MQL5Compat.mqh وجود دارد** (`iATRMQL4`) باید حذف شود چون در MT4 نیازی به handle cache نیست:

```mql4
// MT4 مستقیم:
double GetATRValue(string symbol, int tf, int period, int shift) {
    return iATR(symbol, tf, period, shift);
}
```

همچنین `ReleaseATRHandle()` و `InitATRCache()` در MT4 باید stub باشند (بدنه خالی).
`WarmupATRMultiTFCache()` هم در MT4 معنا ندارد.

### ۱۲.۲ ATR Periods و Weights — دقیقاً یکسان با Java

```
ATR_PERIOD_1  = 5   , ATR_WEIGHT_1 = 1
ATR_PERIOD_2  = 10  , ATR_WEIGHT_2 = 1
ATR_PERIOD_3  = 21  , ATR_WEIGHT_3 = 2
ATR_PERIOD_4  = 66  , ATR_WEIGHT_4 = 3
ATR_PERIOD_5  = 132 , ATR_WEIGHT_5 = 5
ATR_PERIOD_6  = 264 , ATR_WEIGHT_6 = 8
ATR_TOTAL_WEIGHT = 20 (Fibonacci: 1+1+2+3+5+8)
```

فرمول:
```
weightedATR = (ATR5×1 + ATR10×1 + ATR21×2 + ATR66×3 + ATR132×5 + ATR264×8) / 20
```

### ۱۲.۳ True Range Formula (نه ATR ساده)

```
TR = max(High-Low, |High-PrevClose|, |Low-PrevClose|)
prevClose = Close[barIndex+1]  (اگر barIndex == lastBar → از Open استفاده شود)
```

این باید **دقیقاً** این‌گونه محاسبه شود وگرنه ATR یکسان نمی‌شود.

### ۱۲.۴ Fractal Values — سلسله‌مراتب TH

در `CalculateFractalValues`:
```
structureValue = TH × 1   (trigger timeframe)
patternValue   = TH × 4   (pattern  = 4× trigger)
triggerValue   = TH × 1   (همان structureValue برای این timeframe)
```

**رابطه timeframe ها:**
```
current timeframe   → trigger  (×1)
current × 4       → pattern   (×4)
current × 16      → structure (×16)
```

### ۱۲.۵ Object Prefix Format — دقیق

```
objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_"
مثال: "THLevels_H1_"
```

این در `RedrawAllObjects` ساخته می‌شود و به همه توابع رسم پاس داده می‌شود.
از این prefix در cleanup استفاده می‌شود — هر تغییر باعث می‌شود prefix قدیمی `ClearAllLevels` شود.

### ۱۲.۶ Topology Signature — Cache Invalidation هوشمند

قبل از clear کردن سطوح، یک signature بررسی می‌شود:
```
levelSig = objectPrefix | stepMode | maxLevels | startPointType | lsFirst | harmonicEnabled | harmonicRatio | mStepBasis
```
اگر signature تغییر نکرد → `ClearAllLevels` فراخوانی **نمی‌شود** (performance optimization).
این رفتار در MT4 هم باید دقیقاً حفظ شود.

### ۱۲.۷ GetMidpointPrice — نقطه مرکزی

```mql
double GetMidpointPrice(ENUM_TH_START_POINT_TYPE startType) {
    switch(startType) {
        case TH_START_POINT_MIDPOINT:
            return (g_highestHigh + g_lowestLow) / 2.0;
        case TH_START_POINT_HISTORICAL_HIGH:
            return g_highestHigh;
        case TH_START_POINT_HISTORICAL_LOW:
            return g_lowestLow;
        case TH_START_POINT_CUSTOM_PRICE:
            return g_customTHStartPrice;
    }
}
```

اگر midpointPrice <= 0 یا EMPTY_VALUE → return false از `CalculateCommonStepData`.

### ۱۲.۸ UpdateHistoricalValues — CopyHigh/CopyLow در MT4

در MT5 از `CopyHigh/CopyLow` استفاده می‌شود. در MT4 بدیل:
```mql4
// MT4:
for(int i = 0; i < totalBars; i++) {
    highArray[i] = iHigh(NULL, inpHistoricalTimeframe, i);
    lowArray[i]  = iLow(NULL, inpHistoricalTimeframe, i);
}
g_highestHigh = highArray[ArrayMaximum(highArray, totalBars)];
g_lowestLow   = lowArray[ArrayMinimum(lowArray, totalBars)];
```
**اگر `inpHistoricalPeriods == 0` → از همه bars موجود استفاده شود.**
Cache TTL: هر ۱ ساعت refresh (`SECONDS_PER_HOUR`).

### ۱۲.۹ GetPriceForPreviousDay — دقیقاً این index ها

```
cache دوباری (هر روز یک بار update):
cachedPrices[0] = iClose(NULL, PERIOD_D1, 1)   → PRICE_CLOSE (default)
cachedPrices[1] = iOpen(NULL, PERIOD_D1, 1)
cachedPrices[2] = iHigh(NULL, PERIOD_D1, 1)
cachedPrices[3] = iLow(NULL, PERIOD_D1, 1)
cachedPrices[4] = (High + Low) / 2             → PRICE_MEDIAN
cachedPrices[5] = (High + Low + Close) / 3     → PRICE_TYPICAL
```

### ۱۲.۱۰ Tick Throttle — دقیقاً 50ms

در `OnCalculateHandler`:
```
tickThrottled = (nowMs - s_lastTickMs < 50)
```
اگر throttled باشد **و** هیچ شرط دیگری نباشد → `return rates_total` بدون redraw.
این یعنی روی هر tick تا 50ms نمی‌گذارد redraw کند.

### ۱۲.۱۱ Base Price Boundary — دقیقاً دقیقه ۰ و ۳۰

```
currentServerMinute = TimeMinute(serverTime)
basePriceBoundary = (currentServerMinute == 0 || currentServerMinute == 30)
```
در این لحظه‌ها `UpdateBasePrice()` حتماً فراخوانی می‌شود.
`s_nextBasePriceCheckServer` برای جلوگیری از اجرای چندباره در همان دقیقه تنظیم می‌شود.

### ۱۲.۱۲ Redraw Coalescing — 20ms burst guard

اگر دو `RedrawAllObjects(force=true)` ظرف ۲۰ms فراخوانی شوند → دومی رد می‌شود:
```
if(force_redraw && nowMs - s_lastForcedRedrawMs < 20) return;
```
و idle fast-path:
```
if(!hasPendingWork && nowMs - s_lastRedrawAttemptMs < 35) return;
```
این‌ها باید در MT4 هم حفظ شوند.

### ۱۲.۱۳ OnDeinit — رفتار به ازای reason

| reason | رفتار |
|--------|--------|
| `REASON_REMOVE` | همه GlobalVariables پاک + همه objects حذف (deep cleanup) |
| `REASON_PARAMETERS` | factor/lines/atr/th label gvars حذف + `Biotak_TH3_NeedsUpdate` set |
| `REASON_CHARTCHANGE` | `Biotak_LastTFSwitch` timestamp set |
| سایر | تنها objects حذف (shallow) |

**REASON_PARAMETERS:** `GlobalVariableTemp` روی `TH3_NeedsUpdate` فراخوانی می‌شود — این gvar بعد از terminal restart پاک می‌شود.

در MT4 `GlobalVariableTemp` موجود است.

### ۱۲.۱۴ ATR Warmup Gate — 90 ثانیه

```
اگر آخرین warmup کمتر از 90 ثانیه پیش بود → warmup skip شود
```
برای جلوگیری از warmup مکرر روی rapid TF switch.

### ۱۲.۱۵ Hotkey: G برای Lock (نه L)

از PropertiesAndInputs:
```
inpLockKey = "G"    ← timeframe lock
inpHideKey = "F"    ← hide/show
inpLinesToggleKey = "L"  ← toggle lines
inpStepModeKey = "E"     ← cycle step mode
inpTH3ToolKey = "V"      ← TH3 tool start
inpCustomPriceKey = "C"  ← custom price mode
inpTriggerLevelsKey = "T"
inpATRLabelsKey = "A"
inpTHLabelsKey = "S"
inpResetKey = "Q"
```

**قبلاً در پرامپت نوشته بودم L برای Lock — اشتباه بود. L = toggle Lines، G = Lock.**

همه کلیدها user-configurable هستند (نه hardcode).

### ۱۲.۱۶ IsHotkeyPressed — dual match

```mql
bool IsHotkeyPressed(long lparam, string sparam, string hotkey) {
    StringToUpper(hotkey);
    int code = StringGetCharacter(hotkey, 0);
    if((int)lparam == code) return true;
    // dual: برخی keyboard layout ها lparam متفاوت می‌دهند
    if(StringLen(sparam) > 0) {
        StringToUpper(sparam);
        if(StringGetCharacter(sparam, 0) == code) return true;
    }
    return false;
}
```

### ۱۲.۱۷ HideAllTHObjects — ABCD patterns حذف نمی‌شوند

```
// NOTE: ABCD pattern objects are NOT hidden by F key
// آن‌ها مستقل از TH levels هستند
```

فقط objects با `inpObjectPrefix` hide می‌شوند.
custom price line هم hide می‌شود (`g_customPriceLineCreated`).
label های overlay هم hide می‌شوند.

در MT4 بدیل `OBJPROP_TIMEFRAMES`:
هر object را حذف و state را ذخیره کن. وقتی show شد دوباره بساز.

### ۱۲.۱۸ MQL5Compat — توابع که باید در MT4 native باشند

این‌ها در MQL5Compat.mqh تعریف شده‌اند که در MT4 باید یا native استفاده شوند یا stub باشند:

| تابع MT5Compat | MT4 جایگزین |
|----------------|-------------|
| `TimeHour(dt)` | `TimeHour(dt)` — native MT4 |
| `TimeMinute(dt)` | `TimeMinute(dt)` — native MT4 |
| `TimeDay(dt)` | `TimeDay(dt)` — native MT4 |
| `TimeMonth(dt)` | `TimeMonth(dt)` — native MT4 |
| `TimeYear(dt)` | `TimeYear(dt)` — native MT4 |
| `TimeDayOfWeek(dt)` | `TimeDayOfWeek(dt)` — native MT4 |
| `PeriodMinutes(tf)` | باید پیاده شود (در MT4 نیست) |
| `WindowFirstVisibleBar()` | native MT4 |
| `WindowBarsPerChart()` | native MT4 |
| `ObjectSetText(...)` | native MT4 |
| `MarketInfo(...)` | native MT4 |
| `CacheTickPrices()` | `g_cachedBid = Bid; g_cachedAsk = Ask;` |

**`TimeStructToTime` / `TimeToStruct`:** در MT4 این‌ها موجود نیستند.
بدیل:
```mql4
// MT4 بدیل TimeToStruct:
void TimeToStructMT4(datetime dt, MqlDateTime &st) {
    st.year = TimeYear(dt);
    st.mon  = TimeMonth(dt);
    st.day  = TimeDay(dt);
    st.hour = TimeHour(dt);
    st.min  = TimeMinute(dt);
    st.sec  = TimeSeconds(dt);
    st.day_of_week = TimeDayOfWeek(dt);
}
// MT4 بدیل StructToTime:
datetime StructToTimeMT4(MqlDateTime &st) {
    return StrToTime(IntegerToString(st.year) + "." +
                     StringFormat("%02d", st.mon) + "." +
                     StringFormat("%02d", st.day) + " " +
                     StringFormat("%02d", st.hour) + ":" +
                     StringFormat("%02d", st.min) + ":" +
                     StringFormat("%02d", st.sec));
}
```

### ۱۲.۱۹ CalculationCache — GetCachedPoint و GetCachedPeriod

در `CalculationCache.mqh`:
```
GetCachedPoint()     ← از PerformanceOptimizations.mqh
GetCachedPeriod()    ← از PerformanceOptimizations.mqh
GetCachedDigits()    ← از PerformanceOptimizations.mqh
GetCachedSymbol()    ← از PerformanceOptimizations.mqh
GetCachedChartIdStr()← از PerformanceOptimizations.mqh
GetCachedPipSize()   ← (Digits==3||Digits==5) ? Point×10 : Point
```

در MT4 همه این‌ها مستقیماً کار می‌کنند — فقط باید `InitializeGlobalCache()` از OnInit فراخوانی شود.

### ۱۲.۲۰ CacheGetFrameTime و CacheRefreshFrameTime

این‌ها زمان سرور را cache می‌کنند تا در یک frame فقط یکبار `TimeCurrent()` فراخوانی شود:
```
CacheRefreshFrameTime()  ← یکبار در ابتدای هر redraw
CacheGetFrameTime()      ← همه جا به جای TimeCurrent()
```
در MT4 `TimeCurrent()` موجود است — این pattern حفظ شود.

### ۱۲.۱۱ TimeGMT() vs TimeCurrent()

در کد هر دو استفاده می‌شوند:
- `TimeGMT()` → برای cleanup interval و redraw throttle
- `TimeCurrent()` → برای historical update و base price
- `CacheGetFrameTime()` → برای label و status display

در MT4 هر دو `TimeGMT()` و `TimeCurrent()` موجود هستند.

### ۱۲.۲۲ Structure Base Multiplier — Dynamic

```
inpStructureBase: BASE_MULTIPLIER_2 (default) تا BASE_MULTIPLIER_9
```

مثال با base=2 (default):
```
L1 = stepIndex % 2 == 0  → L1 color
L2 = stepIndex % 4 == 0  → L2 color
L3 = stepIndex % 8 == 0  → L3 color
L4 = stepIndex % 16 == 0 → L4 color
L5 = stepIndex % 32 == 0 → L5 color
```

### ۱۲.۲۳ Pip Distance Calculation

```mql
double CalculatePipsDistance(double price1, double price2) {
    double pipSize = GetCachedPipSize();  // (Digits==3||5) ? Point*10 : Point
    if(pipSize <= 0) return 0;
    return MathAbs(price1 - price2) / pipSize;
}
```

این در label ها نمایش داده می‌شود.

### ۱۲.۲۴ ENUM_LOG_LEVEL و سیستم Logger

```
enum ENUM_LOG_LEVEL {
    LOG_LEVEL_TRACE = 0,
    LOG_LEVEL_DEBUG = 1,
    LOG_LEVEL_INFO  = 2,
    LOG_LEVEL_WARN  = 3    ← default
    LOG_LEVEL_ERROR = 4,
    LOG_LEVEL_OFF   = 5
};
```

Macros:
```
_LOG_GATE_E  → Print فقط اگر level >= ERROR
_LOG_GATE_W  → Print فقط اگر level >= WARNING
_LOG_GATE_I  → Print فقط اگر level >= INFO
_LOG_GATE_D  → Print فقط اگر level >= DEBUG
LOG_CAT_KEYS, LOG_CAT_PERF, LOG_CAT_ATR  ← category strings
```

### ۱۲.۲۵ Trigger Transparency Color Blending

در `GetTriggerRenderColor()` یک فرمول custom برای blend وجود دارد:
```
tVis = 100 - ((100 - t) × (100 - t)) / 100   ← Quadratic fade
outR = (foreR × (100-tVis) + bgR × tVis) / 100
outG = (foreG × (100-tVis) + bgG × tVis) / 100
outB = (foreB × (100-tVis) + bgB × tVis) / 100
```

background color از `ChartGetInteger(0, CHART_COLOR_BACKGROUND)` گرفته می‌شود.
این رفتار ریز مهم است چون در MT4 هم `CHART_COLOR_BACKGROUND` موجود است.

### ۱۲.۲۶ Mode Label Duration Enum

```
enum ENUM_MODE_LABEL_DURATION {
    MODE_LABEL_1_SEC = 1000,
    MODE_LABEL_2_SEC = 2000,
    MODE_LABEL_3_SEC = 3000,
    MODE_LABEL_5_SEC = 5000,
    MODE_LABEL_PERMANENT = 0
};
```

در `OnTimer` (هر ۱ ثانیه) tick count مقایسه می‌شود با زمان ایجاد label.

### ۱۲.۲۷ ObjectCache Hash Table

در `ObjectCache.mqh` یک hash table با ۲۰۴۸ bucket وجود دارد:
```
CACHE_HASH_BUCKETS = 2048
```

در MT4 این باید دقیقاً یکسان باشد چون `ClearAllLevels` مستقیماً bucket ها را invalidate می‌کند.

### ۱۲.۲۸ Property Change Detector

`DetectPropertyChanges()` در `PropertyChangeDetector.mqh`:
- price/color/style/width را با cached value مقایسه می‌کند
- فقط property های تغییرکرده را `ObjectSetInteger/ObjectSetDouble` می‌کند
- اگر فقط ۱ property تغییر کرد → single set call
- اگر > 1 → batch set

این **باید** در MT4 هم پیاده شود — بدون آن هر tick همه properties set می‌شوند.

### ۱۲.۲۹ ApplyVisibilityState در ObjectFunctions

```mql
// بعد از ایجاد/update هر object:
ApplyVisibilityState(name, true);          // برای object جدید
ApplyVisibilityStateIfUnchangedSkip(name, true);  // برای object موجود
```

این توابع از `VisibilityManager.mqh` هستند و در MT4 باید:
- اگر indicator hidden → object حذف یا invisible
- اگر visible → object نمایش داده شود

### ۱۲.۳۰ Legacy Suffixes برای Backward Compatibility

```
"MLabel_"
"MEqLabel_"
"SharedPattern_"
"TH_Level_"
"S_"
"TriggerTH_Up_"
"TriggerTH_Down_"
"StructureLevel1_Up_" تا "StructureLevel5_Down_"
"Mid"
```

این‌ها در `ClearAllLevels` حذف می‌شوند — حتی اگر از pipeline جدید استفاده شود.
باید در MT4 هم preserve شوند وگرنه objects قدیمی روی چارت می‌مانند.

### ۱۲.۳۱ MinutesToFractalString — نگاشت دقیق

```
<= 1   min → "M1"
<= 5   min → "M4"
<= 15  min → "M16"
<= 30  min → "M16"   ← M30 هم به M16 map می‌شود
<= 60  min → "H1+M4"
<= 240 min → "H4+M16"
<= 1440 min→ "D2+H20+M16"  ← D1 به این map می‌شود (نه H17+M4!)
<= 10080 min → "D11+H9+M4"
else    → "D45+H12+M16"
```

**دقت مهم:** در ConstantsAndEnums نوشتم `H17+M4` برای D1 — این **اشتباه** بود.
`MinutesToFractalString` که در TimeframeFunctions.mqh است:
- D1 = 1440 دقیقه → `"D2+H20+M16"` با percentage = 1.3332%

کدام درست است؟ باید بررسی کنی:
- `GetFractalTimeframeForCurrent()` چه مقداری برمی‌گرداند؟
- این تابع به `FractalTimeframes.mqh` مراجعه می‌کند

### ۱۲.۳۲ FractalTimeframes.mqh — GetFractalTimeframeForCurrent

این تابع باید بررسی شود. احتمالاً از `MinutesToFractalString` استفاده می‌کند:
```mql
string GetFractalTimeframeForCurrent() {
    int minutes = PeriodMinutes(GetEffectiveTimeframe());
    return MinutesToFractalString(minutes);
}
```

اگر D1 (1440 min) → `MinutesToFractalString` → `"D2+H20+M16"` → percentage = **1.3332%**

### ۱۲.۳۳ GetStructureTimeframeForCurrent (Structure = 16× trigger)

```mql
string GetStructureTimeframeForCurrent() {
    int currentMinutes = PeriodMinutes();
    int structureMinutes = currentMinutes * 16;
    return MinutesToFractalString(structureMinutes);
}
```

مثال H1 (60 min):
- structure = 60 × 16 = 960 min → <= 1440 → "D2+H20+M16" → 1.3332%

### ۱۲.۳۴ CalculateMDistance — M Mode Specific

در M_STEP با `MSTEP_BASIS_M_BASED`:
```
mDistance = CalculateMDistance(controlValue)
```
این تابع باید از `THCalculations.mqh` یا `LevelPipeline.mqh` استخراج شود.
احتمالاً: `mDistance = controlValue` (بدون تغییر) یا مضربی از آن.

### ۱۲.۳۵ Factor Boundary Lines

در FACTOR_STEP یک تابع اضافی فراخوانی می‌شود:
```
DrawFactorBoundaryLines(objectPrefix, g_highestHigh, g_lowestLow, factorValue, factorStepSize)
```

این خطوط boundary برای ناحیه High-Low رسم می‌کند — باید در MT4 هم پیاده شود.

### ۱۲.۳۶ CheckAndClearExpiredLabels — OnTimer

در `OnTimer` علاوه بر `RunIncrementalObjectCleanup`:
```
CheckAndClearExpiredLabels()
```

این تابع label های expired (`g_stepModeLabelCreateTime` و ...) را چک و حذف می‌کند.
زمان expire از `inpModeLabelDuration` (ENUM_MODE_LABEL_DURATION) گرفته می‌شود.

### ۱۲.۳۷ TH3 Frequency Migration (legacy sync)

در OnInit یک migration logic وجود دارد:
```
// اگر saved frequency با index محاسبه‌شده تفاوت > 0.01% داشت:
g_th3FreqIndex = FindNearestFreqIndex(savedFreq)
g_th3FreqOverride = GetFrequencyByIndex(g_th3FreqIndex)
// → persist کن
```

این برای سازگاری با index های قدیمی (قبل از binary subdivision) است.

### ۱۲.۳۸ CleanupAllGlobalVariables — دقیقاً چه چیزی پاک می‌شود

در REASON_REMOVE فراخوانی می‌شود. باید همه این names پاک شوند:
```
"Biotak_isHidden_{chartId}"
"Biotak_TriggerLevels_{chartId}"
"Biotak_LinesVisible_{chartId}"
"Biotak_ATRLabels_{chartId}"
"Biotak_THLabels_{chartId}"
"Biotak_LockTF_{chartId}"
"Biotak_LockTFPeriod_{chartId}"
"Biotak_StepMode_{chartId}"
"Biotak_Factor_{chartId}"
"Biotak_TH3Freq_{chartId}"
"Biotak_TH3FreqIdx_{chartId}"
"Biotak_LastTFSwitch_{chartId}"
"Biotak_BaseInit_{chartId}"
"Biotak_ATRWarmup_{chartId}"
"Biotak_TH3_NeedsUpdate_{chartId}"
"Biotak_CustomPrice_{symbol}"
"Biotak_CustomPriceOverride_{symbol}"
```

---

## ۱۳. خلاصه اصلاحات نسخه اول پرامپت

| مورد | اشتباه قبلی | تصحیح |
|------|-------------|--------|
| Hotkey Lock | `L` | `G` (L = Lines Toggle) |
| D1 fractal string | `H17+M4` (0.6666%) | `D2+H20+M16` (1.3332%) بر اساس `MinutesToFractalString` |
| ATR handle | نیاز به cache | در MT4 هیچ handle نیست، مستقیم |
| Hotkey list | ناقص | همه ۱۰ hotkey با default مشخص شد |

---

*این پرامپت بر اساس بررسی دقیق کامل تمام ۴۳ فایل MQH پروژه MT5 نوشته شده است (نسخه 3.10)*
*بررسی شامل: EventHandlers (2195 خط)، MQL5Compat، ATRCalculations، LevelPipeline، TH3Tool، FrequencyOptimizer، WaveAnalysis، GlobalVariables، PropertiesAndInputs، ConstantsAndEnums، TimeframeFunctions و سایر فایل‌ها*
*تاریخ: ۲۰۲۶/۰۲/۱۸*
