# همراستاسازی MT4 → MT5 — گزارش ۲۰۲۶-۱۰-۰۳

> **به‌روزرسانی سیاست (۲۰۲۶-۱۰-۰۳، ادامهٔ همان روز):** فرمان تازهٔ کاربر —
> «دقیقاً مثل متاتریدر ۴ باشه، نه چیزی کم نه چیزی زیاد؛ چیزهای اضافی متاتریدر ۵
> هم حذف بشه» — تصمیم قبلی («اضافی‌های MT5 جدا بمانند») را لغو کرد: همهٔ
> ویژگی‌های مخصوص MT5 از بیلد بیرون رفتند و هر ماژول MT5 دقیقاً متن MT4 شد.
> سند ماژول‌به‌ماژول: `docs/MT4-MT5-PARITY-MODULE-2026-10-03_FA.md`.
> جدول زیر فقط سابقهٔ مرحلهٔ اول است.

**هدف:** رفتار MT5 دقیقاً همان MT4 باشد؛ MT4 دستنخورده میماند و هر چیزی که لازم
است به کپی MT5 منتقل میشود (فرمان کاربر: «به mt4 کاری نداشته باشه هر چی نیاز
هستش کپی بشه»).

**نتیجه:** هر دو ورودی سبز —

```
Biotak Trigger TH3.mq5      : 0 errors, 0 warnings
Biotak Trigger TH3 Lite.mq5 : 0 errors, 0 warnings
```

## ۱. چه چیزی منتقل شد

| موضوع | فایلهای MT5 | منشأ در MT4 |
|---|---|---|
| DrawStrip کامل (۹ جزء، بدون include، با یک `(ENUM_OBJECT)type`) | `Biotak/DrawStrip.mqh` (۹۵۸۰ خط) | shell + `DrawStrip_Head/Base/Pick/GearA/GearB/Skin/Paint/Tap/Router` |
| انتخابگر رنگ پنل (`PalPickColor`/`PalCellIdParse`، P-DRAW-46/50) | `Biotak/BiotakPanels.mqh` | `BiotakPanels_PalA/PalB` |
| منطق TH Labels: رادیوی انحصاری + یادآوری حالت (پیشفرض STANDARD) | `Biotak/BiotakPanels.mqh`, `Biotak/BiotakMenu.mqh` | `BiotakPanels_Apply`, `BiotakMenu_*` |
| اوربدرگ P-UI-147 (`g_OrbMoved`، آستانهٔ ۱px، ذخیرهٔ خانه در رهاسازی) | `Biotak/BiotakMenu.mqh` | `BiotakMenu_A/C/D` (کار stageشدهٔ MT4) |
| داور ژست P-UI-144 روی جعبه و پا (`GestureTakeAllowed/Note/Release/Why`) | `Biotak/BaseKnotTool.mqh`, `Biotak/TH3Tool.mqh` | `BaseKnot_Drag/Measure`, `TH3Tool_C` |
| نگهبان تمیز (P-PERF-51) تگ شمارش | `Biotak/LabelFunctions.mqh` | `Labels_A/B` |
| حذف کلید PLATE (P-DRAW-89) | `Biotak/BiotakMenu.mqh` | `BiotakMenu_A` |
| اندازهٔ کش ۸تایی زمانهای استاندارد | `Biotak/StandardTimeframes.mqh` | `StandardTimeframes.mqh` |
| PathTool و HRayTool (بدون تغییر) | `Biotak/PathTool.mqh`, `Biotak/HRayTool.mqh` | همان فایلها (بایتبهبایت یکسان) |

نکتهٔ مهم: کار **stageشدهٔ** MT4 (هشت فایل، ۳۵۶ افزودن) قبلاً در MT5 نیفتاده بود؛
همهٔ آن حذفها همین امروز منتقل شد. برای دیدنشان:

```bash
cd ../Biotak-Trigger-TH3-mql4 && git diff --cached --stat
```

## ۲. افزودههای فقط-MT5 (طبق تصمیم کاربر: «هر کدوم جدا باشه»)

اینها در MT4 وجود ندارند و **جدا** نگه داشته شدند؛ هر کدام مالک نام خودش است و
با سطح مشترک قاطی نمیشود:

- **پالت ابزار رسم (ChartTools)** و **ریبون ابزارهای پینشده** (P-DRAW-53…58).
  ریبون صفحهٔ خودش را دارد: `PnlDrawS_R*` + `PnlDrawS_RBG` با همان هنر `ds_*`
  (خانوادهٔ مستقل، تا پلیت استریپ/پنل/بورد را بازنویسی نکند — درس P-DRAW-48).
