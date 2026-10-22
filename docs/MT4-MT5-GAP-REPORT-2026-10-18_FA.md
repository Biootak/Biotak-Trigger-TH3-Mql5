# گزارش کامل شکاف منطق و رفتار — MT5 ↔ MT4

**تاریخ اسنپ‌شات:** 2026-10-18 (سنجش و بیلد در ساعت ۱۷:۳۶ به بعد)
**ابزار:** `tools/parity/module-report.py` + `tools/parity/gap-report.py` (هر دو read-only)
**وضعیت بیلد این اسنپ‌شات:** هر دو entry سبز —
`Biotak Trigger TH3.mq5` → `0 errors, 0 warnings` (log: `build-logs/Biotak-Trigger-TH3-20261018-173642.log`)
`Biotak Trigger TH3 Lite.mq5` → `0 errors, 0 warnings` (log: `build-logs/Biotak-Trigger-TH3-Lite-20261018-173753.log`)

> **این سند «همه‌چیز» را لیست می‌کند:** ۴۲ نماد MISSING، ۱۱۶ نماد DRIFT، ۴۷ نماد/بلوک EXTRA،
> به‌علاوهٔ لایهٔ سازگاری MT5Compat و ریسک‌های «پیاده‌سازی‌شده ولی وابستگی‌بررسی‌نشده».
> خروجی خام هر دو ابزار عیناً در پیوست الف و ب آمده است.

---

## ۰) خلاصهٔ اجرایی

| سنجه | مقدار |
|---|---|
| ماژول‌های محصول | ۷۳ فایل `.mqh` + هر دو entry |
| ماژول‌های GREEN (رفتار هم‌ارز) | ۶۴ |
| ماژول‌های RED (کار باقی است) | **۱۳** = ۱۱ ماژول محصول + ENTRY + ENTRY-LITE |
| نمادهایی که MT4 دارد و MT5 ندارد | **۴۲** — تماماً در `DrawToolbar` (۲۷) و `DrawStrip` (۱۵) |
| نمادهای هم‌نام با بدنهٔ متفاوت | **۱۱۶** |
| نماد/بلوک‌های فقط-MT5 | **۴۷** |
| زیرسیستم محاسبه/رسم با عدد متفاوت | `LevelPipeline` و `TH3Renderer` → RED |

**بزرگ‌ترین شکاف کارکردی (کارِ اصلی باقی‌مانده):**
بازنویسی کامل سیستم **تمپلیت نقشه‌کشی** در MT4 (`P-DRAW-132` / `P-DRAW-135` — «مثل تریدینگ‌ویو: تمپلیت‌های نام‌دار per-kind، سیو/اپلای/حذف/پیجر») که معماری قدیمی preset را رسماً حذف کرده است.
MT5 هنوز روی معماری **قدیمی preset** (`DrawPreset*`) + look سه‌بعدی (`P-LOOK-3D`) کار می‌کند که در MT4 وجود ندارند.

**صحت بیلد ⇒ ناقص‌بودن معنایی، نه شکست کامپایل:**
هر دو entry صفر خطا می‌گیرند؛ یعنی هیچ نامِ آویزانِ کامپایلی نداریم. شکاف‌ها همه از جنس «رفتار/وابستگی» هستند، نه ارجاع حل‌نشده.

**هشدار درخت کاری:**
هر دو مخزن dirty هستند. مقایسهٔ این سند بین «working tree» هر دو درخت انجام شده:
- MT5: شاخهٔ `sync-mt4-reference`، HEAD `151aac8` (2026-10-17)؛ ۱۴ فایل ردیابی‌شدهٔ ویرایش‌شده + ۷ ماژول جدید untracked + ۲۰ آیکون untracked (پورت در جریانِ P-SESS/P-UI-16x).
- MT4: شاخهٔ `main`، HEAD `a00c267` (2026-10-17)؛ ۳۵ فایل ویرایش‌شدهٔ uncommitted (کار جاری روی DrawStrip/DrawToolbar/…).

---

## ۱) روش، برچسب‌ها و معنی‌شان

- **GREEN** — هیچ خط یک‌طرفهٔ «اعلام‌نشده» ندارد؛ هر تفاوت با آیدیاوم‌های اعلام‌شده (پلتفورم/واحد زمان) توضیح داده می‌شود (`BAD=0`).
- **RED** — خطوط یک‌طرفه‌ای دارد که نه MT4-twin دارند نه آیدیاومِ اعلام‌شده ⇒ پورت/تأیید لازم است.
- **MISSING** (در گزارش نمادها) — نماد در MT4 هست، در MT5 نیست ⇒ قابلیت/منطق گم‌شده.
- **DRIFT** (در گزارش نمادها) — نماد هم‌نام است ولی بدنه متفاوت ⇒ تفاوت رفتار؛ اندازهٔ diff + درصد + تگ‌های `P-*` هر طرف.
- **EXTRA** — نماد فقط در MT5 ⇒ یا مخصوص پلتفورم/موتور/پرف (مشروع)، یا بازماندهٔ معماری قدیمی (کاندید حذف).
- **MT5-ONLY / R-TF-UNIT** — مارکرهای درون‌کد برای تفاوت‌های عامدانهٔ پلتفورمی.

`module-report.py` تفاوت‌ها را با آیدیاوم‌های اعلام‌شده تطبیق می‌دهد؛ `gap-report.py` حتی آیدیاوم‌ها را هم لیست می‌کند
(بنابراین DRIFT در یک ماژول GREEN یعنی «آیدیاومِ واحد زمان/پلتفورم»، نه رفتار متفاوت).

---

## ۲) تصویر عددی — ماژول‌های RED

| ماژول | خط بد (BAD) | سمت MT4 | سمت MT5 | نمادهای کلیدی متفاوت |
|---|---:|---:|---:|---|
| `DrawToolbar.mqh` | ۴۸۷ | ۳۱۵ | ۱۷۲ | `DrawTpl*` ↔ `DrawPreset*`، `FibPen*`، `DRAW_*` |
| `DrawStrip.mqh` | ۲۳۵ | ۱۹۲ | ۴۳ | `DrawStripGear*`، `DrawStripTpl*` (MISSING)، `DrawStripMore*`، `DrawStripPick*` |
| `TH3Tool.mqh` | ۱۳۶ | ۳۰ | ۱۰۹ | `OnABCDMouseEvent`، بلوک‌ها، `TH3RestorePatternsFromChart`، `TH3ReadPatternAnchors` (extra) |
| `TH3Renderer.mqh` | ۱۰۹ | ۱۹ | ۱۵۳ | `DrawABCDPattern` (۲۰۵ خط)، `TH3PivotMarkersClear`، پل RBridge |
| `EventHandlers.mqh` | ۱۰۳ | ۷ | ۹۶ | `RedrawAllObjects`، `OnInitHandler`، `OnChartEventHandler`، `P4*Census`/teardown stamps (extra) |
| `LevelPipeline.mqh` | ۶۶ | ۶۷ | ۱۲۷ | `SweepForeignLadderObjects` (۶۰٪)، `RenderZones`، `ExecutePipeline`، `RenderTriggerLines`، پل RBridge |
| `BiotakPanels.mqh` | ۳۸ | ۱۳ | ۲۵ | `PnlApplySet` (37 خط)، `UISyncDrain` |
| `BiotakMenu.mqh` | ۳۲ | ۱۸ | ۱۴ | `DeleteMenu` (۷۲٪)، `DeleteLegacyMenuObjects`، `RingFeatureClick`، `CircTipDragTo` |
| `HTFCandles.mqh` | ۲۳ | ۳ | ۲۶ | `DrawHTFCandles`، `HTFProbe*` ↔ `HTFAdoptKeptFamily`/handoff (extra) |
| `BiotakKit.mqh` | ۱۴ | ۰ | ۱۴ | `SetMidZonesVisible` (extra)، `ApplyRefreshFlags` (extra) |
| `GlobalVariables.mqh` | ۱۱ | ۰ | ۱۱ | شمارنده‌های `g_pInitMs*` + `attachTailPending` (extra) |
| `ENTRY` (`.mq5`) | ۲۲ | ۱ | ۲۱ | بلوک‌های MT5-ONLY: RBridge، CompatRefreshChartData، census |
| `ENTRY-LITE` | ۸ | ۰ | ۸ | همان بلوک‌ها در نسخهٔ Lite |

**ماژول‌های عددساز:** از ۱۶ ماژول «عدد/رسم»، فقط `LevelPipeline` و `TH3Renderer` قرمز شده‌اند؛ بقیه GREEN ⇒
ریاضیات TH/ATR/Zone/TradePlan عیناً هم‌ارز است (شامل `TH3Math`, `TH3Pivots`, `THCalculations`, `TradePlanFormulas`, `ZoneCalculator/Factory/Validator`).

---

## ۳) شکاف قابلیت — MT4 دارد، MT5 ندارد (MISSING = ۴۲)

### ۳.۱ سیستم تمپلیت نقشه‌کشی (کارِ پورت‌نشدهٔ اصلی)

در MT4 این سیستم جایگزین معماری preset شده است (`Toolbar_Tpl.mqh` — درخواست کاربر: «می‌خوام تمپلت‌های مختلف رو سیو کنم و به راحتی هرکدوم خواستم فعال کنم بشه… معمارشو از نو بنویس و معماری قبلی رو حذف کن»).

**مدل رفتاری MT4:**
- هر نوع ابزار (per-kind) تا `DRAW_TPL_MAX` تمپلیت **نام‌دار** دارد؛ سیو زیر اسم تکراری = جایگزینی، اسم نو = append، رک پر = **ردّ با ویتنس** (بجای overwrite خاموش).
- حذف = فشرده‌سازی لیست؛ ایندکس ردیف همان ردیف است.
- اپلای = کل look (۹ مقدار: رنگ/ضخامت/استایل/fill/ray/کپشن/گلیف/لایه/رنگ داخل) + **learning** (طراحی بعدی همان نوع آن را می‌پوشد).
- برای فبیوها **سطح‌ها هم ذخیره می‌شوند** (`DRAW_TPL_LVL_ROW` — ردیف اختصاصی در باند 100+slot، جدا از باند ۰..۱۱ و صندلی‌های رزرو 254/255).
- صندلی‌های رزرو فایل: look ماندگار (P-DRAW-09c) + «آخرین جوهر مشترک» (P-DRAW-INK).
- خانهٔ فایل یکی است: `DRAW_TPL_FILE` + مهاجرت از فایل legacy (`DRAW_TPL_LEGACY`، `DrawTplMigrate`)، seed اولین اجرا (`DrawTplSeed`/`DrawTplSeedOne`)، بوت (`DrawTplBoot` — از init در `EventHandlers` صدا زده می‌شود).

**نمادهای غایب در MT5 — `DrawToolbar` (۲۷):**
`DRAW_TPL_FILE, DRAW_TPL_LEGACY, DRAW_TPL_LVL_ROW, DRAW_TPL_MAX, DRAW_TPL_PAGE,`
`DrawLook, DrawLookPackA, DrawLookPackB, DrawLookUnpackA, DrawLookUnpackB,`
`DrawTpl, DrawTplApply, DrawTplBoot, DrawTplCount, DrawTplDelete, DrawTplIndex, DrawTplLevelsOf, DrawTplLevelsTo, DrawTplLoad, DrawTplMigrate, DrawTplName, DrawTplPath, DrawTplPut, DrawTplSave, DrawTplSaveAs, DrawTplSeed, DrawTplSeedOne`

**نمادهای غایب در MT5 — `DrawStrip` (۱۵):**
`DSTRIP_MK_TPLNAV, DSTRIP_PICK_DEL_W,`
`DrawStripPickDelFaceName, DrawStripPickDelName, DrawStripPickTapDel,`
`DrawStripTplApplyGroup, DrawStripTplCommit, DrawStripTplNameFocus, DrawStripTplNavText, DrawStripTplRowDelete, DrawStripTplSaveHit, DrawStripTplSaveName, DrawStripTplSavePaint, DrawStripTplSaveSweep, DrawStripTplSaveW`

**معادل فعلی MT5 (معماری قدیمی):** `DrawPreset*` — سه اسلات builtin + سه اسلات کاربری بی‌نام، و در استریپ فقط یک ردیف quick-save («Save current look») بدون ادیتور اسم، بدون حذف، بدون پیجر.
⇒ **نتیجهٔ رفتاری برای کاربر MT5 امروز:** نه می‌تواند تمپلیت را نام‌گذاری کند، نه حذف کند، نه بین صفحه‌ها بچرخد، نه سطح‌های فبیو را با تمپلیت ذخیره کند، و رکِ پر آخرین را بی‌صدا overwrite می‌کند.

### ۳.۲ فهرست کامل هر ۴۲ MISSING
همان دو گروه بالا؛ جمع = ۲۷ + ۱۵ = ۴۲. جایی دیگری MISSING وجود ندارد (سایر ۷۳ ماژول هیچ نماد گم‌شده ندارند).

---

## ۴) تفاوت رفتارِ نمادهای هم‌نام (DRIFT = ۱۱۶)

