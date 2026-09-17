# فاز ۳ تا ۱۰ — باگ واحد زمان‌فریم (R-TF-UNIT) و بازبینی ابزارهای حلقه

**تاریخ:** ۱۶ سپتامبر ۲۰۲۶
**مبنا:** `docs/MT5-PARITY-AUDIT-PLAN_FA.md` (بخش ۵ — ماتریس بازبینی ابزار به ابزار)
**وضعیت:** فاز ۳ کامل و تأییدشده. فازهای ۴–۷ بخشی (به‌دلیل نیاز به ترمینال باز).

---

## ۱. خلاصهٔ مدیریتی

بازبینی ابزار به ابزار (فاز ۳) به یک **کلاس باگ** رسید، نه به چند باگ پراکنده.
هر چهار نقصِ تأییدشدهٔ ابزارهای حلقه یک ریشهٔ مشترک داشتند:

> **در MT4 مقدار زمان‌فریم «دقیقه» است و ثابت‌های `PERIOD_*` همان اعداد هستند
> (`PERIOD_H1 == 60`). در MT5 نه: `Period()` یک `ENUM_TIMEFRAMES` برمی‌گرداند
> (`H1 == 16385`) و مقادیر enum هیچ رابطه‌ای با دقیقه ندارند.**
>
> سورس مشترک در مدل MT4 نوشته شده است. پس هر خطی که مقدار زمان‌فریم را
> «دقیقه» فرض می‌کند، روی MT4 درست و روی MT5 **بی‌صدا** غلط است — چون ۱۶۳۸۵
> هم یک عدد صحیح کاملاً سالم است و هیچ خطایی رخ نمی‌دهد.

این دقیقاً همان چیزی است که کاربر «نصفه و نیمه» نامید: شیم MT5 خودش در
`MQL5Compat.mqh:128-130` این تفاوت را مستند کرده و `PeriodMinutes()` را ساخته —
و بعد فقط **دو بار** از آن استفاده کرده. بقیهٔ ۱۴۴ نقطهٔ کاندید هرگز تبدیل نشده بودند.

**نتیجه:** یک روش واحد (`CompatTF()`) به‌کار رفت که همهٔ این نقاط را یک‌جا
درست می‌کند، به‌علاوهٔ یک گیت جدید (`tf-unit-audit`) که نمی‌گذارد دوباره
خراب شود. روی MT4 **هیچ‌چیز تغییر نکرده** — اثباتش در بخش ۵.

---

## ۲. نقص‌های پیش‌بینی‌شده و یافته‌شده (فهرست گلوله‌ای)

### ۲.۱ کندل‌های تایم‌فریم بالاتر (HTF Candles)

| # | سناریو | ریشه | اثر روی MT5 |
|---|---|---|---|
| ۱ | **حالت FIXED هیچ‌وقت رسم نمی‌کند** | `HTFCandles.mqh:908/997` — `tf <= Period()` | روی MT4 `240 <= 60` غلط است (رسم می‌کند)؛ روی MT5 `240 <= 16388` **درست** است → هر پاس باکس‌ها را پاک می‌کند و رسم هرگز رخ نمی‌دهد |
| ۲ | **نردبان snap اشتباه** | `HTFCandles.mqh:235-236` — `static int ladder[9] = {PERIOD_M1, …, PERIOD_MN1}` | این آرایه «دقیقه» فرض شده (`MathLog(mins/ladder[i])`). روی MT5 رده‌ها `1,5,15,30,16385,16388,16408,32769,49153` می‌شوند: چارت H1 به‌جای H4 به **MN1** snap می‌کرد و بعد پشت گیت `rung > Period()` پنهان می‌شد |
| ۳ | **`g_HTFPeriod` و `InpHTFTimeframe` پیش‌فرض غلط** | `HTFCandles.mqh:61/79/1092` — `= PERIOD_H4` | متغیر از نوع `int` و در واحد دقیقه؛ روی MT5 مقدار پیش‌فرض ۱۶۳۸۸ می‌شد، نه ۲۴۰ |
| ۴ | **`HTFBarCloseTime` برای MN1** | `HTFCandles.mqh:291` — `if(tf == PERIOD_MN1)` | روی MT5 هرگز true نمی‌شود → زمان بستهٔ کندل MN1 با `ot + tf*60` حساب می‌شد (غلط) |
| ۵ | **`iBarShift` با enum نامعتبر** | `HTFCandles.mqh:360` — `(ENUM_TIMEFRAMES)p` | `p` دقیقه است. روی MT5 `(ENUM_TIMEFRAMES)60` یک enum نامعتبر است → `iBarShift` مقدار ‎-1 برمی‌گرداند → محور افقی کندل‌ها غلط |