- **نردبان ۳۴ سلولی ابزار** (`TOOL_FEATURE_COUNT`/`TOOL_DRAW_BASE`) با ستارهها و
  صفحهبندی (`ToolsPageSync`)، ماوسرنگ کشیده (`ToolsCellLit`)، مالک چهره
  (`ToolsFacePlace`).
- **CardCover** و نگهبان پیکسلی تگ شمارش (`CardCoverPxBlk`) و ردیفهای پوشیده
  (`CardCoverRightRowBlk`).
- **ماشین view-lock سهگانه** (P-DRAW-64، `s_viewAutoUser` + `ArrayResize(gvars,31)`).
- **`PnlCoverChanged()`** که در MT5 تابع MT4 (`PnlPublishCover` +
  `HTFCardCullRefresh`) را در بر میگیرد و دو کار اضافهٔ MT5 را هم انجام میدهد.
- **سازگاری پلتفرمی:** `(ENUM_OBJECT)type`، `CompatTF(...)`، `iBars(...)`،
  و سوئیچهای دقیقهای R-TF-UNIT (`case 1: return "M1";`).

## ۳. ابزار بازبینی (دوباره اجراپذیر)

```bash
python build-logs/reffull.py     # ریزکاری: خطوط MT4 که در MT5 گم شدهاند
python build-logs/reffull2.py    # نسخهٔ بیتفاوت به فاصلهگذاری (معیار نهایی)
python build-logs/hunks.py Biotak/<file>.mqh   # نمای دوطرفهٔ هر اختلاف
```

`reffull2.py` همهٔ ماژولهای MT4 را با includeهای بازگشتی (اجزای فقط-MT4) صاف
میکند و با فایل MT5 مقایسه میکند. **اکنون ۵۶ خط اختلاف باقی است و همه توجیهشده
است** (فهرست بالا) — یعنی هیچ منطق مشترکی گم نشده.

## ۴. ابزار اثبات رفتاری (ساخته شد)

```
python tools/make_sync_compare.py            # هر دو دوقلو را از ورودیهای امروز میسازد
python tools/make_sync_compare.py --deploy-mt4 "<MQL4\Indicators>"
python tools/parity/parity-diff.py --mt4 "<MQL4\Files>" --mt5 "<MQL5\Files>" --bar latest
```

- `tools/make_sync_compare.py` بدنهٔ دامپ را **بایتبهبایت** در هر دو دوقلو مینویسد، پس
  اگر دو CSV اختلاف داشتند، اختلاف در اندیکاتور است نه در ابزار اندازهگیری.
- `tools/parity/parity-diff.py` سه حکم میدهد: **INVENTORY** (مجموعهٔ نامها)،
  **PROPERTIES** (نوع/رنگ/استایل/ضخامت/ماسک TF/back/fill/ray/zorder/text — بدون اثر فید)،
  و **LADDER** (هندسه به واحد نسبی پایه: `(price-base)/adaptedStep`). چون دو
  ترمینال دو بروکر مختلفاند، قیمت مطلق پاسخ سؤال دیگری است؛ نردبان نسبی پاسخ
  سؤال برابری است.
- خودآزمایی: `python build-logs/parity_selftest.py` — یک جفت سالم (باید PASS شود) و یک
  جفت با نقص تزریقشده (باید FAIL شود و نام شیء را بگوید). هر دو درستاند.

**وضعیت استقرار:** هر دو دوقلو کامپایل شدهاند (MT5: 0 خطا در ریشهٔ همین مخزن که
ترمینال از طریق junction میبیند؛ MT4: 0 خطا در
`...\AMarkets - MetaTrader 4\…\MQL4\Indicators\`). برای MT4 یک junction به نام
`Biotak` در `MQL4\Indicators` ساخته شد که به `Biotak-Trigger-TH3-mql4\Biotak`
اشاره میکند — خودِ مخزن MT4 دستنخورده است و حذف آن junction هر زمان ممکن است.

## ۵. قدم بعدی

- اتصال `Biotak Sync Compare` روی یک چارت **تازه** با تنظیمات پیشفرض در هر دو
  ترمینال (نماد و تایمفریم یکسان)، یک تا دو کندل صبر، سپس اجرای `parity-diff.py`.
- `Biotak Update/AdaptiveScaling/FractalTimeframes/HistoricalDataFunctions/InputValidator`
  طبق همان ممیزی هیچ اختلافی ندارند.