### ۴.۱ ماژول‌های RED — تفاوت‌هایی که باید پورت/تأیید شوند

**`DrawToolbar.mqh`** (diff ~۵۰۰ خط):
- `FibPenSync` (۴۵ خط، ۶٪) و `FibPenDragFollow`، `FibPenPreviewArm/End`، `DrawSlotWrite`، `FillChildEnsure` — خانوادهٔ look/قلم فبیو؛ MT5 نسخهٔ ۳D را دارد و MT4 نه (بخش ۵.۴).
- ردیف‌های style: MT5 `DRAW_SLOT_STYLE = 9` (سه neon/caps/wash + 3D)، MT4 `= 8`. `FIBPEN_STYLE_3D` در MT5 ردیف نهم است.

**`DrawStrip.mqh`**:
- `DrawStripGearObjectsPurge` (۸۰ خط، ۹۳٪)، `DrawStripClose` (44)، `DrawStripOnEvent`، `DrawStripPaint`، `DrawStripMoreTap/Build/Tip/Text` — ساخت منوی چرخ‌دنده/رک تمپلیت.
- `DrawStripGearRowTap/Content/Tip/Text/Close/GroupDigest` + `DrawStripDiagEmit/Close` (extra) — ردیف‌ها و دیالوگ‌ها.
- `DrawStripLevelsToggle`/`DrawStripLevelsRewrite` [P-LVL-SCALE, P-LVL-TEXT] — رندر سطح‌ها.
- `DrawStripEditEnd`، `DrawStripPickTap/Count/ClosePicker/PopRowRes`، `DrawStripDuplicate`، `DrawStripFootTap`، `DrawStripHoldLatch` — تعاملات پیکر/فوتر.

**`BiotakMenu.mqh`**:
- `DeleteMenu` (۲۶ خط، ۷۲٪) و `DeleteLegacyMenuObjects` (۷۵٪): MT5 کل خانواده را با یک sweep پیشوندی `ObjectsDeleteAll(0, "BiotakMenu_<chart>_")` پاک می‌کند؛ MT4 نام‌به‌نام (CircIcon/CircBg/CircBadge/CircBadgeTxt/ToolsBg/ToolsIcon/…) حذف می‌کند. مکانیزم حذف رویدادهای برنامه‌ای در MT5 (بخش ۶) این تفاوت را پوشش می‌دهد، ولی دامنهٔ sweep دیگر «دقیقاً همان مجموعهٔ کلاسیک» نیست.
- `RingFeatureClick`، `InitializeUIStates`، `SetHTFVisible`، `CircTipDragTo` — بودجهٔ redraw درگ رینگ (`CIRC_DRAG_REDRAW_INTERVAL`) + `CircReassertLock` فقط در MT5؛ در MT4 `g_redrawTHLevelsNeeded` و redraw مستقیم.

**`BiotakPanels.mqh`**:
- `PnlApplySet` (۳۷ خط): MT4 علم‌ها را `flags=REFRESH_BUFFERS` یا `g_labelsRelayoutNeeded=true; flags=REFRESH_ALL` می‌گذارد؛ MT5 `RequestUISync()` صدا می‌زند و `flags=REFRESH_NONE` برمی‌گرداند (تأخیر تا درینِ UISync). مسیر پایانِ کار باید یکی باشد — تأیید لازم.
- `UISyncDrain` (۱ خط).

**`EventHandlers.mqh`** (۹۶ خط فقط-MT5 در همین فایل):
- `RedrawAllObjects` (۶۴ خط)، `OnInitHandler` (۳۵)، `OnChartEventHandler`، `ResolveTopologyAdoption`، `RunIncrementalObjectCleanup`، `SetTriggerLevelsVisible`، `DrawLevelsBasedOnMode`، `OnCalculateHandler`، `OnDeinitHandler`، `P4ReportSlow`.
- MT4-Only داخل همین‌ها: `ThrottledChartRedraw()` (۲ بار)، GV با نام `Biotak_TH3_NeedsUpdate_<chart>`، و **`DrawTplBoot()` در init** — یعنی وابستگی بوت تمپلیت‌ها هم اینجاست.
- MT5-Only: `P4ObjectCensus`، `P4LeftoverCensus`، `RepaintLabelsForSwitch`، `AttachToolRestoreLegacy`، `TailRestoreDeferred`، `ResolvePeriodChangeAttach`، `ConsumeCleanUITeardownStamp`/`StampCleanUITeardown`/`UITearStampName`، `SavePeriodStamp`/`LastPeriodStampName` (۲۲+۱۳+۱۳+۱۵+۱۶+۲۱+۲۲ خط) — مخصوص ترتیب رویداد/attach در MT5.

**`GlobalVariables.mqh`** — فقط-MT5: ۱۰ شمارندهٔ `g_pInitMs*` (پروفایل init) + `g_attachTailPending`؛ `ChartViewRestoreUser` [P-UI-114] ۲ خط.

**`HTFCandles.mqh`** — `DrawHTFCandles` [P-HTF-TOP, P-PERF-08]، `HTFProbeCull`/`HTFProbeSettings` [P-HTF]؛
فقط-MT5: `SaveHTFHandoffStamp`/`HTFAdoptKeptFamily`/`HTFKeptStampName` (تحویل خانوادهٔ HTF بین attachها).

**`LevelPipeline.mqh`** (کل خط لولهٔ سطوح/زون‌ها — RED عددی):
- `SweepForeignLadderObjects` (۷۵ خط، ۶۰٪) [P-LBL-12, P-PERF-55]، `RenderZones` (۴۱ خط، ۲۷٪)، `ExecutePipeline` (۳۲)، `RenderTriggerLines` (۲۵، ۲۴٪)، `BuildZonesAndLines`، `StructureRecolourWalk`، `PipelineGeometryKey`، `TriggerFamilyWalk`، `LevelSplitCounts`، `SZoneDefinition`، `STriggerLine`، `CleanupSurplusPipeline`.
- فقط-MT5: `RBridgeZoneFamilyMask/ZonesBegin/ZonesMarkStale/ZonesStale/ZoneRecolour/TriggerWalk/Pinned/End` + محاسبهٔ `rbPxPerPrice` از ChartGet* — پل موتور رندر.
- فقط-MT4: مسیر `HideAllZoneFamilyObjects` مستقیم، مجموعهٔ `produced[]`/`LadderSetBuild`، ترتیب حذف `for(int i = total - 1; …)`.
⇒ وقتی `BIOTAK_RENDER_ENGINE` خاموش شود (A/B آبجکتی)، مسیر آبجکتی MT5 باید با منطق MT4 هم‌ارز باشد — نقطهٔ بازبینی.

**`TH3Tool.mqh`**:
- `OnABCDMouseEvent` (۷۴ خط، ۲۴٪) [P-TH3-PERF-05, P-TH3-PB-DRAG, P-TH3-BAND-PRESS, P-TH3-PB-OFF, P-LM-13]، بلوک ۵۱ خطی ۵۵٪ [P-LM-20, P-TH3-PB-LOCK, P-BK-03]، `TH3RestorePatternsFromChart` (۲۶٪)، `SetActiveABCDPattern`، `LegMeasureUpgradeLegacy`، `TH3_ExportCurrentSample`، `TH3BaseEditorSync`.
- فقط-MT5: `TH3ReadPatternAnchors` (۴۹ خط)، `TH3LiveDragUnlatch`، `TH3LiveDragHeartbeat` — درگ زندهٔ TH3.
- نسخهٔ کاری MT5 (uncommitted) گاردهای mute (`P-UI-160b`) و بازنویسی خواندن LEG (`P-LM-25`) را اضافه کرده است — با MT4 HEAD هم‌راستا می‌شود ولی drift باقی است.

**`TH3/TH3Renderer.mqh`**:
- `DrawABCDPattern` (۲۰۵ خط، ۱۰٪) [P-UI-160, P-TH3-INFO-01, P-TH3-STEP-16, P-TH3-PB-MAN, P-TH3-STEP-04] — بزرگ‌ترین تابع متفاوت محصول.
- `TH3PivotMarkersClear` (۵۰٪)، `TH3InfoOrphanPlateSweep`، `TH3FamilyAnchorsAlive`، `TH3InfoCaptionHeal`، `TH3HitPivotForward`.
- فقط-MT5: `if(RBridgeActive()) return true;` + `RBridgePatternDropBase` — «فاز A موتور رندر: خانوادهٔ پترن به کانواس می‌رود» (کامیت `151aac8`).
- فقط-MT4: سه گارد `if(IsIndicatorHidden()) return;` + `bool isActive = (g_activeABCDPattern == mainObjName)` — یعنی MT4 مخفی‌بودن (mute F) را در همین توابع مستقیم گارد می‌کند؛ MT5 مسیرش از پل/ماسک می‌گذرد. **هم‌ارزی در حالت hide باید تأیید شود.**

**`ENTRY` / `ENTRY-LITE`** (بلوک‌های MT5-ONLY — از AGENTS.md و کامنت‌ها):
`ArraySetAsSeries` روی آرایه‌های `OnCalculate`، `CompatRefreshChartData()`، `RBridgeInit/RBridgeShutdown`، `RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones)` در `OnChartEvent`/`OnTimer`، `P4LeftoverCensus("oninit"/"remove")`، `TailRestoreDeferred()`، و منطق `p116keep = (reason == REASON_CHARTCHANGE)` (نگه‌داشتن TF).
سمت MT4 فقط یک خط اضافه در لاگ `OnDeinit` (`ms handler=…`) دارد.

### ۴.۲ ماژول‌های GREEN — driftهای ایدیاومی (رفتار عامدانه، بدون تفاوت)

این‌ها در گزارش gap می‌آیند ولی `BAD=0` دارند؛ همه عبور واحد زمان (R-TF-UNIT) یا پل پلتفورم‌اند:

| ماژول | نماد | توضیح |
|---|---|---|
| `TimeframeFunctions` | `GetCurrentTimeframe` (۳۳٪) | MT5: `CompatTF(...)`؛ MT4: مقدار خام دقیقه |
| `LabelFunctions` | `PeriodToString` (۳۱٪) | همان عبور واحد |
| `BuildConfig` | `CompatPeriodMinutes` (۵۰٪) | پین W1=10080 / MN1=43200 (R-TF-UNIT) |
| `PerformanceOptimizations` | `GetCachedPeriod` | lock تایم‌فریم در MT5 (`CompatTimeframeLockActive`) |
| `DynamicTradingDayDetector` | `DetectFetchBarTimes` | `(ENUM_TIMEFRAMES)` ↔ `CompatTF` |
| `HistoricalDataFunctions` | `UpdateHistoricalValues` [P-MT5-01] | خواندن سری‌ها از آینهٔ `Time[]` |
| `InputValidator` | `ValidateInputs` (۰٪ — فقط خط‌بندی) | — |
| `ATRCalculations` | `CalculateWeightedATR`، `ReleaseATRHandle` (+`WeightedATRWasProvisional` extra) | موتور iATR سنکرون MT5 (بخش ۶) |
| `AdaptiveScaling` | `UpdateATRScalingFactor` [P-BE-02] | همان خانواده |
| `BasePriceManager` | `GetSymbolStateIndex` [P-BE-05] | — |
| `ObjectCache` | `DeleteIndicatorObjectManaged` [P-PERF-13] | — |
| `ExtendedDrawingFunctions` | `CreateOrUpdateHLine`، `CleanupSurplusObjects` | — |
| `ZoneRenderer` | `ResolveZoneStyles`، `RenderLines` | [P-PERF-41…] |
| `PathTool` | `PathWitness` | — |
| `THVolNorm` | `THVolNormDrawnV`، `THVolNormColumnV` [P-LBL] | — |
| `HTFCandles` | بلوک، `InitializeHTFCandles`، `HTFProbe*` | ماسک/پروب HTF |

---

## ۵) موارد فقط-MT5 (EXTRA = ۴۷) — دسته‌بندی

### ۵.۱ موتور رندر کانواس و پل RBridge (عامدانه، R-RENDER-ENGINE)
- `Engine/RenderPlatform.mqh`، `Engine/RenderCore.mqh`، `Engine/RenderBridge.mqh` — فقط MT5 (بدون twin در MT4).
- `#define BIOTAK_RENDER_ENGINE` در هر دو entry + include `Engine\RenderBridge.mqh` + `RBridgeInit/Shutdown/Pump`.
- فراخوانی‌های محصول: `LevelPipeline` (ماسک/بیلد/رنگ‌آمیزی زون‌ها، `RBridgeTriggerWalk`)، `TH3Renderer` (`RBridgePatternDropBase`)، `BiotakKit.SetMidZonesVisible` (`RBridgeZoneFamilyMask` + `ScheduleHeavyFrame`).
- خاموش‌کردن = کامنت‌کردن همان یک خط define (مسیر آبجکتی A/B). **هر بازبینی رفتار باید در هر دو حالت انجام شود.**