### ۲.۲ ابزار Base / Knot

| # | سناریو | ریشه | اثر روی MT5 |
|---|---|---|---|
| ۶ | **نام تایم‌فریم در tooltip** | `BaseKnotTool.mqh:4976` — `int tfMin = Period();` | کادر به‌جای `"H1"` می‌نوشت **`"16385m"`** |
| ۷ | **ردهٔ اشتباه در نردبان** | `BaseKnotTool.mqh:2562/3002/1548` | MN1 جایی که MT4 ردهٔ H4 را می‌پذیرد |
| ۸ | **Entry/SL/TP از تایم‌فریم غلط** | `BaseKnotTool.mqh:716-724/2723/2832` | اندازه‌گذاری از MN1 در حالی که MT4 از H1 استفاده می‌کند |
| ۹ | **`iBarShift` با enum نامعتبر** | `BaseKnotTool.mqh:2500/2501/2724/2791` | `(ENUM_TIMEFRAMES)tfMin` و `(ENUM_TIMEFRAMES)tfRead` → ‎-1 → شمارش کندل‌های پایه صفر/غلط |

### ۲.۳ ناحیهٔ Trigger Zones

| # | سناریو | ریشه | اثر روی MT5 |
|---|---|---|---|
| ۱۰ | **نشان حلقه ON ولی چارت بی‌تغییر** | `LevelPipeline.mqh:581/720/833` | اشیای `_Zone_` به `config.zonesEnabled` گره خورده‌اند؛ در حالی که «Zones & Levels» خاموش است، حلقهٔ Trigger Zones بی‌اثر است |

### ۲.۴ لایهٔ کش و برچسب‌ها (فراتر از گزارش ابزارها)

| # | سناریو | ریشه | اثر روی MT5 |
|---|---|---|---|
| ۱۱ | **`PeriodSeconds()` صفر برمی‌گرداند** | `PerformanceOptimizations.mqh:528`، `ObjectFunctions.mqh:86`، `THCalculations.mqh:126/134` | `PeriodSeconds((ENUM_TIMEFRAMES)60)` روی MT5 معتبر نیست → **۰** → هر محاسبهٔ وابسته به طول کندل صفر |
| ۱۲ | **ATR وزن‌دار از TF نامعتبر** | `ATRCalculations.mqh:410/1129` | `CalculateWeightedATR((ENUM_TIMEFRAMES)Period())` → enum نامعتبر → ATR صفر → **برچسب‌ها ظاهر نمی‌شوند** (شکایت اصلی کاربر) |
| ۱۳ | **نردبان TH%** | `ExtendedDrawingFunctions.mqh:832/865/877/886` | `return (ENUM_TIMEFRAMES)Period();` → تابع یک enum نامعتبر برمی‌گرداند |
| ۱۴ | **قفل تایم‌فریم** | `BiotakPanels.mqh:2556` — `LockOptFromPeriod()` | مقایسهٔ دقیقه با `PERIOD_*` → روی MT5 هیچ‌وقت مطابقت نمی‌کند → سگمنت همیشه `Cur` نشان می‌داد؛ و برچسب قفل `"16385"` می‌نوشت |
| ۱۵ | **مقدار قفل‌شدهٔ ذخیره‌شده روی دیسک** | `EventHandlers.mqh:466` | مقدار در GlobalVariable ذخیره می‌شود؛ نسخهٔ قدیمی MT5 عدد ۱۶۳۸۵ را ذخیره کرده بود → پس از ارتقا هم خراب می‌ماند |
| ۱۶ | **`TradePlanStripPips`** | `TradePlanFormulas.mqh:166` | پارامتر `tfMinutes` است ولی به enum کست می‌شد |
| ۱۷ | **کلید کش طرح معامله** | `TradePlanFormulas.mqh:362` | `IntegerToString(Period())` → کلید کش بین دو پلتفرم متفاوت بود |

