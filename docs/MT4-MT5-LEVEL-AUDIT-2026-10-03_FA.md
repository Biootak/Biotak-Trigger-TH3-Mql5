# چرا سطوح در MT5 با MT4 فرق می‌کند — چک صفر تا صد (۲۰۲۶-۱۰-۰۳)

**سؤال کاربر:** «توی رسم سطوح مثل متاتریدر ۴ نیست؛ عددها و سطوحی که با تنظیمات
یکسان رسم می‌شود فرق می‌کند.»

**پاسخ کوتاه:** تنظیمات (inputs) فقط *یک* ورودیِ نردبان است. عدد هر سطح از این
زنجیره می‌آید و **سه ورودی دیگرش بیرون از تنظیمات و بیرون از کد** زندگی می‌کنند:

```
سطح_i  =  قیمتِ مرجع (basePrice)  +  i × step
                       │                    │
        ┌──────────────┘                    └──────────────┐
        │                                                  │
  BasePriceManager:                                  step از کدام پایه؟
  · پروندهٔ روز (GMT) در Files/.biotak/history        · TH%  → CalculateTH(base, digits, pct)   [ریاضی محض]
  · یا اگر پرونده خالی باشد → Bid زندهٔ همان لحظه      · ATR  → CalculateATRBasedStep()
  · ValidateRestoredBasePrice در برابر Bid            · Combo/Factor → ریاضی محض
                                                     · GetAdaptedStepSize → ریاضی محض
```

یعنی حتی با **تنظیمات ۱۰۰٪ یکسان**، اگر دو ترمینال «قیمت مرجع» یا «ATR» متفاوت
داشته باشند، همهٔ سطوح جابجا می‌شوند — و این تفاوت در مقایسهٔ متنی کد دیده
نمی‌شود، چون کد عیناً یکی است و *داده* فرق دارد.

---

## ۱. آنچه واقعاً باگ بود و اصلاح شد (فقط سمت MT5)

`iATR` در MT4 روی **کل هیستوری** هموار می‌کند (Wilder). شیم MT5 وقتی هندل ATR
هنوز آماده نیست (دوران warmup، خصوصاً D1/W1/MN1 که MT5 آنها را از M1 می‌سازد)
یک مسیر جایگزین داشت که فقط `3×period` کندل عقب seed می‌زد. باقی‌ماندهٔ آن seed
بعد از ~`2×period` کندل هنوز ≈ `e^-2 ≈ ۱۳٪` است — یعنی یک **عدد متفاوت** با
MT4، و چون همین ATR وارد `step` می‌شود، **همهٔ سطوح جابجا** می‌شد.

اصلاح در `MT5Compat/MQL5Compat.mqh`:

* پنجرهٔ fallback از `max(3×period, 60)` به `max(3×period, 3000)` رفت، و
* seed روی **قدیمی‌ترین کندلِ کپی‌شده** نشست (قرارداد خود MT4).

باقی‌ماندهٔ seed با ۳۰۰۰ کندل برای بزرگ‌ترین period این پروژه (۲۶۴ روی MN1)
کمتر از `3e-5` است — عملاً صفر. حالا مقدار fallback و مقدار هندل و مقدار MT4 یکی‌اند.

> این تنها واگراییِ **کد-سطح** در زنجیرهٔ نردبان بود. بقیهٔ زنجیره
> (CalculateTH، GetAdaptedStepSize، CalculateLevels، BuildZonesAndLines،
> ClassifyLevels و رندر) متن‌به‌متن MT4 است و در گزارش ماژول‌به‌ماژول سبز است.

## ۲. آنچه باگ نیست، ولی سطوح را جابجا می‌کند (داده/وضعیت)

| # | ورودی | چرا بین دو ترمینال فرق می‌کند | چطور یکسان می‌شود |
|---|---|---|---|
| ۱ | **قیمت مرجع** (basePrice) | پروندهٔ روزِ هر ترمینال جداست: `Files/.biotak/history/base_price_history_SYMBOL_YYYY_DDD.txt`؛ هر ۳۰ دقیقه یک ردیف. اگر پرونده خالی باشد، base = **Bid زندهٔ لحظهٔ attach** | پروندهٔ امروز را در هر دو ترمینال پاک کنید و هر دو را نزدیک هم attach کنید |
| ۲ | **بروکر/نماد** | MT4 روی AMarkets و MT5 روی Vittaverse است؛ های/لو/close روز قبل و ATR ذاتاً متفاوت‌اند | برای آزمون مطلق، هر دو ترمینال باید یک بروکر/نماد باشند؛ در غیر این صورت فقط مقایسهٔ **نسبت به base** معنا دارد |
| ۳ | **عمق هیستوری** | MT5 هیستوری را async بار می‌کند؛ تعداد کندل‌های M1/D1 دو طرف فرق دارد و مسیر بازسازی مرجع و legهای ATR به آن حساس است | در هر دو طرف یک‌بار چارت را بکشید تا هیستوری کامل شود، بعد attach |
| ۴ | **لنگر سفارشی TH** | اگر قبلاً «قیمت سفارشی» ست شده باشد، `g_thStartPointType = CUSTOM` می‌ماند و **تنظیمات را نادیده می‌گیرد** | در پنل، حالت شروع TH را روی «Previous Close» برگردانید (یا چارت تازه) |
| ۵ | **EMA ضریب تطبیقی** | `g_smoothedScalingFactor` در **اولین محاسبه** seed می‌شود؛ پس زمان attach در مقدار اولیه‌اش اثر دارد | هر دو را با فاصلهٔ زمانی کم attach کنید؛ بعد از چند کندل به هم می‌رسند |
| ۶ | **ساعت سرور / GMT** | نام پروندهٔ روز با **GMT** ساخته می‌شود؛ دو بروکر آفست سرور متفاوت دارند | فقط با GMT یکسان (یا همان بروکر) قابل مقایسه است |
| ۷ | **شبیه‌سازی سری‌های MQL4** | MT5 آرایه‌های `Time[]/Open[]/High[]/Low[]/Close[]/Bars` را خودش می‌سازد؛ تمام‌سازی فقط وقتی «تعداد کندل عوض شود» و با فاصلهٔ ≥۵۰۰ms انجام می‌شود. تا وقتی هیستوری async می‌رسد، `Bars` شبیه‌سازی‌شده **از چارت عقب‌تر** است و هر خوانندهٔ `Bars/Time[]/Close[]` سری کوتاه‌تری می‌بیند (MT4 اصلاً چنین تاخیری ندارد) | صبر کنید تا دانلود تمام شود (هر دو طرف یک‌بار چارت را بکشید)، سپس اندازه‌گیری کنید؛ `barsEmul` در CSV وضعیت این را نشان می‌دهد |