### ۵.۲ سازگاری/پایداری مخصوص MT5 (عامدانه — نیازمند مراقبت)
- `EventHandlers`: `ConsumeCleanUITeardownStamp`/`StampCleanUITeardown`/`UITearStampName` (پاک‌سازی UI بین attach)، `TailRestoreDeferred`/`AttachToolRestoreLegacy`/`RepaintLabelsForSwitch`/`ResolvePeriodChangeAttach`/`SavePeriodStamp`/`LastPeriodStampName`.
- `HTFCandles`: `SaveHTFHandoffStamp`/`HTFAdoptKeptFamily`/`HTFKeptStampName`.
- `TH3Tool`: `TH3ReadPatternAnchors`/`TH3LiveDragUnlatch`/`TH3LiveDragHeartbeat`.
- `BiotakKit`: `ApplyRefreshFlags`.
- `GlobalVariables`/`PerformanceOptimizations`: `CompatTimeframeLockActive`/`CompatLockedPeriod`.
- این‌ها twin در MT4 ندارند چون ترتیب رویداد/چرخهٔ عمر در MT5 فرق دارد؛ هر پورت مشترک باید آن‌ها را در معادله نگه دارد.

### ۵.۳ تلمتری و پروفایل (هزینه‌دار — کاندید گیت/حذف در ریلیز)
- `g_pInitMs*` (۱۰ شمارنده) در `GlobalVariables` + ثبت در entry (`g_pInitMsStates/Kit/HTF/Menu/Adopt/Tail/Front/…)`.
- `P4LeftoverCensus`/`P4ObjectCensus` در `EventHandlers` + صدا‌زنی در entry (`P4LeftoverCensus("oninit")`).
- `ATRCalculations.WeightedATRWasProvisional`.

### ۵.۴ بازماندهٔ معماری قدیمی MT4 (کاندید حذف هنگامِ پورت تمپلیت)
- `DrawToolbar`: `DRAW_PRESET_BUILTIN/DIR/FILE/MAX` + `DrawPreset, DrawPresetApply, DrawPresetCapture, DrawPresetCaptureAndSave, DrawPresetClear, DrawPresetCount, DrawPresetIsBuiltin, DrawPresetName, DrawPresetPack, DrawPresetPath, DrawPresetSet, DrawPresetUnpack, DrawPresetsInit, DrawPresetsLoad, DrawPresetsSave` — MT4 این معماری را **حذف** کرده است.
- `DrawStrip`: `DrawStripPresetApplyGroup` (معادل MT4: `DrawStripTplApplyGroup`)، `DrawStripDiagClose`.
- look سه‌بعدی فبیو: `FIBPEN_LOOK_3D`، `FIBPEN_STYLE_3D`، `FibPenShwOffPx`، ردیف style نهم — **این‌ها در MT4 وجود ندارند** (شکاف معکوس: MT5 جلوتر است یا MT4 حذف کرده — باید تعیین تکلیف شود).

---

## ۶) لایهٔ سازگاری `MT5Compat/MQL5Compat.mqh` — فهرست کامل شیم‌ها

### ۶.۱ مقادیر و واحدها
| شیم | رفتار |
|---|---|
| `#define Period()` → `CompatPeriodMinutes()` | R-TF-UNIT: Period() در MT5 به «دقیقه» برمی‌گردد (MQL4-meaning) تا ~۶۰ مصرف‌کنندهٔ مشترک درست بمانند؛ W1=10080 / MN1=43200 پین‌شده. |
| `CompatTF()` | تنها عبور مجاز دقیقه↔enum. |
| `#define iBars/iTime/iHigh/iLow/iOpen/iClose` | عبور از `CompatTF`. |
| `iBarShift` (دو overload + `iBarShiftReal`) | فرم «دقیقه» و فرم enum؛ built-in با نام واقعی قابل دسترسی. |
| `PeriodMinutes()` | **بدون مصرف‌کننده (dormant)** — کامنت خودش این را می‌گوید؛ W1/MN1 پین شده تا کسی دوباره گاف واحد را کشف نکند. |
| `TimeHour/Minute/Seconds/Day/Month/Year/DayOfWeek` | معادل `TimeToStruct`. |
| `MarketInfo` | نقشهٔ ۱۹ مود به SymbolInfo*. |
| `Bid`/`Ask`/`Symbol()`/`Digits`/`Point` | شمارشی `CompatBid/Ask` + ماکرو. |
| `WindowPriceMin/Max`, `WindowFirstVisibleBar`, `WindowBarsPerChart`, `ObjectType`, `ObjectSetText`, `DoubleToStr`, `StringGetChar` | معادل‌های مستقیم. |
| `StringTrimLeft/Right` | **شیم معنایی**: MQL4 رشتهٔ trim‌شده برمی‌گرداند، MQL5 تعداد حذف‌شده — اینجا فرم رشته‌ای احیا شده (۸ محل مصرف در BasePriceHistoryManager). |

### ۶.۲ آینهٔ آرایه‌های سری پیش‌فرض (MQL4 emulation)
- `Time[]/Open[]/High[]/Low[]/Close[]/Bars` → آرایه‌های گلوبال؛ نگهداری با `CompatRefreshChartData(knownBars, livClose, livHigh, livLow, livTime, livOpen)`.
- مسیر داغ: اگر بار فقط +۱ شده ⇒ **شیفت O(n) در حافظه** بدون CopyRates؛ وگرنه کپی کل تاریخچه (عمدی: `Bars` به‌عنوان «مقدار» مصرف می‌شود — BaseKnotTool/ZoneFactory/ExtendedDrawingFunctions) + throttle 500ms بعد از موفقیت.
- تیک MT5-ONLY (2026-10-13): `livTime/livOpen` هم روی شیفت bar-new نوشته می‌شوند (باگ off-by-one قبلی).
- ورودی‌ها: مقادیر زنده از `OnCalculate` (بدون کراس کرنل)، `OnTimer/OnInit` می‌گذارند `-1/EMPTY_VALUE` و fallback کرنل می‌شود.

### ۶.۳ موتور ATR (P-ATR-SYNC)
- `iATR` → `iATRMQL4` با memo (۱۰۲۴ اسلات، کلید symbol/tf/period/shift/bar-count) که هر بار کندل عوض شود باطل است؛ مقدار «provisional» هرگز memo نمی‌شود.
- پیاده‌سازی فقط `iATRRatesFallback` (CopyRates + بازگشت Wilder از قدیمی‌ترین بار، پنجره ۳۰۰۰+ یا کل تاریخچه) — **هیچ هندلی ساخته نمی‌شود**؛ `ReleaseATRHandleCache` فقط کش را ریست و لجر را چاپ می‌کند.
- هدف اعلام‌شده: هم‌ارزی MT4 با باقیماندهٔ <1e-5 برای همهٔ پریودهای پروژه (پایین‌تر از کامنت خط ۴۲۴).

### ۶.۴ API آبجکت
- `OBJPROP_TIME1/2`, `OBJPROP_PRICE1/2` → `OBJPROP_TIME/PRICE` + modifier؛ خواندن و نوشتن.
- `OBJPROP_RAY` → `OBJPROP_RAY_RIGHT` (کد مشترک هر بار RAY+RAY_LEFT+RAY_RIGHT را با هم می‌نویسد).
- overloadهای `int prop` برای ObjectGet/SetInteger/String (فرم MQL4).
- `ObjectsTotal` — فرم‌های ۰/۲/۳ آرگومان با عبور کامل (رفع باگ تاریخی که فقط OBJ_HLINE می‌شمرد)، `ObjectName`/`ObjectFind` فرم‌های MQL4.
- `ObjectCreate` (۲ فرم) و `ObjectDelete` و `ObjectsDeleteAll` — همگی توکن ثبت می‌کنند (بخش ۶.۵).

### ۶.۵ فیلتر «طوفان رویداد برنامه‌ای»
- ایجاد/حذف برنامه‌ای در MT4 رویداد `CHARTEVENT_OBJECT_*` تولید نمی‌کند؛ در MT5 می‌کند. این لایه معنای MT4 را برمی‌گرداند:
  - جدول توکن per-name (۱۶۳۸۴ اسلات، ۸ پروب، TTL ۱۰ ثانیه) برای create/delete تک‌شیء.
  - ثبت پیشوند برای sweepها (۶۴ رکورد، TTL ۱۰ ثانیه؛ sweep بی‌پیشوند = wildcard).
  - مصرف در entry: `CompatConsumeObjEvent(id, name)` قبل از هر دیسپچ ⇒ رویداد خودمان drop، رویداد کاربر dispatch.
- `CompatDeinitBegin` ثبت‌ها را در teardown خاموش می‌کند (P-PERF-99).

### ۶.۶ لجر اندازه‌گیری (وضعیت فعلی: **روشن**)
- `#define COMPAT_LEDGER 1` در خط ۲۵ — یعنی شمارنده‌ها + دوتا `GetTickCount` روی مسیرهای داغ (iBarShift/iATR/MarketInfo/Bid/Ask/Refresh) زنده‌اند و در `ReleaseATRHandleCache` (مسیر deinit) یک خط `[MT5-COMPAT] session …` چاپ می‌شود.
- کامنت بالای همین خط می‌گوید برای ریلیز باید «کامنت» باشد (خاموش). **این مورد یک تصمیم باز است: یا آگاهانه در حالت سنجش مانده، یا برای ریلیز خاموش شود.**

---

## ۷) ریسک‌ها و «پیاده‌سازی ناقص / وابستگی بررسی‌نشده»

۱. **پورت تمپلیت، یک پورت زنجیره‌ای است، نه یک فایل:** حذف `DrawPreset*` + افزودن `DrawTpl*` هم‌زمان باید شامل این وابستگی‌ها باشد:
   - `DrawStripMoreBuild/Tap/Paint` (ردیف‌های `DSTRIP_MK_PRESET/SAVE` → `TPLNAV` + ادیتور اسم + ردیف حذف)،
   - `DSTRIP_PICK_*` (`DSTRIP_PICK_DEL_W`، `DrawStripPickTapDel/DelName/DelFaceName`)،
   - `DrawTplBoot()` در مسیر init (`EventHandlers`)،
   - کدگذاری «سطح‌های فبیو» که به خوانندهٔ سطح فبیو در `FibPen` نیاز دارد،
   - و مهاجرت فایل legacy (`DRAW_TPL_LEGACY`).
۲. **look ۳D فبیو فقط در MT5 است** (`P-LOOK-3D`) و در MT4 کوچک‌ترین اثری ندارد؛ ردیف style و رنگ‌بندی استایل‌ها (۸ ↔ ۹) هم همین‌جا فرق دارند. تعیین تکلیف: حذف از MT5 یا پورت به MT4.
۳. **`COMPAT_LEDGER=1`** روی بیلد فعلی: هزینهٔ اندازه‌گیری روی مسیرهای داغ + چاپ deinit. اگر این بیلد ریلیز است، باید خاموش شود (بخش ۶.۶).
۴. **`PeriodMinutes()` کد مرده** است (no caller) — نگه‌داشتنش فقط به‌خاطر پین واحد است؛ هنگام پاک‌سازی کد نادیده گرفته نشود.
۵. **درخت کاری میانی است:** ۷ ماژول جدید untracked وابستگی بیلد شده‌اند —
   `BiotakHomes.mqh` (include در `BiotakMenu`)، `BiotakMenu_Ring.mqh` (include در `BiotakMenu`)،
   `PenStack.mqh` + `BoxPreview.mqh` (include در `DrawToolbar`)، `Sessions_Time/Model/Draw.mqh` (include در هر دو entry).
   به‌علاوهٔ ۲۰ آیکون جدید (`circ_on/off_*`, `eye_on/off`, `scale_on/off`, `sessions_on/off`, `star_on/off`) که در `Files/Icons` untracked هستند.
   **بدون `git add`، یک کلون تازه یا CI نمی‌تواند بیلد کند** (metaeditor از includeهای untracked استفاده می‌کند چون همه در همان دیسک هستند).
۶. **هم‌ارزی hide (mute F) در مسیر موتور:** MT4 در `TH3Renderer` سه گارد مستقیم `IsIndicatorHidden()` دارد؛ MT5 از `RBridgePump(IsIndicatorHidden(), …)` + ماسک استفاده می‌کند. برای خانوادهٔ پترن ABCD، پلن‌های LegMeasure (که WIP گارد گرفت) و زون‌ها این هم‌ارزی باید با تست بصری تأیید شود.
۷. **هم‌ارزی مسیر آبجکتی (engine off):** با کامنت‌کردن `BIOTAK_RENDER_ENGINE`، انتظار داریم `LevelPipeline`/`TH3Renderer` عیناً مثل MT4 رفتار کنند؛ ولی drift فعلی (مثلاً `SweepForeignLadderObjects` ۶۰٪) نشان می‌دهد نسخهٔ آبجکتی MT5 با بهبودهای MT4 (P-LBL-12، P-PERF-55) هم‌راستا نیست. قبل از A/B باید این مسیر بازبینی شود.
۸. **مکانیزم census/teardown فقط در MT5:** اگر از MT5 حذف شوند تا «شبیه MT4» شود، نسبت به ترتیب رویداد MT5 پسرفت می‌شود؛ اگر بمانند، هر پورت آیندهٔ MT4 باید drift آن‌ها را بشناسد (لیست کامل در ۵.۲).
۹. **هم‌ارزی سطوح خارجی/Geometery:** `docs/LEVELS-FOREIGN-GEOMETRY_FA.md` مرجع این‌جاست؛ drift `SweepForeignLadderObjects` دقیقاً همین سطح را لمس می‌کند.
۱۰. **درخت MT4 هم dirty است (۳۵ فایل)** — این گزارش نسبت به همان working tree است؛ بعد از commit شدن هر دو طرف باید دوباره اجرا شود (هر دو ابزار read-only و ارزان‌اند).

---

## ۸) بازتولید

```powershell
# نمای ماژول‌به‌ماژول (GREEN/RED + خطوط بی‌توضیح)
python tools/parity/module-report.py

# نمای نمادبه‌نماد (MISSING/DRIFT/EXTRA + تگ‌های P-*)
python tools/parity/gap-report.py --tags

# فقط یک ماژول
python tools/parity/gap-report.py --only DrawToolbar.mqh --tags

# بیلد هر دو entry (0/0 لازم است)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3.mq5" -ErrorsOnly
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mt5-build.ps1 -Source "Biotak Trigger TH3 Lite.mq5" -ErrorsOnly
```

---
## پیوست الف — خروجی خام gap-report.py --tags (2026-10-18)
```text
  !!  Biotak/ATRCalculations.mqh                 missing=0 drift=2 extra=1
        DRIFT    CalculateWeightedATR                         DRIFT     4 lines,   7% different
        DRIFT    ReleaseATRHandle                             DRIFT     3 lines,  33% different
        EXTRA    WeightedATRWasProvisional                    EXTRA     1 lines
  !!  Biotak/AdaptiveScaling.mqh                 missing=0 drift=1 extra=0
        DRIFT    UpdateATRScalingFactor                       DRIFT     2 lines,   1% different   [P-BE-02]
  OK  Biotak/AlertFunctions.mqh                 
  OK  Biotak/BaseKnotTool.mqh                   
  OK  Biotak/BasePriceHistoryManager.mqh        
  !!  Biotak/BasePriceManager.mqh                missing=0 drift=1 extra=0
        DRIFT    GetSymbolStateIndex                          DRIFT     2 lines,   1% different   [P-BE-05 P-BE-03]
  OK  Biotak/BiotakHomes.mqh                    
  !!  Biotak/BiotakKit.mqh                       missing=0 drift=1 extra=1
        DRIFT    (block)                                      DRIFT    44 lines,  74% different   [P-PERF-06 P-PERF-30 P-PERF-24 P-PERF-40 P-PERF-34]
        EXTRA    ApplyRefreshFlags                            EXTRA    42 lines
  !!  Biotak/BiotakMenu.mqh                      missing=0 drift=7 extra=0
        DRIFT    DeleteMenu                                   DRIFT    26 lines,  72% different
        DRIFT    DeleteLegacyMenuObjects                      DRIFT    18 lines,  75% different   [P-UI-161]
        DRIFT    RingFeatureClick                             DRIFT    12 lines,   7% different   [P-UI-93 P-PERF-41 P-SESS P-UI-40 P-PERF-32 P-PERF-21]
        DRIFT    CircTipDragTo                                DRIFT     5 lines,  15% different   [P-UI-158]
        DRIFT    InitializeUIStates                           DRIFT     4 lines,   6% different   [P-UI-131 P-UI-144 P-PERF-44]
        DRIFT    (block)                                      DRIFT     2 lines,   1% different   [P-UI-147 P-UI-14 P-UI-90 P-UI-92 P-OFF P-UI-71]
        DRIFT    SetHTFVisible                                DRIFT     2 lines,  10% different   [P-PERF-24]
  OK  Biotak/BiotakMenu_Ring.mqh                
  !!  Biotak/BiotakPanels.mqh                    missing=0 drift=2 extra=0
        DRIFT    PnlApplySet                                  DRIFT    37 lines,   6% different   [P-UI-93 P-UI-131 P-PERF-32 P-PERF-21 P-PERF-41 P-PERF-29]
        DRIFT    UISyncDrain                                  DRIFT     1 lines,   6% different
  OK  Biotak/BoxPreview.mqh                     
  !!  Biotak/BuildConfig.mqh                     missing=0 drift=1 extra=0
        DRIFT    CompatPeriodMinutes                          DRIFT     2 lines,  50% different
  !!  Biotak/BuildHash.mqh                       missing=0 drift=3 extra=0
        DRIFT    TH3_SRC_HASH                                 DRIFT     2 lines, 100% different
        DRIFT    TH3_SRC_SHORT                                DRIFT     2 lines, 100% different
        DRIFT    TH3_SRC_FILES                                DRIFT     2 lines, 100% different
  OK  Biotak/CalculationCache.mqh               
  OK  Biotak/CardMetrics.mqh                    
  OK  Biotak/ComboEngine.mqh                    
  OK  Biotak/ConstantsAndEnums.mqh              
  !!  Biotak/DrawStrip.mqh                       missing=15 drift=30 extra=2
        DRIFT    DrawStripGearObjectsPurge                    DRIFT    80 lines,  93% different   [P-DRAW-117 P-DRAW-33 P-DRAW-131]
        DRIFT    DrawStripClose                               DRIFT    37 lines,  44% different   [P-DRAW-64 P-DRAW-66 P-DRAW-33 P-DRAW-134 P-DRAW-29 P-DRAW-31]
        DRIFT    DrawStripOnEvent                             DRIFT    25 lines,   4% different   [P-UI-113 P-DRAGF3 P-DRAW-64 P-UI-130 P-DRAW-74 P-DRAW-128]
        EXTRA    DrawStripPresetApplyGroup                    EXTRA    23 lines
        DRIFT    DrawStripPaint                               DRIFT    21 lines,   3% different   [P-LOG-8 P-DRAW-120 P-DRAW-42 P-DRAW-08 P-LOG-10 P-DRAW-29]
        MISSING  DrawStripTplSavePaint                        MISSING  19 lines
        MISSING  DrawStripTplApplyGroup                       MISSING  17 lines   [P-DRAW-132 P-DRAW-134 P-DRAW-64]
        MISSING  DrawStripTplCommit                           MISSING  16 lines   [P-DRAW-131]
        DRIFT    DrawStripMoreTap                             DRIFT    15 lines,   8% different   [P-DRAW-132 P-UI-131 P-DRAW-25 P-DRAW-131 P-DRAW-64]
        DRIFT    DrawStripGearRowTap                          DRIFT    14 lines,   9% different   [P-DRAW-117 P-DRAW-84 P-DRAW-21 P-DRAW-64 P-UI-132 P-UI-131]
        MISSING  DrawStripTplRowDelete                        MISSING  13 lines   [P-DRAW-132 P-LOG-3]
        DRIFT    DrawStripDiagEmit                            DRIFT    13 lines,  57% different
        MISSING  DrawStripTplSaveHit                          MISSING  11 lines   [P-UI-131]
        MISSING  DrawStripPickTapDel                          MISSING  11 lines   [P-UI-131]
        DRIFT    DrawStripGearPaint                           DRIFT    11 lines,   3% different   [P-DRAW-99 P-DRAW-117 P-DRAW-118 P-DRAW-33 P-DRAW-124 P-DRAW-42]
        MISSING  DrawStripTplSaveSweep                        MISSING  10 lines
        DRIFT    DrawStripMoreBuild                           DRIFT    10 lines,  19% different   [P-DRAW-132 P-DRAW-21 P-DRAW-64]
        DRIFT    DrawStripGearContent                         DRIFT     9 lines,   4% different   [P-DRAW-99 P-DRAW-117 P-DRAW-30 P-DRAW-44 P-DRAW-39 P-DRAW-64]
        DRIFT    DrawStripGearRowTip                          DRIFT     9 lines,  14% different   [P-DRAW-117]
        MISSING  DrawStripTplNameFocus                        MISSING   8 lines
        DRIFT    DrawStripMoreTip                             DRIFT     8 lines,  14% different
        MISSING  DrawStripTplNavText                          MISSING   7 lines
        DRIFT    DrawStripLevelsToggle                        DRIFT     6 lines,  10% different   [P-LVL-SCALE P-DRAW-135 P-LOG-3]
        DRIFT    DrawStripMoreText                            DRIFT     5 lines,  13% different   [P-DRAW-09]
        DRIFT    DrawStripGearRowText                         DRIFT     5 lines,  10% different   [P-DRAW-117]
        DRIFT    DrawStripEditEnd                             DRIFT     5 lines,   4% different   [P-DRAW-118 P-DRAW-100 P-LVL-SCALE P-LVL-TEXT P-UI-131 P-DRAW-25]
        EXTRA    DrawStripDiagClose                           EXTRA     5 lines
        DRIFT    DrawStripGearHit                             DRIFT     4 lines,   3% different   [P-DRAW-103 P-DRAW-36 P-DRAW-85 P-DRAW-117 P-DRAW-84 P-DRAW-48]
        DRIFT    DrawStripLevelsRewrite                       DRIFT     4 lines,  10% different   [P-LVL-TEXT P-DRAW-74 P-LOG-3]
        DRIFT    DrawStripPickTap                             DRIFT     3 lines,   4% different   [P-DRAW-64 P-LOG-3 P-DRAW-48]
        DRIFT    DrawStripPickCount                           DRIFT     2 lines,   9% different   [P-PAL-21 P-LOOK P-DRAW-BODY-UI]
        DRIFT    DrawStripPopRowRes                           DRIFT     2 lines,   5% different   [P-LOOK]
        DRIFT    DrawStripClosePicker                         DRIFT     2 lines,   4% different   [P-PAL-21 P-DRAW-75 P-DRAW-33 P-DRAW-134]
        DRIFT    DrawStripGearClose                           DRIFT     2 lines,   8% different   [P-DRAW-131 P-DRAW-84 P-DRAW-88 P-LVL-TEXT]
        DRIFT    DrawStripGearGroupDigest                     DRIFT     2 lines,   2% different   [P-DRAW-117]
        DRIFT    DrawStripDuplicate                           DRIFT     2 lines,   1% different   [P-DRAW-74 P-DRAW-23 P-LVL-TEXT]
        DRIFT    DrawStripFootTap                             DRIFT     2 lines,   5% different   [P-DRAW-96 P-DRAW-64 P-DRAW-21]
        DRIFT    DrawStripHoldLatch                           DRIFT     2 lines,   5% different   [P-UI-130 P-UI-113 P-UI-115 P-DRAW-04]
        MISSING  DSTRIP_PICK_DEL_W                            MISSING   1 lines   [P-DRAW-134]
        MISSING  DSTRIP_MK_TPLNAV                             MISSING   1 lines   [P-DRAW-132]
  !!  Biotak/DrawToolbar.mqh                     missing=27 drift=10 extra=22
        MISSING  DrawTplLevelsTo                              MISSING  46 lines   [P-DRAW-74]
        DRIFT    FibPenSync                                   DRIFT    45 lines,   6% different   [P-DRAGF3 P-LOOK P-LOOK-RAY2 P-LOOK-ALL P-LOOK-RAY5 P-LOOK-ANCHOR]
        EXTRA    DrawPresetsInit                              EXTRA    42 lines
        MISSING  DrawTplApply                                 MISSING  32 lines   [P-DRAW-135]
        MISSING  DrawTplSeed                                  MISSING  31 lines
        MISSING  DrawTplMigrate                               MISSING  30 lines
        MISSING  DrawTplLevelsOf                              MISSING  25 lines
        MISSING  DrawTplLoad                                  MISSING  25 lines   [P-DRAW-135 P-UI-133]
        MISSING  DrawTplSaveAs                                MISSING  23 lines   [P-DRAW-74 P-DRAW-135]
        MISSING  DrawTplSave                                  MISSING  23 lines   [P-DRAW-135 P-DRAW-09 P-DRAW-INK]
        MISSING  DrawTplBoot                                  MISSING  22 lines
        MISSING  DrawTplDelete                                MISSING  21 lines   [P-DRAW-135]
        EXTRA    DrawPresetsSave                              EXTRA    20 lines
        EXTRA    DrawPresetsLoad                              EXTRA    20 lines
        EXTRA    DrawPresetCapture                            EXTRA    19 lines
        MISSING  DrawTplPut                                   MISSING  18 lines   [P-DRAW-135]
        MISSING  DrawTplSeedOne                               MISSING  15 lines
        EXTRA    DrawPresetApply                              EXTRA    15 lines
        MISSING  DrawLookPackA                                MISSING  13 lines
        EXTRA    DrawPresetSet                                EXTRA    13 lines
        MISSING  DrawLook                                     MISSING  12 lines
        MISSING  DrawLookUnpackA                              MISSING  12 lines
        DRIFT    FibPenDragFollow                             DRIFT    11 lines,   4% different   [P-DRAGF3 P-LOOK-RAY2 P-LOOK-RAY5 P-LOOK-ANCHOR P-DRAW-74]
        EXTRA    DrawPreset                                   EXTRA    10 lines
        EXTRA    DrawPresetUnpack                             EXTRA    10 lines
        EXTRA    DrawPresetClear                              EXTRA    10 lines
        EXTRA    DrawPresetPack                               EXTRA     9 lines
        MISSING  DrawTpl                                      MISSING   8 lines   [P-DRAW-135]
        MISSING  DrawTplIndex                                 MISSING   8 lines
        MISSING  DrawTplCount                                 MISSING   7 lines
        EXTRA    DrawPresetCount                              EXTRA     7 lines
        MISSING  DrawLookPackB                                MISSING   6 lines
        MISSING  DrawLookUnpackB                              MISSING   6 lines
        MISSING  DrawTplName                                  MISSING   6 lines
        EXTRA    DrawPresetName                               EXTRA     6 lines
        EXTRA    DrawPresetCaptureAndSave                     EXTRA     6 lines
        DRIFT    DrawSlotWrite                                DRIFT     4 lines,   1% different   [P-HR-04 P-UI-136 P-UI-137 P-DRAW-48 P-DRAW-BODY P-DRAW-128]
        DRIFT    FibPenPreviewArm                             DRIFT     3 lines,   4% different   [P-DRAGF3 P-DRAW-74]
        DRIFT    FibPenPreviewEnd                             DRIFT     3 lines,   4% different   [P-DRAGF3]
        DRIFT    FillChildEnsure                              DRIFT     2 lines,   2% different   [P-DRAW-64]
  !!  Biotak/DynamicTradingDayDetector.mqh       missing=0 drift=1 extra=0
        DRIFT    DetectFetchBarTimes                          DRIFT     2 lines,   6% different
  OK  Biotak/ErrorCodes.mqh                     
  !!  Biotak/EventHandlers.mqh                   missing=0 drift=11 extra=11
        DRIFT    RedrawAllObjects                             DRIFT    64 lines,   9% different   [P-PERF-02 P-PERF-03 P-PERF-49 P-KEY-01 P-PERF-34 P-UI-98]
        DRIFT    OnInitHandler                                DRIFT    35 lines,   6% different   [P-ARCH-03 P-PERF-38 P-PERF-10 P-BUILD-08 P-UI-134 P-DRAW-89]
        EXTRA    P4ObjectCensus                               EXTRA    22 lines
        EXTRA    P4LeftoverCensus                             EXTRA    21 lines
        EXTRA    RepaintLabelsForSwitch                       EXTRA    16 lines
        EXTRA    AttachToolRestoreLegacy                      EXTRA    15 lines
        DRIFT    OnChartEventHandler                          DRIFT    14 lines,   1% different   [P-UI-114 P-HR-01 P-UI-136 P-UI-100 P-UI-142 P-DRAW-01]
        DRIFT    P4InitLedgerTag                              DRIFT    13 lines,  45% different
        EXTRA    ResolvePeriodChangeAttach                    EXTRA    13 lines
        EXTRA    TailRestoreDeferred                          EXTRA    13 lines
        EXTRA    ConsumeCleanUITeardownStamp                  EXTRA     8 lines
        DRIFT    ResolveTopologyAdoption                      DRIFT     6 lines,  14% different   [P-PERF-38 P-VIEW]
        DRIFT    RunIncrementalObjectCleanup                  DRIFT     6 lines,   6% different   [P-BK-01 P-HR-05]
        DRIFT    SetTriggerLevelsVisible                      DRIFT     5 lines,  15% different   [P-UI-93 P-PERF-21 P-PERF-32 P-KEY-01 P-PERF-24 P-KEY-PROBE]
        DRIFT    DrawLevelsBasedOnMode                        DRIFT     4 lines,   6% different   [P-UI-98]
        DRIFT    OnCalculateHandler                           DRIFT     4 lines,   2% different   [P-UI-98 P-BK-13 P-BK-29 P-BK-92 P-BK-46 P-UI-53]
        EXTRA    SavePeriodStamp                              EXTRA     4 lines
        EXTRA    StampCleanUITeardown                         EXTRA     4 lines
        DRIFT    OnDeinitHandler                              DRIFT     3 lines,   1% different   [P-PERF-49 P-PERF-02 P-TH3-P6 P-BUILD-01 P-BK-02 P-HR-01]
        DRIFT    P4ReportSlow                                 DRIFT     1 lines,   6% different
        EXTRA    LastPeriodStampName                          EXTRA     1 lines
        EXTRA    UITearStampName                              EXTRA     1 lines
  !!  Biotak/ExtendedDrawingFunctions.mqh        missing=0 drift=2 extra=0
        DRIFT    CreateOrUpdateHLine                          DRIFT     9 lines,   9% different
        DRIFT    CleanupSurplusObjects                        DRIFT     6 lines,  17% different
  OK  Biotak/FactorMode.mqh                     
  OK  Biotak/FloatingPointHelper.mqh            
  OK  Biotak/FractalTimeframes.mqh              
  OK  Biotak/FrequencyOptimizer.mqh             
  !!  Biotak/GlobalVariables.mqh                 missing=0 drift=2 extra=2
        DRIFT    (block)                                      DRIFT    11 lines,   5% different   [P-UI-65 P-UI-98 P-LM-21 P-UI-31 P-LM-15 P-UI-149]
        DRIFT    ChartViewRestoreUser                         DRIFT     2 lines,  17% different   [P-UI-114]
        EXTRA    CompatTimeframeLockActive                    EXTRA     1 lines
        EXTRA    CompatLockedPeriod                           EXTRA     1 lines
  OK  Biotak/HRayTool.mqh                       
  !!  Biotak/HTFCandles.mqh                      missing=0 drift=5 extra=3
        DRIFT    DrawHTFCandles                               DRIFT     7 lines,   4% different   [P-HTF-TOP P-PERF-08 P-UI-68 P-HTF-SLOT P-HTF-SYN P-PERF-02]
        EXTRA    HTFAdoptKeptFamily                           EXTRA     7 lines
        EXTRA    SaveHTFHandoffStamp                          EXTRA     5 lines
        DRIFT    (block)                                      DRIFT     2 lines,   2% different   [P-UI-92 P-HTF-PROBE P-HTF P-HTF-SLOT]
        DRIFT    HTFProbeCull                                 DRIFT     2 lines,  12% different   [P-HTF]
        DRIFT    HTFProbeSettings                             DRIFT     2 lines,   7% different   [P-HTF]
        DRIFT    InitializeHTFCandles                         DRIFT     1 lines,   1% different   [P-DRAW-87 P-UI-142 P-UI-92 P-UI-68 P-PERF-08 P-PERF-44]
        EXTRA    HTFKeptStampName                             EXTRA     1 lines
  !!  Biotak/HistoricalDataFunctions.mqh         missing=0 drift=1 extra=0
        DRIFT    UpdateHistoricalValues                       DRIFT     2 lines,   2% different   [P-MT5-01 P-UI-57]
  OK  Biotak/InputValidationEnhanced.mqh        
  !!  Biotak/InputValidator.mqh                  missing=0 drift=1 extra=0
        DRIFT    ValidateInputs                               DRIFT     2 lines,   0% different   [P-UI-57 P-UI-63 P-TH3-PB-MAN]
  !!  Biotak/LabelFunctions.mqh                  missing=0 drift=2 extra=0
        DRIFT    PeriodToString                               DRIFT    10 lines,  31% different
        DRIFT    SetTHLabelsVisibility                        DRIFT     2 lines,   2% different   [P-PERF-02 P-TH-02 P-LBL]
  !!  Biotak/LevelPipeline.mqh                   missing=0 drift=12 extra=0
        DRIFT    SweepForeignLadderObjects                    DRIFT    75 lines,  60% different   [P-LBL-12 P-PERF-55]
        DRIFT    RenderZones                                  DRIFT    41 lines,  27% different   [P-PERF-41 P-PERF-04 P-VIEW-01 P-VIEW-03 P-UI-62 P-PERF-32]
        DRIFT    ExecutePipeline                              DRIFT    32 lines,  11% different   [P-PERF-06 P-PERF-18 P-LEVEL-FOREIGN-01 P-LEVEL-FOREIGN-02 P-UI-153 P-UI-152]
        DRIFT    RenderTriggerLines                           DRIFT    25 lines,  24% different   [P-UI-98 P-UI-66 P-PERF-03 P-BK-15 P-VIEW-01 P-VIEW-03]
        DRIFT    BuildZonesAndLines                           DRIFT    10 lines,   3% different   [P-UI-59 P-UI-57 P-BE-02 P-UI-58 P-UI-62]
        DRIFT    StructureRecolourWalk                        DRIFT     3 lines,   4% different   [P-UI-62 P-UI-131]
        DRIFT    PipelineGeometryKey                          DRIFT     3 lines,   3% different   [P-PERF-21 P-UI-131 P-UI-66 P-PERF-23]
        DRIFT    TriggerFamilyWalk                            DRIFT     3 lines,   6% different   [P-UI-62 P-BK-01]
        DRIFT    LevelSplitCounts                             DRIFT     2 lines,   4% different
        DRIFT    SZoneDefinition                              DRIFT     1 lines,   3% different   [P-UI-62]
        DRIFT    STriggerLine                                 DRIFT     1 lines,   3% different
        DRIFT    CleanupSurplusPipeline                       DRIFT     1 lines,   2% different   [P-UI-98 P-PERF-36 P-PERF-41]
  OK  Biotak/Logger.mqh                         
  OK  Biotak/MarketHoursDetector.mqh            
  OK  Biotak/MathConstants.mqh                  
  OK  Biotak/ModeDefinitions.mqh                
  !!  Biotak/ObjectCache.mqh                     missing=0 drift=1 extra=0
        DRIFT    DeleteIndicatorObjectManaged                 DRIFT     5 lines,  11% different   [P-PERF-13 P-PERF-07 P-UI-62]
  OK  Biotak/ObjectCountManager.mqh             
  OK  Biotak/ObjectFunctions.mqh                
  !!  Biotak/PathTool.mqh                        missing=0 drift=1 extra=0
        DRIFT    PathWitness                                  DRIFT     2 lines,  50% different
  OK  Biotak/PenStack.mqh                       
  !!  Biotak/PerformanceOptimizations.mqh        missing=0 drift=1 extra=2
        DRIFT    GetCachedPeriod                              DRIFT     2 lines,  17% different
        EXTRA    CompatTimeframeLockActive                    EXTRA     1 lines
        EXTRA    CompatLockedPeriod                           EXTRA     1 lines
  OK  Biotak/Profiler.mqh                       
  OK  Biotak/ProjectConstants.mqh               
  OK  Biotak/PropertiesAndInputs.mqh            
  OK  Biotak/PropertyChangeDetector.mqh         
  OK  Biotak/RuntimeSettings.mqh                
  OK  Biotak/Sessions_Draw.mqh                  
  OK  Biotak/Sessions_Model.mqh                 
  OK  Biotak/Sessions_Time.mqh                  
  OK  Biotak/StandardTimeframes.mqh             
  !!  Biotak/TH3Tool.mqh                         missing=0 drift=7 extra=3
        DRIFT    OnABCDMouseEvent                             DRIFT    74 lines,  24% different   [P-TH3-PERF-05 P-TH3-PB-DRAG P-TH3-BAND-PRESS P-TH3-PB-OFF P-TH3-PB-UI P-LM-13]
        DRIFT    (block)                                      DRIFT    51 lines,  55% different   [P-LM-20 P-TH3-PB-LOCK P-TH3-PB-DRAG-LOCK P-BK-03 P-LM-13 P-TH3-BAND-PRESS]
        EXTRA    TH3ReadPatternAnchors                        EXTRA    49 lines
        DRIFT    TH3RestorePatternsFromChart                  DRIFT    23 lines,  26% different   [P-TH3-INFO-06 P-TH3-PB-OFF]
        DRIFT    SetActiveABCDPattern                         DRIFT     8 lines,  11% different   [P-TH3-P6 P-TH3-INFO-01 P-TH3-INFO-04 P-TH3-INFO-10]
        EXTRA    TH3LiveDragUnlatch                           EXTRA     6 lines
        EXTRA    TH3LiveDragHeartbeat                         EXTRA     5 lines
        DRIFT    LegMeasureUpgradeLegacy                      DRIFT     4 lines,   3% different   [P-LM-11 P-LM-09 P-LM-04 P-LM-07]
        DRIFT    TH3_ExportCurrentSample                      DRIFT     4 lines,   1% different   [P-TH3-STEP-16 P-UI-142 P-TH3-DB P-TH3-REC-02 P-TH3-REC-04 P-TH3-REC-06]
        DRIFT    TH3BaseEditorSync                            DRIFT     2 lines,   3% different
  OK  Biotak/THCalculations.mqh                 
  !!  Biotak/THVolNorm.mqh                       missing=0 drift=2 extra=0
        DRIFT    THVolNormDrawnV                              DRIFT     4 lines,   4% different   [P-LBL]
        DRIFT    THVolNormColumnV                             DRIFT     2 lines,   1% different   [P-LBL]
  !!  Biotak/TimeframeFunctions.mqh              missing=0 drift=1 extra=0
        DRIFT    GetCurrentTimeframe                          DRIFT    10 lines,  33% different
  OK  Biotak/TradePlanFormulas.mqh              
  OK  Biotak/UtilityFunctions.mqh               
  OK  Biotak/VisibilityManager.mqh              
  OK  Biotak/WaveAnalysis.mqh                   
  OK  Biotak/ZoneCalculator.mqh                 
  OK  Biotak/ZoneConfig.mqh                     
  OK  Biotak/ZoneConstants.mqh                  
  OK  Biotak/ZoneFactory.mqh                    
  !!  Biotak/ZoneRenderer.mqh                    missing=0 drift=2 extra=0
        DRIFT    ResolveZoneStyles                            DRIFT    12 lines,   9% different
        DRIFT    RenderLines                                  DRIFT     9 lines,   9% different
  OK  Biotak/ZoneValidator.mqh                  
  OK  Biotak/TH3/TH3Controller.mqh              
  OK  Biotak/TH3/TH3Math.mqh                    
  OK  Biotak/TH3/TH3PatternStore.mqh            
  OK  Biotak/TH3/TH3Pivots.mqh                  
  !!  Biotak/TH3/TH3Renderer.mqh                 missing=0 drift=6 extra=0
        DRIFT    DrawABCDPattern                              DRIFT   205 lines,  10% different   [P-UI-160 P-TH3-INFO-01 P-TH3-STEP-16 P-TH3-PB-MAN P-TH3-PB-RET8 P-TH3-STEP-04]
        DRIFT    TH3InfoOrphanPlateSweep                      DRIFT     6 lines,  16% different
        DRIFT    TH3PivotMarkersClear                         DRIFT     6 lines,  50% different
        DRIFT    TH3FamilyAnchorsAlive                        DRIFT     3 lines,  14% different
        DRIFT    TH3InfoCaptionHeal                           DRIFT     1 lines,   2% different   [P-UI-160 P-TH3-INFO-13 P-LM-09 P-TIME-01]
        DRIFT    TH3HitPivotForward                           DRIFT     1 lines,   1% different   [P-UI-160 P-TH3-STEP-08 P-TH3-STEP-09]
  OK  Biotak/TH3/TH3Types.mqh                   
  ?? ENTRY                                      (not on both sides)
  ?? ENTRY-LITE                                 (not on both sides)

TOTAL symbols: MISSING=42 DRIFT=116 EXTRA=47
```

## پیوست ب — خروجی خام module-report.py (2026-10-18)
```text
==============================================================================
MODULE BY MODULE:   MT4 (reference)   vs   MT5
==============================================================================
Biotak/ATRCalculations.mqh             lines mt4=  909 mt5=  914  shared=  908  mt4-only=   1 mt5-only=   6  BAD=  0  sym mt4= 57/mt5= 58  GREEN
Biotak/AdaptiveScaling.mqh             lines mt4=  164 mt5=  166  shared=  164  mt4-only=   0 mt5-only=   2  BAD=  0  sym mt4=  9/mt5=  9  GREEN
Biotak/AlertFunctions.mqh              lines mt4=   72 mt5=   72  shared=   72  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  6/mt5=  6  GREEN
Biotak/BaseKnotTool.mqh                lines mt4= 3600 mt5= 3600  shared= 3600  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=293/mt5=293  GREEN
Biotak/BasePriceHistoryManager.mqh     lines mt4=  682 mt5=  682  shared=  682  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 28/mt5= 28  GREEN
Biotak/BasePriceManager.mqh            lines mt4= 1237 mt5= 1237  shared= 1236  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4= 44/mt5= 44  GREEN
Biotak/BiotakHomes.mqh                 lines mt4=  165 mt5=  165  shared=  165  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 30/mt5= 30  GREEN
Biotak/BiotakKit.mqh                   lines mt4=  238 mt5=  252  shared=  238  mt4-only=   0 mt5-only=  14  BAD= 14  sym mt4= 66/mt5= 67  RED
      MT5-only lines with no declared idiom: 14
        + {
        + {
        + }
        + }
        + int SetMidZonesVisible(const bool on)
        + g_showMidZones = on;
        + RuntimeSettingsSaveOverridesThrottled();
        + if(RBridgeActive())
        + RBridgeZoneFamilyMask(on);
        + if(on && RBridgeZonesStale()) ScheduleHeavyFrame("zone-build");
        + RepaintForDiscreteAction();
        + return REFRESH_NONE;
      MT5-only symbols: ApplyRefreshFlags
Biotak/BiotakMenu.mqh                  lines mt4= 3041 mt5= 3043  shared= 3009  mt4-only=  32 mt5-only=  34  BAD= 32  sym mt4=289/mt5=289  RED
      MT4-only lines with no declared idiom: 18
        - string legacy = "BiotakMenu_" + IntegerToString(ChartID()) + "_";
        - for(int i = 0; i < RING_MAX_SEATS; i++)
        - ObjectDelete(0, legacy + "CircIcon" + IntegerToString(i));
        - ObjectDelete(0, legacy + "CircBg" + IntegerToString(i));
        - ObjectDelete(0, legacy + "CircBadge" + IntegerToString(i));
        - ObjectDelete(0, legacy + "CircBadgeTxt" + IntegerToString(i));
        - for(int t = 0; t < CAT_COUNT; t++)
        - ObjectDelete(0, legacy + "ToolsBg" + IntegerToString(t));
        - ObjectDelete(0, legacy + "ToolsIcon" + IntegerToString(t));
        - ObjectDelete(0, legacy + "ToolsBadge" + IntegerToString(t));
        - ObjectDelete(0, legacy + "ToolsBadgeTxt" + IntegerToString(t));
        - g_redrawTHLevelsNeeded = true;
      MT5-only lines with no declared idiom: 14
        + ObjectsDeleteAll(0, "BiotakMenu_" + IntegerToString(ChartID()) + "_");
        + const bool uiFamiliesClean = ConsumeCleanUITeardownStamp();
        + if(!uiFamiliesClean)
        + static uint s_TipLastRedrawTick = 0;
        + CircReassertLock();
        + uint now = GetTickCount();
        + if(now - s_TipLastRedrawTick < CIRC_DRAG_REDRAW_INTERVAL) return;
        + s_TipLastRedrawTick = now;
        + ChartRedraw();
        + refreshFlags = REFRESH_NONE;
        + refreshFlags = REFRESH_NONE;
        + refreshFlags = SetMidZonesVisible(wantOn);
Biotak/BiotakMenu_Ring.mqh             lines mt4=  231 mt5=  231  shared=  231  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 35/mt5= 35  GREEN
Biotak/BiotakPanels.mqh                lines mt4= 7184 mt5= 7196  shared= 7171  mt4-only=  13 mt5-only=  25  BAD= 38  sym mt4=458/mt5=458  RED
      MT4-only lines with no declared idiom: 13
        - if(row==0) { g_showMidZones=(v>0.5);
        - flags=REFRESH_BUFFERS; }
        - flags=REFRESH_BUFFERS; }
        - flags=REFRESH_BUFFERS; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL; }
        - g_labelsRelayoutNeeded=true; flags=REFRESH_ALL;
      MT5-only lines with no declared idiom: 25
        + flags=REFRESH_NONE; }
        + flags=REFRESH_NONE; }
        + flags=REFRESH_NONE; }
        + if(row==0) {
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
        + RequestUISync();
Biotak/BoxPreview.mqh                  lines mt4=   67 mt5=   67  shared=   67  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  5/mt5=  5  GREEN
Biotak/BuildConfig.mqh                 lines mt4=  133 mt5=  133  shared=  132  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4= 33/mt5= 33  GREEN
Biotak/BuildHash.mqh                   lines mt4=    3 mt5=    3  shared=    0  mt4-only=   3 mt5-only=   3  BAD=  0  sym mt4=  4/mt5=  4  GREEN
Biotak/CalculationCache.mqh            lines mt4=  279 mt5=  279  shared=  279  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 30/mt5= 30  GREEN
Biotak/CardMetrics.mqh                 lines mt4=   83 mt5=   83  shared=   83  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 80/mt5= 80  GREEN
Biotak/ComboEngine.mqh                 lines mt4=  343 mt5=  343  shared=  343  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 21/mt5= 21  GREEN
Biotak/ConstantsAndEnums.mqh           lines mt4=  672 mt5=  672  shared=  672  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=208/mt5=208  GREEN
Biotak/DrawStrip.mqh                   lines mt4= 6369 mt5= 6088  shared= 6024  mt4-only= 345 mt5-only=  64  BAD=235  sym mt4=513/mt5=500  RED
      MT4-only lines with no declared idiom: 192
        - static int s_dsTplPage[DK_COUNT];
        - return true;
        - return true;
        - if(ObjectFind(0, nm) < 0) return;
        - if(!s_dsOpen || s_dsObj == "") return false;
        - if(mx >= ex && mx < ex + ew && my >= ey && my < ey + DSTRIP_GEAR_EDIT_H)
        - if(DrawStripTplSaveHit(e, mx, ex, ew)) return true;
        - if(slot == DRAW_SLOT_STYLE) return ((k == DK_FIBO || k == DK_FIBOFAN) ? 8 : 5);
        - ChartRedraw();
        - ChartRedraw();
        - ChartRedraw();
        - string DrawStripTplNavText(const EDrawKind k)
      MT5-only lines with no declared idiom: 43
        + if(mx >= ex && mx < ex + ew &&
        + my >= ey && my < ey + DSTRIP_GEAR_EDIT_H)
        + if(st == FIBPEN_STYLE_3D) return "3D";
        + if(slot == DRAW_SLOT_STYLE) return ((k == DK_FIBO || k == DK_FIBOFAN) ? 9 : 5);
        + if(row == FIBPEN_STYLE_3D && (k == DK_FIBO || k == DK_FIBOFAN)) return "3D";
        + for(int i = 0; i < DRAW_PRESET_MAX && r < DSTRIP_PICK_MAX; i++)
        + { if(DrawPresetName(k, i) == "") continue; s_dsMoreKind[r] = DSTRIP_MK_PRESET; s_dsMoreArg[r] = i; r++; 
        + if(kind == DSTRIP_MK_PRESET) return DrawPresetName(s_dsKind, arg);
        + if(kind == DSTRIP_MK_SAVE) return "Save current look";
        + return "Template: " + DrawPresetName(s_dsKind, arg) +
        + return "Template: " + DrawPresetName(s_dsKind, arg) +
        + (DrawPresetIsBuiltin(arg) ? " (built-in)" : " (mine)") +
      MT4-only symbols: DSTRIP_MK_TPLNAV, DSTRIP_PICK_DEL_W, DrawStripPickDelFaceName, DrawStripPickDelName, DrawStripPickTapDel, DrawStripTplApplyGroup, DrawStripTplCommit, DrawStripTplNameFocus, DrawStripTplNavText, DrawStripTplRowDelete, DrawStripTplSaveHit, DrawStripTplSaveName
      MT5-only symbols: DrawStripPresetApplyGroup
Biotak/DrawToolbar.mqh                 lines mt4= 2813 mt5= 2673  shared= 2491  mt4-only= 322 mt5-only= 182  BAD=487  sym mt4=222/mt5=217  RED
      MT4-only lines with no declared idiom: 315
        - {
        - {
        - {
        - {
        - {
        - {
        - {
        - {
        - {
        - {
        - {
        - {
      MT5-only lines with no declared idiom: 172
        + return true;
        + if(k == DK_NONE) return false;
        + if(name == "" || ObjectFind(0, name) < 0) return false;
        + if(lk < FIBPEN_LOOK_NEON || lk > FIBPEN_LOOK_3D) return 0;
        + if(lk < FIBPEN_LOOK_NEON || lk > FIBPEN_LOOK_3D) return;
        + int FibPenShwOffPx(const int w) { return ((w > 0 ? w : 1) / 2) + 1; }
        + string sn = FibPenShwName(fibo, l);
        + string sn = FibPenShwName(fibo, l);
        + if(ObjectFind(0, sn) >= 0 && (int)ObjectGetInteger(0, sn, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS)
        + { ObjectSetInteger(0, sn, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); nH++; }
        + if(ObjectFind(0, sn) >= 0 && (int)ObjectGetInteger(0, sn, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS)
        + { ObjectSetInteger(0, sn, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); nU++; }
      MT4-only symbols: DRAW_TPL_FILE, DRAW_TPL_LEGACY, DRAW_TPL_LVL_ROW, DRAW_TPL_MAX, DRAW_TPL_PAGE, DrawLook, DrawLookPackA, DrawLookPackB, DrawLookUnpackA, DrawLookUnpackB, DrawTpl, DrawTplApply
      MT5-only symbols: DRAW_PRESET_BUILTIN, DRAW_PRESET_DIR, DRAW_PRESET_FILE, DRAW_PRESET_MAX, DrawPreset, DrawPresetApply, DrawPresetCapture, DrawPresetCaptureAndSave, DrawPresetClear, DrawPresetCount, DrawPresetIsBuiltin, DrawPresetName
Biotak/DynamicTradingDayDetector.mqh   lines mt4=  137 mt5=  137  shared=  136  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4=  7/mt5=  7  GREEN
Biotak/ErrorCodes.mqh                  lines mt4=   55 mt5=   55  shared=   55  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 24/mt5= 24  GREEN
Biotak/EventHandlers.mqh               lines mt4= 3534 mt5= 3712  shared= 3497  mt4-only=  37 mt5-only= 215  BAD=103  sym mt4=128/mt5=139  RED
      MT4-only lines with no declared idiom: 7
        - ThrottledChartRedraw();
        - ThrottledChartRedraw();
        - string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStr;
        - DrawTplBoot();
        - " atr=" + IntegerToString((int)g_pInitMsAtr) + "]";
        - g_labelsRelayoutNeeded = true;
        - RedrawLabelsOnly();
      MT5-only lines with no declared idiom: 96
        + else
        + else
        + string nm = ObjectName(0, i, -1, -1);
        + uint _adoptT = GetTickCount();
        + g_pInitMsAdopt += GetTickCount() - _adoptT;
        + uint _adoptT2 = GetTickCount();
        + g_pInitMsAdopt += GetTickCount() - _adoptT2;
        + string names = "";
        + if(nm == "") continue;
        + names += nm;
        + uint pFrontTick = GetTickCount();
        + g_pInitMsFront = GetTickCount() - pFrontTick;
      MT5-only symbols: AttachToolRestoreLegacy, ConsumeCleanUITeardownStamp, P4LeftoverCensus, P4ObjectCensus, RepaintLabelsForSwitch, StampCleanUITeardown, TailRestoreDeferred, UITearStampName
Biotak/ExtendedDrawingFunctions.mqh    lines mt4= 1270 mt5= 1285  shared= 1270  mt4-only=   0 mt5-only=  15  BAD=  0  sym mt4= 41/mt5= 41  GREEN
Biotak/FactorMode.mqh                  lines mt4=  101 mt5=  101  shared=  101  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  7/mt5=  7  GREEN
Biotak/FloatingPointHelper.mqh         lines mt4=  148 mt5=  148  shared=  148  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 30/mt5= 30  GREEN
Biotak/FractalTimeframes.mqh           lines mt4=  192 mt5=  192  shared=  192  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 18/mt5= 18  GREEN
Biotak/FrequencyOptimizer.mqh          lines mt4=  671 mt5=  671  shared=  671  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 21/mt5= 21  GREEN
Biotak/GlobalVariables.mqh             lines mt4=  671 mt5=  685  shared=  669  mt4-only=   2 mt5-only=  16  BAD= 11  sym mt4= 74/mt5= 76  RED
      MT5-only lines with no declared idiom: 11
        + static uint g_pInitMsStates = 0;
        + static uint g_pInitMsKit = 0;
        + static uint g_pInitMsHTF = 0;
        + static uint g_pInitMsMenu = 0;
        + static uint g_pInitMsAdopt = 0;
        + static uint g_pInitMsTail = 0;
        + static uint g_pInitMsFront = 0;
        + static uint g_pInitMsTailLeg = 0;
        + static uint g_pInitMsTailTh3 = 0;
        + static uint g_pInitMsInk = 0;
        + static bool g_attachTailPending = false;
Biotak/HRayTool.mqh                    lines mt4=  473 mt5=  473  shared=  473  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 40/mt5= 40  GREEN
Biotak/HTFCandles.mqh                  lines mt4= 1048 mt5= 1071  shared= 1045  mt4-only=   3 mt5-only=  26  BAD= 23  sym mt4= 88/mt5= 91  RED
      MT5-only lines with no declared idiom: 23
        + {
        + {
        + {
        + }
        + }
        + }
        + if(g_HTFDrawnCount > 0)
        + string HTFKeptStampName() { return "Biotak_HTFKept_" + GetCachedChartIdStr(); }
        + const int HTF_KEPT_NONE = -1;
        + static int s_HTFKeptCount = HTF_KEPT_NONE;
        + void SaveHTFHandoffStamp()
        + GlobalVariableSet(HTFKeptStampName(), (double)g_HTFDrawnCount);
      MT5-only symbols: HTFAdoptKeptFamily, HTFKeptStampName, SaveHTFHandoffStamp
Biotak/HistoricalDataFunctions.mqh     lines mt4=   99 mt5=   99  shared=   98  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/InputValidationEnhanced.mqh     lines mt4=  167 mt5=  167  shared=  167  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  9/mt5=  9  GREEN
Biotak/InputValidator.mqh              lines mt4=  311 mt5=  311  shared=  310  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/LabelFunctions.mqh              lines mt4= 1476 mt5= 1476  shared= 1470  mt4-only=   6 mt5-only=   6  BAD=  0  sym mt4= 59/mt5= 59  GREEN
Biotak/LevelPipeline.mqh               lines mt4= 1221 mt5= 1281  shared= 1154  mt4-only=  67 mt5-only= 127  BAD= 66  sym mt4= 47/mt5= 47  RED
      MT4-only lines with no declared idiom: 27
        - if(!config.zonesEnabled) { HideAllZoneFamilyObjects(); return; }
        - const bool makeLines,
        - int removed = 0;
        - if(!(vpTop > vpBottom) || vpBottom <= 0) return 0;
        - if(lineCount <= 0) return 0;
        - string produced[];
        - ArrayResize(produced, lineCount + zoneCount);
        - produced[pc++] = lines[l].name;
        - produced[pc++] = zones[z].name;
        - const string fam = config.objectPrefix + config.modeName + "_";
        - const bool producedSet = LadderSetBuild(produced, pc);
        - for(int i = total - 1; i >= 0; i--)
      MT5-only lines with no declared idiom: 39
        + if(!config.zonesEnabled)
        + if(RBridgeActive()) { RBridgeZoneFamilyMask(false); RBridgeZonesMarkStale(); return; }
        + HideAllZoneFamilyObjects(); return;
        + if(RBridgeActive())
        + if(RBridgeActive())
        + RBridgeZoneFamilyMask(true);
        + RBridgeZonesBegin();
        + double rbPxPerPrice = 0.0;
        + int rbH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
        + double rbPmax = ChartGetDouble(0, CHART_PRICE_MAX);
        + double rbPmin = ChartGetDouble(0, CHART_PRICE_MIN);
        + if(rbH > 0 && rbPmax > 0 && rbPmin > 0 && rbPmax > rbPmin)
Biotak/Logger.mqh                      lines mt4=  236 mt5=  236  shared=  235  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4= 55/mt5= 55  GREEN
Biotak/MarketHoursDetector.mqh         lines mt4=   89 mt5=   89  shared=   89  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  6/mt5=  6  GREEN
Biotak/MathConstants.mqh               lines mt4=    2 mt5=    2  shared=    2  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/ModeDefinitions.mqh             lines mt4=  152 mt5=  152  shared=  152  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  8/mt5=  8  GREEN
Biotak/ObjectCache.mqh                 lines mt4=  527 mt5=  530  shared=  526  mt4-only=   1 mt5-only=   4  BAD=  0  sym mt4= 43/mt5= 43  GREEN
Biotak/ObjectCountManager.mqh          lines mt4=  175 mt5=  175  shared=  175  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 11/mt5= 11  GREEN
Biotak/ObjectFunctions.mqh             lines mt4=   72 mt5=   72  shared=   72  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/PathTool.mqh                    lines mt4=  887 mt5=  887  shared=  886  mt4-only=   1 mt5-only=   1  BAD=  0  sym mt4= 73/mt5= 73  GREEN
Biotak/PenStack.mqh                    lines mt4=  537 mt5=  537  shared=  537  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 26/mt5= 26  GREEN
Biotak/PerformanceOptimizations.mqh    lines mt4=  329 mt5=  331  shared=  328  mt4-only=   1 mt5-only=   3  BAD=  0  sym mt4= 37/mt5= 39  GREEN
Biotak/Profiler.mqh                    lines mt4=   78 mt5=   78  shared=   78  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 11/mt5= 11  GREEN
Biotak/ProjectConstants.mqh            lines mt4=  126 mt5=  126  shared=  126  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 18/mt5= 18  GREEN
Biotak/PropertiesAndInputs.mqh         lines mt4=  286 mt5=  286  shared=  286  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/PropertyChangeDetector.mqh      lines mt4=   77 mt5=   77  shared=   77  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 11/mt5= 11  GREEN
Biotak/RuntimeSettings.mqh             lines mt4= 1223 mt5= 1223  shared= 1223  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=173/mt5=173  GREEN
Biotak/Sessions_Draw.mqh               lines mt4=  507 mt5=  507  shared=  507  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 26/mt5= 26  GREEN
Biotak/Sessions_Model.mqh              lines mt4=  238 mt5=  238  shared=  238  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 31/mt5= 31  GREEN
Biotak/Sessions_Time.mqh               lines mt4=  271 mt5=  271  shared=  271  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 36/mt5= 36  GREEN
Biotak/StandardTimeframes.mqh          lines mt4=   25 mt5=   25  shared=   25  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  2/mt5=  2  GREEN
Biotak/TH3Tool.mqh                     lines mt4= 2960 mt5= 3039  shared= 2930  mt4-only=  30 mt5-only= 109  BAD=136  sym mt4=176/mt5=179  RED
      MT4-only lines with no declared idiom: 29
        - datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
        - double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
        - datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
        - double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
        - datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
        - double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
        - if(ObjectFind(0, base + "_Line_AB") < 0) { TH3InfoFamilyDelete(base); continue; }
        - if(ObjectFind(0, base + "_Line_BC") < 0) { TH3InfoFamilyDelete(base); continue; }
        - datetime tA = (datetime)ObjectGetInteger(0, base + "_Line_AB", OBJPROP_TIME, 0);
        - double pA = ObjectGetDouble(0, base + "_Line_AB", OBJPROP_PRICE, 0);
        - datetime tB = (datetime)ObjectGetInteger(0, base + "_Line_AB", OBJPROP_TIME, 1);
        - double pB = ObjectGetDouble(0, base + "_Line_AB", OBJPROP_PRICE, 1);
      MT5-only lines with no declared idiom: 107
        + {
        + {
        + {
        + {
        + {
        + }
        + }
        + }
        + }
        + }
        + }
        + }
      MT5-only symbols: TH3LiveDragHeartbeat, TH3LiveDragUnlatch, TH3ReadPatternAnchors
Biotak/THCalculations.mqh              lines mt4=  170 mt5=  170  shared=  170  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 17/mt5= 17  GREEN
Biotak/THVolNorm.mqh                   lines mt4=  326 mt5=  326  shared=  323  mt4-only=   3 mt5-only=   3  BAD=  0  sym mt4= 32/mt5= 32  GREEN
Biotak/TimeframeFunctions.mqh          lines mt4=   52 mt5=   52  shared=   47  mt4-only=   5 mt5-only=   5  BAD=  0  sym mt4=  4/mt5=  4  GREEN
Biotak/TradePlanFormulas.mqh           lines mt4=  256 mt5=  256  shared=  256  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 41/mt5= 41  GREEN
Biotak/UtilityFunctions.mqh            lines mt4=  732 mt5=  732  shared=  732  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 62/mt5= 62  GREEN
Biotak/VisibilityManager.mqh           lines mt4=  337 mt5=  337  shared=  337  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 23/mt5= 23  GREEN
Biotak/WaveAnalysis.mqh                lines mt4=  268 mt5=  268  shared=  268  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 16/mt5= 16  GREEN
Biotak/ZoneCalculator.mqh              lines mt4=  219 mt5=  219  shared=  219  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  4/mt5=  4  GREEN
Biotak/ZoneConfig.mqh                  lines mt4=   36 mt5=   36  shared=   36  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  3/mt5=  3  GREEN
Biotak/ZoneConstants.mqh               lines mt4=   93 mt5=   93  shared=   93  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 15/mt5= 15  GREEN
Biotak/ZoneFactory.mqh                 lines mt4=  366 mt5=  366  shared=  366  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 13/mt5= 13  GREEN
Biotak/ZoneRenderer.mqh                lines mt4=  197 mt5=  196  shared=  192  mt4-only=   5 mt5-only=   4  BAD=  0  sym mt4=  7/mt5=  7  GREEN
Biotak/ZoneValidator.mqh               lines mt4=  138 mt5=  138  shared=  138  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  7/mt5=  7  GREEN
Biotak/TH3/TH3Controller.mqh           lines mt4=  233 mt5=  233  shared=  233  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 29/mt5= 29  GREEN
Biotak/TH3/TH3Math.mqh                 lines mt4=  651 mt5=  651  shared=  651  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 42/mt5= 42  GREEN
Biotak/TH3/TH3PatternStore.mqh         lines mt4=   70 mt5=   70  shared=   70  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4=  9/mt5=  9  GREEN
Biotak/TH3/TH3Pivots.mqh               lines mt4= 1226 mt5= 1226  shared= 1226  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 84/mt5= 84  GREEN
Biotak/TH3/TH3Renderer.mqh             lines mt4= 1549 mt5= 1683  shared= 1530  mt4-only=  19 mt5-only= 153  BAD=109  sym mt4= 55/mt5= 55  RED
      MT4-only lines with no declared idiom: 4
        - if(IsIndicatorHidden()) return;
        - if(IsIndicatorHidden()) return;
        - if(IsIndicatorHidden()) return;
        - bool isActive = (g_activeABCDPattern == mainObjName);
      MT5-only lines with no declared idiom: 105
        + if(RBridgeActive()) return true;
        + bool rbr = false;
        + rbr = RBridgeActive();
        + const bool patActive = (g_activeABCDPattern == mainObjName);
        + if(rbr) RBridgePatternDropBase(mainObjName);
        + if(rbr)
        + if(rbr)
        + if(rbr)
        + if(rbr)
        + if(rbr)
        + if(rbr)
        + if(rbr)
Biotak/TH3/TH3Types.mqh                lines mt4=   71 mt5=   71  shared=   71  mt4-only=   0 mt5-only=   0  BAD=  0  sym mt4= 13/mt5= 13  GREEN
ENTRY                                  lines mt4=  126 mt5=  164  shared=  125  mt4-only=   1 mt5-only=  39  BAD= 22  sym mt4=  6/mt5=  7  RED
      includes MT5 has, MT4 lacks: renderbridge.mqh
      MT4-only lines with no declared idiom: 1
        - "ms handler=", (int)p15Handler, "ms | ovr w=", RSSaveWrites(), "/",
      MT5-only lines with no declared idiom: 21
        + P4LeftoverCensus("oninit");
        + uint p4q = GetTickCount();
        + g_pInitMsStates = GetTickCount() - p4q; p4q = GetTickCount();
        + g_pInitMsKit = GetTickCount() - p4q; p4q = GetTickCount();
        + g_pInitMsHTF = GetTickCount() - p4q; p4q = GetTickCount();
        + g_pInitMsMenu = GetTickCount() - p4q;
        + RBridgeInit();
        + RBridgeShutdown();
        + const bool p116keep = (reason == REASON_CHARTCHANGE);
        + if(!p116keep)
        + if(!p116keep)
        + else
      MT5-only symbols: BIOTAK_RENDER_ENGINE
ENTRY-LITE                             lines mt4=   59 mt5=   84  shared=   59  mt4-only=   0 mt5-only=  25  BAD=  8  sym mt4=  7/mt5=  8  RED
      includes MT5 has, MT4 lacks: renderbridge.mqh
      MT5-only lines with no declared idiom: 8
        + P4LeftoverCensus("oninit");
        + RBridgeInit();
        + RBridgeShutdown();
        + if(reason == REASON_REMOVE) P4LeftoverCensus("remove");
        + if(id == CHARTEVENT_CHART_CHANGE || id == CHARTEVENT_KEYDOWN || id == CHARTEVENT_OBJECT_CLICK)
        + RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones);
        + RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones);
        + TailRestoreDeferred();
      MT5-only symbols: BIOTAK_RENDER_ENGINE
==============================================================================
SUMMARY
==============================================================================
UNJUSTIFIED one-sided lines: 15 modules affected
  !! Biotak/BiotakKit.mqh                    14 bad lines   (mt4-only 0, mt5-only 14)
      symbols: mt4 - | mt5 (block), ApplyRefreshFlags, ClampInt, NativeStyleFromIdx, RefreshDisplay, UIDragBudgetBegin
  !! Biotak/BiotakMenu.mqh                   32 bad lines   (mt4-only 18, mt5-only 14)
      symbols: mt4 DeleteLegacyMenuObjects, CreateToolsMenu, DeleteRing, DeleteMenu, RingFeatureClick, FeaturePanel | mt5 CircTipDragTo, CircHandleMouseMove, DeleteMenu, RingFeatureClick, InitializeUIStates, SetHTFVisible
  !! Biotak/BiotakPanels.mqh                 38 bad lines   (mt4-only 13, mt5-only 25)
      symbols: mt4 PnlApplySet | mt5 PnlApplySet, PnlCloseAll, PnlOpen, PnlSkinButtonAct, UIRebuildForMetrics, UISyncDrain
  !! Biotak/DrawStrip.mqh                   235 bad lines   (mt4-only 192, mt5-only 43)
      symbols: mt4 DrawStripLevelsToggle, DrawStripOnEvent, DrawStripPickTap, DrawStripMoreBuild, DrawStripGearObjectsPurge, DrawStripTplCommit | mt5 DrawStripGearHit, DrawStripMoreTap, DrawStripGearRowTap, DrawStripClose, DrawStripPresetApplyGroup, DrawStripGearRowTip
  !! Biotak/DrawToolbar.mqh                 487 bad lines   (mt4-only 315, mt5-only 172)
      symbols: mt4 DrawTplLoad, DrawTplApply, DRAW_TPL_MAX, DrawTplIndex, DrawTplDelete, DrawTplSeed | mt5 FibPenSync, DrawPresetsInit, FibPenPreviewArm, DrawPresetCapture, FibPenLookSet, DrawPresetSet
  !! Biotak/EventHandlers.mqh               103 bad lines   (mt4-only 7, mt5-only 96)
      symbols: mt4 ResolveTopologyAdoption, P4InitLedgerTag, DrawLevelsBasedOnMode, OnInitHandler, OnChartEventHandler, RedrawAllObjects | mt5 DrawLevelsBasedOnMode, OnInitHandler, RepaintLabelsForSwitch, RedrawAllObjects, ResolvePeriodChangeAttach, TailRestoreDeferred
  !! Biotak/GlobalVariables.mqh              11 bad lines   (mt4-only 0, mt5-only 11)
      symbols: mt4 - | mt5 (block), ChartViewRestoreUser, CompatLockedPeriod, CompatTimeframeLockActive
  !! Biotak/HTFCandles.mqh                   23 bad lines   (mt4-only 0, mt5-only 23)
      symbols: mt4 (block), HTFProbeSettings, HTFProbeCull | mt5 DrawHTFCandles, HTFAdoptKeptFamily, InitializeHTFCandles, (block), HTFRefreshBlendBackground, HTFBlendBackgroundColor
  !! Biotak/LevelPipeline.mqh                66 bad lines   (mt4-only 27, mt5-only 39)
      symbols: mt4 ExecutePipeline, ClassifyLevels, ClassifyLevelsAlternating, BuildZonesAndLines, RenderZones, RenderTriggerLines | mt5 ExecutePipeline, SweepForeignLadderObjects, RenderTriggerLines, RenderZones, Step1HandleOwnFace, CleanupSurplusPipeline
  !! Biotak/TH3Tool.mqh                     136 bad lines   (mt4-only 29, mt5-only 107)
      symbols: mt4 TH3RestorePatternsFromChart, OnABCDMouseEvent, AutoSelectBestFrequency, TH3BaseEditorSync | mt5 OnABCDMouseEvent, TH3ReadPatternAnchors, TH3LiveDragUnlatch, TH3RestorePatternsFromChart, TH3BaseEditorSync, LegMeasureUpgradeLegacy
  !! Biotak/TH3/TH3Renderer.mqh             109 bad lines   (mt4-only 4, mt5-only 105)
      symbols: mt4 TH3InfoOrphanPlateSweep, TH3PivotMarkersClear, DrawABCDPattern, TH3InfoCaptionHeal, TH3HitPivotForward | mt5 DrawABCDPattern, TH3InfoOrphanPlateSweep, TH3FamilyAnchorsAlive, TH3LogFileAppend, TH3AvgCandleSize, TH3ROPlateH
  !! ENTRY                                   22 bad lines   (mt4-only 1, mt5-only 21)
      symbols: mt4 OnDeinit | mt5 OnDeinit, OnCalculate, OnInit, OnTimer, OnChartEvent
  !! ENTRY                                   22 bad lines   (mt4-only 1, mt5-only 21)
      symbols: mt4 OnDeinit | mt5 OnDeinit, OnCalculate, OnInit, OnTimer, OnChartEvent
  !! ENTRY-LITE                               8 bad lines   (mt4-only 0, mt5-only 8)
      symbols: mt4 - | mt5 OnCalculate, OnInit, OnDeinit, OnTimer, OnChartEvent
  !! ENTRY-LITE                               8 bad lines   (mt4-only 0, mt5-only 8)
      symbols: mt4 - | mt5 OnCalculate, OnInit, OnDeinit, OnTimer, OnChartEvent

MT4-ONLY SYMBOLS (lost logic): 2
   - Biotak/DrawStrip.mqh :: DSTRIP_MK_TPLNAV, DSTRIP_PICK_DEL_W, DrawStripPickDelFaceName, DrawStripPickDelName, DrawStripPickTapDel, DrawStripTplApplyGroup, DrawStripTplCommit, DrawStripTplNameFocus, DrawStripTplNavText, DrawStripTplRowDelete, DrawStripTplSaveHit, DrawStripTplSaveName, DrawStripTplSavePaint, DrawStripTplSaveSweep, DrawStripTplSaveW
   - Biotak/DrawToolbar.mqh :: DRAW_TPL_FILE, DRAW_TPL_LEGACY, DRAW_TPL_LVL_ROW, DRAW_TPL_MAX, DRAW_TPL_PAGE, DrawLook, DrawLookPackA, DrawLookPackB, DrawLookUnpackA, DrawLookUnpackB, DrawTpl, DrawTplApply, DrawTplBoot, DrawTplCount, DrawTplDelete, DrawTplIndex, DrawTplLevelsOf, DrawTplLevelsTo, DrawTplLoad, DrawTplMigrate, DrawTplName, DrawTplPath, DrawTplPut, DrawTplSave, DrawTplSaveAs, DrawTplSeed, DrawTplSeedOne

MT5-ONLY SYMBOLS (extras to remove): 8
   + Biotak/BiotakKit.mqh               ApplyRefreshFlags
   + Biotak/DrawStrip.mqh               DrawStripPresetApplyGroup
   + Biotak/DrawToolbar.mqh             DRAW_PRESET_BUILTIN, DRAW_PRESET_DIR, DRAW_PRESET_FILE, DRAW_PRESET_MAX, DrawPreset, DrawPresetApply, DrawPresetCapture, DrawPresetCaptureAndSave, DrawPresetClear, DrawPresetCount, DrawPresetIsBuiltin, DrawPresetName, DrawPresetPack, DrawPresetPath, DrawPresetSet, DrawPresetUnpack, DrawPresetsInit, DrawPresetsLoad, DrawPresetsSave, FIBPEN_LOOK_3D, FIBPEN_STYLE_3D, FibPenShwOffPx
   + Biotak/EventHandlers.mqh           AttachToolRestoreLegacy, ConsumeCleanUITeardownStamp, P4LeftoverCensus, P4ObjectCensus, RepaintLabelsForSwitch, StampCleanUITeardown, TailRestoreDeferred, UITearStampName
   + Biotak/HTFCandles.mqh              HTFAdoptKeptFamily, HTFKeptStampName, SaveHTFHandoffStamp
   + Biotak/TH3Tool.mqh                 TH3LiveDragHeartbeat, TH3LiveDragUnlatch, TH3ReadPatternAnchors
   + ENTRY                              BIOTAK_RENDER_ENGINE
   + ENTRY-LITE                         BIOTAK_RENDER_ENGINE

MT5-ONLY MODULE FILES (extras left in the build): 0
MT5 platform layer (declared, required by MQL5): MT5Compat/MQL5Compat.mqh

==============================================================================
DO THE NUMBERS MATCH?  modules that draw / compute what the user sees
==============================================================================
  Biotak/ATRCalculations.mqh           mt4-only lines=   1 mt5-only lines=   6 BAD=  0   -> GREEN
  Biotak/AdaptiveScaling.mqh           mt4-only lines=   0 mt5-only lines=   2 BAD=  0   -> GREEN
  Biotak/BasePriceManager.mqh          mt4-only lines=   1 mt5-only lines=   1 BAD=  0   -> GREEN
  Biotak/ComboEngine.mqh               mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/FractalTimeframes.mqh         mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/LabelFunctions.mqh            mt4-only lines=   6 mt5-only lines=   6 BAD=  0   -> GREEN
  Biotak/LevelPipeline.mqh             mt4-only lines=  67 mt5-only lines= 127 BAD= 66   -> RED
  Biotak/THCalculations.mqh            mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/TradePlanFormulas.mqh         mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/ZoneCalculator.mqh            mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/ZoneFactory.mqh               mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/ZoneRenderer.mqh              mt4-only lines=   5 mt5-only lines=   4 BAD=  0   -> GREEN
  Biotak/ZoneValidator.mqh             mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/TH3/TH3Math.mqh               mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/TH3/TH3Pivots.mqh             mt4-only lines=   0 mt5-only lines=   0 BAD=  0   -> GREEN
  Biotak/TH3/TH3Renderer.mqh           mt4-only lines=  19 mt5-only lines= 153 BAD=109   -> RED

VERDICT: 13 RED, 0 YELLOW, 64 GREEN, 0 MT5-only files   ->  WORK REMAINS
```