---

## ۳. روش واحد (R-TF-UNIT)

### ۳.۱ قاعده

> در سورس مشترک، هر مقدار زمان‌فریم **همیشه دقیقه** است.
> `Period()` و `GetCachedPeriod()` دقیقه برمی‌گردانند.
> ثابت‌های `PERIOD_*` فقط جایی ظاهر می‌شوند که واقعاً `ENUM_TIMEFRAMES` لازم است.
> عبور از دقیقه به enum **یک بار** و در نقطهٔ مصرف، از طریق `CompatTF()` انجام می‌شود.

### ۳.۲ پیاده‌سازی — سه قطعه

**الف) `Biotak/BuildConfig.mqh`** (اولین include هر دو ورودی):

```mql5
#ifdef __MQL5__
int CompatPeriodMinutes() { return PeriodSeconds(PERIOD_CURRENT) / 60; }
ENUM_TIMEFRAMES CompatTF(const int v) { … }   // دقیقه → enum
int CompatMinutes(const int v) { … }          // نرمال‌سازی مقدار با منشأ نامعلوم
#else
int CompatPeriodMinutes() { return Period(); }
ENUM_TIMEFRAMES CompatTF(const int v) { return (ENUM_TIMEFRAMES)v; }
int CompatMinutes(const int v) { return v; }
#endif
```

`CompatTF()` **بخشنده** است: مقداری که از قبل یک enum معتبر باشد دست‌نخورده
عبور می‌کند. دو مقیاس برخورد نمی‌کنند — مقادیر ۱..۳۰ روی هر دو پلتفرم یکسان‌اند
(`PERIOD_M1..PERIOD_M30` واقعاً ۱..۳۰ هستند) و بالاتر از آن نردبان دقیقه
(۶۰…۴۳۲۰۰) و نردبان enum (۱۶۳۸۵…) جدا هستند.

این بخشندگی **تور ایمنی** کل بازسازی است: یک نقطهٔ تبدیل‌نشده هم روی
زمان‌فریم درست می‌نشیند.

**ب) `MT5Compat/MQL5Compat.mqh`** — بازگرداندن معنای MT4:

```mql5
#define Period() CompatPeriodMinutes()      // در انتهای فایل
#define iBars(sym, tf)  iBars(sym, CompatTF(tf))
#define iTime(sym, tf, sh)  iTime(sym, CompatTF(tf), sh)
// … iHigh/iLow/iOpen/iClose به همین شکل
ENUM_TIMEFRAMES CompatRawPeriod() { return Period(); }   // دسترسی به تابع اصلی، پیش از ماکرو
```

این یک خط، **حدود ۶۰ نقطهٔ فراخوانی** را که `Period()` را دقیقه فرض می‌کردند
یک‌جا درست می‌کند — بدون دست‌زدن به سورس مشترک.

**ج) تبدیل نقاط دقیقه‌ای صریح** به مدل دقیقه (نردبان HTF، پیش‌فرض‌ها،
`LockPeriodFromOpt`/`LockOptFromPeriod`).

### ۳.۳ چرا ماکرو و نه ۶۰ ویرایش دستی

هر دو راه روی MT4 **بی‌اثر** هستند (`CompatPeriodMinutes()` روی MT4 همان
`Period()` است). ولی ماکرو:

- نقاطی را که پیدا نکرده‌ایم هم درست می‌کند؛
- اگر فردا کسی یک نقطهٔ جدید بنویسد، خودکار درست است؛
- کامپایلر را مجبور می‌کند نقاط enum-خواه را **فهرست کند** — و کرد:
  دقیقاً دو خطای `error 262: cannot convert enum` در `WaveAnalysis.mqh:178`
  (تنها جایی که `iBarShift` بدون ماکرو استفاده شده بود).

---

## ۴. آنچه تغییر کرد (فایل به فایل)

