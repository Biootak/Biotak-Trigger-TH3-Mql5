# پورتِ کارِ جدیدِ MT4 به درخت MT5 — ۲۰۲۶-۱۰-۲۱

مرجع: درخت کاری MT4 (`../Biotak-Trigger-TH3-mql4`، تغییرهای staged بالای `dfdbae9`) — فقط‌خواندنی.
مقصد: `Biotak/` و `Engine/` همین مخزن. هیچ نوشتنی به MT4 انجام نشد.

## ۱. نتیجه

| سنجه | قبل | بعد |
|---|---|---|
| `tools/parity/gap-report.py` | `MISSING=40 DRIFT=145 EXTRA=30` | **`MISSING=0 DRIFT=93 EXTRA=29`** |
| `tools/parity/module-report.py` | ۱۵ RED / ۱ YELLOW / ۶۱ GREEN | همان (همه از کارِ اعلام‌شده‌ی MT5-only) |
| ساخت Full | — | **`0 errors, 0 warnings`** |
| ساخت Lite | — | **`0 errors, 0 warnings`** |
| `tools/check-pp-balance.py` روی `Biotak/*.mqh` | — | depth = 0 در همه |

`MISSING=0` یعنی **هیچ تابع/نماد/فایلی که در MT4 باشد و در MT5 نباشد باقی نمانده**.
`DRIFT` باقی‌مانده همان ۹۳ نمادی است که در پاس قبلی تریاژ شد (موتور کانواس، توکن رویداد،
R-TF-UNIT، memoها، sweepهای پیشوندی، walk تکه‌تکه) — هیچ‌کدام «MT5 عقب‌مانده» نیست.

## ۲. چه چیزی اضافه شد

| ویژگی MT4 | ماژول MT5 | یادداشت |
|---|---|---|
| **P-ANCHOR-LAST** — یک لنگر محاسبه‌ی فعال | `Biotak/CalcAnchor.mqh` (جدید) + `GlobalVariables` + `ATRCalculations` + `TradePlanFormulas` + `LabelFunctions` + `TH3Tool` + `BaseKnotTool` + `BiotakPanels` | `CalculateWeightedATR` حالا wrapper است: `CalcAnchorAt()>0` → `At(tf, anchor)`، وگرنه `CalculateWeightedATRLive` (بدنه‌ی قبلی، بایت‌به‌بایت). آشکارسازها صریحاً Live صدا می‌زنند |
| **P-BK-113/114** — ATR رانگِ owner | `Biotak/BaseKnot_Owner.mqh` (جدید) + جدول `BaseKnotOwnerATR*` در `BaseKnotTool` | `BaseKnotOwnerTFWalk` روی `CalculateWeightedATRAt`، پامپ در `BaseKnotEngPump` |
| **P-BK-112** — کلاسِ گره از کندل خودش، نه دقیقه‌ی تقویمی | `BaseKnotBaseTFRead/Tag/Line` | `spanMin = bars * commitTF`؛ گپِ آخر هفته دیگر رانگ نمی‌خرد |
| **P-BK-106b** — سه ATR واقعی | `BaseKnotAbilityGet/Read` + `BaseKnotEngNeeds` (۴ TF) + `abPatRead/abStrRead` | √-law فقط fallback سرد است |
| **P-TP4 روی نوت** — TRex / Trigger / Pricicle / Classic | `BaseKnotPlanLegsPush` + `BaseKnotLegsTag` + نوتِ چندخطی + پلیتِ چندخطی | `BaseKnotNotePlateH(txt)` و `BaseKnotNoteMaxLineW` بر مبنای تعداد خط |
| **P-UI-195** — رینگ دو دایره‌ای | `BiotakMenu_Ring.mqh` (کپی کامل) + `BiotakMenu.mqh` + `BiotakPanels` | `CircSeatSize` تنها مالکِ سایزِ صندلی؛ دایره‌ی دوم ۳۲px با `CircRing2Radius` و fit مستقل |

## ۳. تفاوت‌های عمدیِ این پورت

- `BiotakMenu_Ring.mqh` در MT5 بایت‌به‌بایت با HEAD در MT4 یکی بود، پس **کپی کامل** شد؛ هیچ
  MT5-only در آن نبود که از دست برود.
- `BaseKnotTool.mqh` در MT5 یک **مونولیت** است (چانک‌های `BaseKnot_*` در MT4 جدا هستند)، پس
  پورت تابع‌به‌تابع انجام شد و نه با `git apply`.
- `Biotak/Asset/…`‌ها و `BuildHash.mqh`: آیکون‌های `circ_*_30/32/35/39/43.bmp` از قبل در
  `Files/Icons` هستند و `#resource`شان در `BiotakMenu.mqh` هست؛ `BuildHash` مثل قبل stale
  ماند (تولیدکننده‌ی MT5 ندارد).

## ۴. تست دستیِ باقی‌مانده

1. کارت ATR → ردیف **LAST OBJECT** را روشن بگذار، یک LegMeasure بکش: اعداد ATR باید روی
   کندلِ تیپِ همان لِگ قفل شوند؛ با حذف لِگ به حالت live برگردند.
2. یک باکس گره بکش کهن‌تر از آخر هفته → کلاس باید `H1 base` بماند، نه `H4`.
3. نوت گوشه: چهار لِگ TRex/Trigger/Pricicle/Classic در یک خط، ATR سه رانگ در خط دوم،
   `TF … | Leg n%` در خط سوم؛ پلیت باید هر سه خط را بپوشاند.
4. رینگ: ۱۰ ستاره + درب → نه صندلی داخلی ۴۴px و بقیه روی دایره‌ی دوم ۳۲px، بین دو صندلی.