## ۳. چک‌لیست صفر تا صد (هر عددی که رسم می‌شود)

| مرحله | تابع | منبع ورودی | MT4 vs MT5 |
|---|---|---|---|
| قیمت مرجع | `GetBasePriceForTH` → `g_basePriceCached` | پروندهٔ روز / Bid / بازسازی از M30+M1 | کد یکسان؛ **داده/وضعیت** متفاوت (ردیف‌های ۱–۳ جدول بالا) |
| درصد | `GetTimeframeTH` | input + تنظیمات ذخیره‌شده | یکسان |
| گام TH | `CalculateTH(base, digits, pct)` | ریاضی محض | یکسان (خط‌به‌خط) |
| گام ATR | `CalculateATRBasedStep` → `CalculateWeightedATR` → ۶ leg | `iATR` | **اصلاح شد** (بند ۱) |
| گام Combo/Factor | `GetComboStepSize` و مشابه | inputs | یکسان |
| تطبیق گام | `GetAdaptedStepSize` (+EMA) | ATR/TH | کد یکسان؛ زمان attach (ردیف ۵) |
| تولید سطوح | `CalculateLevels` | base + step + inputs | یکسان |
| دسته‌بندی/تریگر | `ClassifyLevels`, `DeriveTriggers`, `CalculateStructure/Pattern/TriggerValue` | ریاضی محض | یکسان |
| ساخت و رسم | `BuildZonesAndLines`, `ConstructZone`, `RenderAll`, `FormatStepLabel` | قیمت‌های بالا | یکسان |

## ۴. روش تأیید عملی (بدون حدس)

۱. **وضعیت را یکسان کنید** (حداقل: پروندهٔ امروز `base_price_history_*` را در هر
   دو ترمینال پاک کنید؛ ترجیحاً همان بروکر و همان نماد).
۲. در هر دو ترمینال `Biotak Sync Compare` را روی چارت تازه بیندازید.
۳. اجرا کنید:

```bash
python tools/parity/parity-diff.py --mt4 "<MQL4/Files>" --mt5 "<MQL5/Files>" --bar latest
```

خروجی حالا **سه** پرونده را می‌خواند:

| پرونده | چه می‌گوید |
|---|---|
| `biotak_sync_values.csv` | عددهای اصلی (base, TH%, step, ATR, ساختار/الگو/تریگر) |
| `biotak_sync_objects.csv` | فهرست و مشخصات و هندسهٔ همهٔ اشیای رسم‌شده |
| `biotak_sync_state.csv` | **علت**: منشأ قیمت مرجع (پرونده/‌Bid)، عمق هیستوری، عقب‌بودن شبیه‌سازی سری‌ها (`barsEmul` vs `barsChart`)، لنگر سفارشی، شش leg ATR، ATR وزن‌دار |

`parity-diff.py` سه حکم می‌دهد (INVENTORY / PROPERTIES / LADDER) و اگر LADDER
ردیف‌به‌ردیف جواب ندهد، بخش `STATE / CAUSE` می‌گوید کدام ورودی مسئول است:

```
CAUSES (5):
   * mt5: the CHART is not using the input start type - live=1 input=0
     (a leftover custom TH anchor = a different ladder regardless of settings ...)
   * barsM1: mt4=90000 mt5=61000 (history depth feeds the ATR legs ...)
   * the reference-price file: mt4 has 12 entries, mt5 has 0 - the empty side
     anchored its base price on the LIVE BID (BASE PRICE INIT) ...
```

اگر هیچ‌کدام از این علت‌ها نبود و باز LADDER رد شد، آن‌وقت **باگ برابری** است و
می‌شود دقیقاً با نام شیء دنبالش رفت (ابزار هر استثنا را نام‌به‌نام چاپ می‌کند).

## ۵. وضعیت بیلد بعد از این اصلاح

```
Biotak Trigger TH3.mq5      : 0 errors, 0 warnings
Biotak Trigger TH3 Lite.mq5 : 0 errors, 0 warnings
Biotak Sync Compare.mq5     : 0 errors, 0 warnings
Biotak Sync Compare.mq4     : 0 errors, 1 warnings   (warning 46 در PathTool، از قبل)
module-report               : 0 RED, 0 YELLOW, 69 GREEN
```