| فایل | تغییر |
|---|---|
| `Biotak/BuildConfig.mqh` | افزودن `CompatPeriodMinutes()`، `CompatTF()`، `CompatMinutes()` (هر دو پلتفرم) |
| `MT5Compat/MQL5Compat.mqh` | `#define Period()`، مسیردهی ۶ ماکروی `iXxx` از `CompatTF`، `CompatRawPeriod()`، اصلاح `PeriodMinutes()`، `iATRMQL4()` دوواحدی |
| `Biotak/HTFCandles.mqh` | نردبان snap به دقیقه، `g_HTFPeriod`/`InpHTFTimeframe` = ۲۴۰، مقایسهٔ MN1 = ۴۳۲۰۰، `iBarShift` با `CompatTF` |
| `Biotak/BaseKnotTool.mqh` | چهار `iBarShift` با `CompatTF` |
| `Biotak/BiotakPanels.mqh` | `LockPeriodFromOpt`/`LockOptFromPeriod` به دقیقه |
| `Biotak/ATRCalculations.mqh` | دو نقطهٔ عبور به `CompatTF` |
| `Biotak/ExtendedDrawingFunctions.mqh` | چهار نقطهٔ `return` به `CompatTF` |
| `Biotak/PerformanceOptimizations.mqh` | `PeriodSeconds(CompatTF(...))` |
| `Biotak/ObjectFunctions.mqh` | همان |
| `Biotak/THCalculations.mqh` | دو نقطه |
| `Biotak/BiotakMenu.mqh`، `Biotak/EventHandlers.mqh` | `iClose` با `CompatTF`؛ نرمال‌سازی مقدار قفل بازیابی‌شده |
| `Biotak/TradePlanFormulas.mqh` | `CompatTF(tfMinutes)` |
| `Biotak/WaveAnalysis.mqh` | دو `iBarShift` (تنها خطاهای کامپایل) |
| `Biotak/TimeframeFunctions.mqh` | بازنشستگی `GetHigherPatternTimeframePeriod()` (بدون فراخوان، `-OFF`) |

**گیت‌های به‌روزشده:** `base-count-audit` (پذیرش `CompatTF(...)`)،
`write-budget-audit` (نردبان دقیقه‌ای).
**گیت جدید:** `tf-unit-audit` — قاعدهٔ R-TF-UNIT را اجرا می‌کند.

---

## ۵. اثبات «رفتار تغییر نکرده» روی MT4

روی MT4:

- `CompatPeriodMinutes()` ⟶ `Period()` که همان دقیقه است → **همان مقدار**؛
- `CompatTF(v)` ⟶ `(ENUM_TIMEFRAMES)v`، و روی MT4 `PERIOD_H4 == 240` → **همان enum**؛
- `CompatMinutes(v)` ⟶ `v` → **بی‌اثر**؛
- نردبان `{1,5,15,30,60,240,1440,10080,43200}` ⟶ دقیقاً همان `{PERIOD_M1…PERIOD_MN1}` روی MT4؛
- `#define Period()` فقط در شیم MT5 وجود دارد — MT4 هرگز آن را نمی‌بیند.

پس هر جایگزینی روی MT4 **هم‌مقدار** است و رفتار نمی‌تواند تغییر کند.
مستقل از این استدلال، MT4 هم کامپایل شد: ۰ خطا، ۰ اخطار.

---

## ۶. تأیید (Verification)

| ورودی | نتیجه | زمان | خروجی |
|---|---|---|---|
| MT5 Full | **۰ خطا، ۱ اخطار** | ۲۶٫۶ ثانیه | `.ex5` ۱۷:۵۳:۵۳ |
| MT5 Lite | **۰ خطا، ۱ اخطار** | ۱۵٫۱ ثانیه | `.ex5` ۱۷:۵۴:۰۸ |
| MT4 Full | **۰ خطا، ۰ اخطار** | ۵۲۴ ms | `.ex4` ۱۷:۵۴:۱۶ |
| MT4 Lite | **۰ خطا، ۰ اخطار** | ۲۳۸ ms | `.ex4` ۱۷:۵۴:۱۷ |

اخطار باقی‌مانده همان `warning 63` شناخته‌شده است
(`PerformanceOptimizations.mqh:464`، `ArrayResize` روی آرایهٔ استاتیک — روی هر دو
پلتفرم no-op است و فقط MT5 گزارشش می‌کند).

