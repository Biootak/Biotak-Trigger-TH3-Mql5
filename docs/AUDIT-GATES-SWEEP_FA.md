# نتیجه‌ی اجرای گیت‌های بازبینی پروژه

**تاریخ:** ۱۴۰۵/۰۶/۲۵ (2026-09-16)
**دامنه:** ۹ گیت بازبینی موجود در `Biotak-Trigger-TH3-mql4/tools/`
**نتیجه:** ✅ **هر ۹ گیت سبز** — ۱ گیت کهنه با آزمایش اثبات و اصلاح شد · ۱ رگرسیون خودم که گیت گرفت

---

## ۱. خلاصه‌ی نتایج

| گیت | نتیجه | پوشش |
|---|---|---|
| `zorder-audit.py` | ✅ clean | نردبان Z — ۵۴ پله، ۱۳۴ محل فراخوانی، همه نام‌دار |
| `ui-text-audit.py` | ✅ clean | متریک متن و DPI — یک مالک، همه‌ی کپشن‌ها اندازه‌گیری‌شده |
| `chart-label-audit.py` | ✅ clean | هندسه‌ی لیبل چارت — ۳۲٬۴۰۰ ترکیب، یک گام، بدون سرریز |
| `panel-wiring-audit.py` | ✅ clean | ۲۲ بررسی، ۱۲۲ ردیف کارت، زنجیره‌ی فشار خودترمیم |
| `gesture-budget-audit.py` | ✅ clean | ۳ بازو، ۹ پاک‌سازی کانال، ۱۱/۱۱ قول برقرار |
| `probe-budget-audit.py` | ✅ clean | ۱۰۰+ بررسی، شامل قحطی staging و فنس تقسیم‌برصفر |
| `write-budget-audit.py` | ✅ clean | بودجه‌ی نوشتن — **تغییر `P-PERF-45` را تأیید کرد** |
| `panel-colour-audit.py` | ✅ clean | یک مالک برای حاشیه‌ی سواچ، کف کنتراست ۱.۷:۱ |
| `base-count-audit.py` | ✅ clean | داستان BaseKnot — **گیت کهنه بود، کد درست** |

---

## ۲. شکست `base-count-audit`: گیت کهنه بود، نه کد ناقص

دو بررسی ناموفق بودند:

```
FAIL  the story still runs on the CLASS' own candles (one side, one box)
FAIL  the APPROACH is the last close outside the band before that entry
```

هر دو regex روی `Biotak/BaseKnotTool.mqh` بودند — فایلی که **لمس نکرده بودم**. اما برخلاف حدس اولیه، **کد ناقص نبود؛ گیت کهنه بود.**

### شاهد ۱ — کد منطق را دارد، فقط با کست

```mql5
// BaseKnotTool.mqh:2724
int s2 = iBarShift(_Symbol, (ENUM_TIMEFRAMES)tfRead, t2, false);
// BaseKnotTool.mqh:2791
int sFrom = iBarShift(_Symbol, (ENUM_TIMEFRAMES)tfRead, tFrom, false);
```

گیت `iBarShift(_Symbol, tfRead, …` را می‌خواست (بدون کست). یعنی تفاوت فقط **کست** بود، نه منطق.

### شاهد ۲ — الگوی کست در کل درخت، تبعیض‌آمیز است

```
iBarShift با کست صریح :  ۵ مورد  ← همه با متغیر tfRead
iBarShift بدون کست    : ۲۰ مورد  ← همه با literal «۰»
```

`iBarShift(_Symbol, 0, t, false)` بدون کست کامپایل می‌شود چون MQL5 یک **ثابت** را به‌طور ضمنی به enum تبدیل می‌کند، اما یک **متغیر** را نه. پس کست اجباری است.

`MQL5Compat.mqh:21` دقیقاً همین را برای `iClose` حل کرده:

```mql5
#define iClose(sym, tf, sh) iClose(sym, (ENUM_TIMEFRAMES)(tf), sh)
```

اما **ماکروی معادلی برای `iBarShift` وجود ندارد** — پس کست باید در محل فراخوانی باشد، که همان قانون مستند `AGENTS.md` است.