صحت کامپایل MT4 از دو راه تأیید شد: `mtime` فایل `.ex4` جلو رفت **و** لاگ خام
هر ۵۰ فایل include را دوباره فهرست کرد (یعنی کامپایل واقعی، نه replay کش‌شده).

**گیت‌ها — همه سبز (۱۰ از ۱۰):**

```
zorder-audit          ok      probe-budget-audit    ok
ui-text-audit         ok      write-budget-audit    ok
chart-label-audit     ok      panel-colour-audit    ok
panel-wiring-audit    ok      base-count-audit      ok
gesture-budget-audit  ok      tf-unit-audit         ok  ← جدید
```

---

## ۷. فاز ۶ — چرخهٔ کامل تعویض تایم‌فریم (تحلیل ایستا)

`OnDeinit` روی MT5 ۴۸۵ ms است (`htf=203 handler=203 pnl=79`) در مقابل
۲۶۶–۳۲۸ ms روی MT4.

**آنچه بررسی شد:** هر دو مالک گران، **از قبل** شکل بهینهٔ «یک فراخوانی» را دارند:

- `DeleteHTFCandles()` → یک `ObjectsDeleteAll(0, g_HTFPrefix)` (P-PERF-14)،
  با گارد `g_HTFDrawnCount <= 0 && !HTFAnyBoxesExist()`؛
- `OnDeinitHandler()` → حدود ۵ `ObjectDelete` نام‌دار + sweep پیشوندی؛
- sweep مربوط به مهاجرت نام‌گذاری (`EventHandlers.mqh:24-51`) یک‌بارمصرف است
  و با `LegacyNameSchemeMigrated()` زودتر برمی‌گردد — هزینهٔ هر teardown نیست.

**نتیجه:** هزینه O(تعداد اشیا) **درون خود ترمینال** است، نه در تعداد
فراخوانی‌های ما. طبق یافتهٔ تثبیت‌شدهٔ این پروژه — «فراخوانی را روی MT5
ارزان‌تر نمی‌توان کرد، فقط می‌توان کمتر صدا زد» — و چون تعداد فراخوانی‌ها
از قبل یک است، **اهرم باقی‌مانده معماری است** (رسم اشیای کمتر یا بازاستفاده
به‌جای حذف/بازساخت).

**تصمیم:** هیچ تغییری بدون اندازه‌گیری انجام نشد. قاعدهٔ خود پروژه است که
«عددی بدون علت» مبنای اقدام نیست. فاز ۲ (جدول هزینهٔ primitive) پیش‌نیاز
این تصمیم است و به باز بودن ترمینال نیاز دارد.

---

## ۸. باز (Open) و گام بعد

**مسدود به ترمینال (فاز ۲):** جدول هزینهٔ primitive. سوئیچ پروب عمداً روشن
است (`MT5Compat/MT5PrimitiveProbe.mqh:25` — `ENABLE_MT5_PRIMITIVE_PROBE`).
هنگام عرضه باید خاموش شود.

**فاز ۴–۵ (بازبینی ۲ زیرابزار + ۱۰ پنل + مکانیزم‌های عرضی):** گیت
`tf-unit-audit` کلاس باگ واحد را پوشش می‌دهد، ولی بازبینی رفتاری هر پنل
(باز/بسته، کشیدن، DPI، Z-order، ویرایش‌گر متن) هنوز کامل نشده است.

**فاز ۷ (گزارش نهایی تطابق لاگ به لاگ):** به لاگ زندهٔ هر دو ترمینال نیاز دارد.

**فهرست حمل:** خاموش کردن پروب؛ تصمیم دربارهٔ `warning 63`؛ اصلاح ترتیب
آرگومان `ObjectsTotal` در `BiotakPanels.mqh:6964/6968`.

**هشدار مهم (AGENTS.md):** ویرایش‌های این نشست روی **سورس مشترک** (مخزن MT4)
نشسته‌اند. طبق قرارداد پروژه، این نشست نباید آن‌ها را commit کند — باید به
نشست کاری MT4 تحویل داده شوند. وضعیت MT4 در این لحظه **staged** است، پس
`git diff` تقریباً خالی به‌نظر می‌رسد؛ حقیقت در `git diff --cached` است.