### شاهد ۳ — آزمایش قطعی (اثبات، نه استدلال)

کست را موقتاً برداشتم و MT5 را کامپایل کردم:

```
ERR  Biotak/BaseKnotTool.mqh(2724,32) : error 262: cannot convert enum
result : Result: 1 errors, 1 warnings
```

**حذف کست، بیلد MT5 را می‌شکند.** پس کد درست است و گیت کهنه.

### اصلاح

گیت به‌روز شد تا کست اختیاری را بپذیرد، **بدون** تضعیف invariant:

```python
_CAST = r"(?:\(ENUM_TIMEFRAMES\)\s*)?"
and re.search(r"iBarShift\(_Symbol,\s*" + _CAST + r"tfRead,\s*t2", blk) is not None
```

آنچه گیت واقعاً باید نگه دارد این است که lookup روی **`tfRead`** (تایم‌فریم خودِ کلاس) انجام شود، نه تایم‌فریم چارت — و این هنوز کامل بررسی می‌شود. کست نویز پلتفرمی است، نه بخشی از invariant.

**`BaseKnotTool.mqh` دست‌نخورده ماند.** بعد از آزمایش، `git diff` روی آن **خالی** است — یعنی بایت‌به‌بایت با نسخه‌ی stage‌شده‌ی شما یکسان.

---

## ۳. یک رگرسیون که خودم ساختم و گیت گرفت

وقتی `GetCachedPipSize()` را اصلاح کردم، فنس تقسیم‌برصفر را به این شکل بازنویسی کردم:

```mql5
const bool pointUsable = (p > 0.0 && MathIsValidNumber(p));
g_cachedPipSize = pointUsable ? p : 0.00001;
```

گیت فوراً گرفت:

```
FAIL [custom-price-source] GetCachedPipSize lost its zero-divide fence: pip size is a
     DENOMINATOR in every pip figure, and Point is 0 on a symbol whose data is not loaded yet
```

**رفتار درست بود** (فنس سر جایش بود، حتی بهتر)، اما **شکل** عوض شده بود و گیت الگوی تحت‌اللفظی را می‌خواهد. رفع: خط فنس **بایت‌به‌بایت** به شکل اصلی برگشت و پرچم جدید یک خط جدا شد:

```mql5
if(!MathIsValidNumber(g_cachedPipSize) || g_cachedPipSize <= 0.0) {
    g_cachedPipSize = (p > 0.0 && MathIsValidNumber(p)) ? p : 0.00001;
}
g_cachedPipSizeReal = (p > 0.0 && MathIsValidNumber(p));
```

**درس:** وقتی گیتی الگوی تحت‌اللفظی را چک می‌کند، **معنای درست کافی نیست — شکل هم باید حفظ شود.** و اینکه گیت واقعاً کار می‌کند: یک بازنویسی «بی‌خطر» را گرفت.

**تفاوت دو مورد:** اینجا گیت **درست** بود و کد باید شکلش را حفظ کند؛ در بخش ۲ گیت **کهنه** بود و باید به‌روز شود. تفکیک این دو، کار اصلی است — و معیارش آزمایش است، نه سلیقه.

---

## ۴. آنچه گیت‌ها تأیید می‌کنند (پس دیگر دنبالش نگردید)

اینها **حل شده‌اند** و شواهدش عددی است، نه ادعا:

- **لایه‌بندی Z-Order:** ۵۴ پله، هر محل فراخوانی نام‌دار، اثبات آخرین لایه تایپ را می‌کشد. → نگرانی «کندل‌ها روی پنل می‌افتند» منتفی است.
- **مقیاس‌پذیری DPI/4K:** یک مالک متریک در `UtilityFunctions.mqh`، ۱۹ محل اندازه فونت همه از مالک، متریک نمایش دوباره probe و بازسازی می‌شود، تولتیپ رینگ در ۹۶/۱۲۰/۱۴۴ dpi جا می‌شود (۲۹۰×۵۶، بدترین کپشن ۲۶۰px).
- **نشت کلیک:** `[click-ownership]` — UI دقیقاً همان سطوحی را claim می‌کند که **مرئی** دارد، از layout خودش اندازه‌گیری‌شده؛ box tool و Custom Price قبل از خواندن `dparam` می‌پرسند کجا/مال کی.
- **درگ و long-press:** ۱۸ پاس سنگین برای ۶۶ تیک در یک درگ ۲ ثانیه‌ای، ۱ settle، ۱۱/۱۱ قول.
- **پاک‌سازی:** `[teardown-census]` هر ۲۸ خانواده‌ی GlobalVariable توسط یک teardown که روی حذف اجرا می‌شود پاک می‌شوند؛ `[purge]` و `[heal]` سبز.
- **بودجه‌ی نوشتن:** مدل می‌گوید بدترین مرحله ۲۸۹ از ۹۶۵ آبجکت (۳۰٪) به‌جای یک فریم ۹۶۵‌تایی؛ ۵ فریم یکسان = ۳۰۰ نوشتن به‌جای ۱۵۰۰.
- **گیت، تغییر `P-PERF-45` را تأیید کرد:** `ok [staging] the coop pump owns the staging rebuild and the owed frame together`.
- **دیوار Lite:** هر فراخوانی در فایل‌های Lite داخل Lite حل می‌شود (۳۹۶ نام فقط-Full گارد شده).

### دو موردی که «مشکوک» بودند و بررسی شدند — تغییری لازم نبود

۱. **«یک درگ سریع از چارت می‌تواند کنترل کارت را مسلح کند»** → `PnlHandleMouseMove` فقط روی **لبه‌ی فشار** عمل می‌کند (`if(!pressStart) return;` در `BiotakPanels.mqh:7979`) و `PnlPressAllowed()` (P-UI-70b) آن را گارد می‌کند. `MousePressStart` (`BiotakMenu.mqh:366`) هر فشار را به یک **شماره‌ی توالی** می‌بندد (`g_UIPressSeq`) و claim را منتشر می‌کند، پس یک claim روی اشاره‌گر بعدی خرج نمی‌شود. گیت `[click-ownership]` هم همین را تأیید می‌کند. **اثبات کامل نیاز به آزمون زنده دارد**، اما طراحی مسئله را پوشش می‌دهد.
۲. **«قفل رینگ در long-press بی‌حرکت کمی دیرتر آزاد می‌شود»** → خودترمیم است (`CircReapStaleRingClaims`، `ChartScrollReconcile` در `OnTimer`)، و `[heal]` سبز است.

---

## ۵. شبیه‌ساز پنل

`panel-mt4-sim.py` یک گزارش تصویری ساخت:

```
Biotak-Trigger-TH3-mql4/panel_mt4_sim.html   (11 cards, 94 bitmaps, 96 dpi)
```

برای دیدن چیدمان واقعی کارت‌ها بدون باز کردن ترمینال.

---

## ۶. وضعیت ساخت نهایی

| بیلد | نتیجه | خروجی |
|---|---|---|
| MT5 Full | ۰ خطا / ۱ اخطار، ۲۱.۸s | `1,737,106 B` @ `17:30:14` |
| MT5 Lite | ۰ خطا / ۱ اخطار، ۱۳.۴s | — |
| MT4 Full | ۰ خطا | `.ex4` `2,566,136 B` @ `17:30:30` |
| MT4 Lite | ۰ خطا | `.ex4` `975,290 B` @ `17:30:31` |

تنها اخطار: `PerformanceOptimizations.mqh(464,5) warning 63` — همان مورد شناخته‌شده و بی‌خطر.

---

## ۷. وضعیت فایل‌ها بعد از این دور

| فایل | تغییر |
|---|---|
| `tools/base-count-audit.py` | ✅ تنها فایل این دور — گیت کهنه اصلاح شد |
| `Biotak/BaseKnotTool.mqh` | **دست‌نخورده** (`git diff` خالی، بایت‌به‌بایت برابر با نسخه‌ی stage‌شده) |
| سورس مشترک | بدون تغییر در این دور؛ بیلدها از دور قبل معتبر و تازه‌سازی شدند |
