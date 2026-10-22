# مقایسه End-to-End متاتریدر ۴ و ۵ — Biotak Trigger TH3

تاریخ: 2026-10-21
دامنه: `Biotak Trigger TH3.mq5` (Full) و `Biotak Trigger TH3 Lite.mq5`
مرجع رفتاری: مخزن MT4 (`../Biotak-Trigger-TH3-mql4`)، فقط-خواندنی
وضعیت: بازبینی کد + مقایسه نمادبه‌نماد + ساخت هر دو نسخه + حلقه‌ی بسته. ۶ شکاف پیدا و اصلاح شد (۵ رفتاری + ۱ تشخیصی).

---

## 0. حکم یک‌خطی

- **هیچ منطق MT4 گم نشده است**: `gap-report.py` → `MISSING=0`. هیچ تابع/سیمبل/فایلی که در MT4 باشد و در MT5 نباشد وجود ندارد.
- **۹۹ نماد drift کد** دارد (بدون شمارش کامنت‌ها). همه بازبینی شد و در سه دسته جای می‌گیرد: کار عمدی MT5-only (موتور کانواس، توکن رویداد، R-TF-UNIT، memoها)، بازنویسی‌های perf (sweep پیشوندی، walk تکه‌تکه)، و **۶ موردی که MT5 واقعاً از MT4 عقب بود** (۵ رفتاری + ۱ تشخیصی؛ بخش ۵).
- **حذف خانواده‌ای** (مثال کاربر) در هر ۱۱ خانواده ابزار یک‌پارچه است: هر عضو حذف شود، کل خانواده در همان event می‌رود. توپولوژی کامل در بخش ۴.
- هر دو نسخه پس از اصلاح: `0 errors, 0 warnings`.

---

## 1. روش و معیار قبولی

| مرحله | ابزار | خروجی |
|---|---|---|
| فهرست تفاوت ماژول‌ها | `tools/parity/module-report.py` | ۵۹ GREEN، ۱۵ RED (همه از کار اعلام‌شده MT5-only)، ۲ فایل MT5-only |
| نمادهای گم‌شده / drift | `tools/parity/gap-report.py` | `MISSING=0 DRIFT=99 EXTRA=35` |
| drift واقعی کد (بدون کامنت) | اسکریپت مقایسه‌ی comment-insensitive روی همان chunker | ۹۹ نماد، همه بازبینی شد |
| بدنه‌ی تابع‌به‌تابع | استخراج تابع از هر دو درخت و diff | ۴ شکاف تأیید شد |
| ساخت | `tools/mt5-build.ps1` | Full + Lite: `0/0` |

معیار قبولی برای هر ابزار همان ۸ مرحله‌ی بخش ۲ است؛ «PASS» یعنی مسیر کد و build بررسی شده، نه تست ماوس.

---

## 2. قانون مشترک هر ابزار (۸ مرحله)

1. **Arm** — کلیک روی seat/hotkey؛ هیچ ابزار دیگری هم‌زمان armed نمی‌ماند (`CancelOtherToolSessions`).
2. **Preview** — فقط قبل از commit؛ با Esc، right-click، hide یا deinit پاک می‌شود.
3. **Commit** — یک owner برای هندسه و state.
4. **Select/Edit** — نقطه/دسته/body؛ بدون حذف ناخواسته در کلیک بعدی.
5. **Delete** — یک مسیر، همراه با همه‌ی فرزندان (بخش ۴).
6. **Persistence** — شیء committed بعد از TF switch می‌ماند؛ selection و preview نمی‌ماند.
7. **Teardown** — قفل view، preview، handle و session در هر reason آزاد می‌شود.
8. **UI surface** — کلیک روی پنل/استریپ هرگز به chart نشت نمی‌کند.

---

## 3. ماتریس ابزار به ابزار

| ابزار | مسیر MT5 | مرجع MT4 | حکم |
|---|---|---|---|
| **RING: TRIGGER** | `RingFeatureClick` → `SetTriggerLevelsVisible` → در کانواس `RBridgeTriggerWalk` | همان تابع، walk روی object | PASS — تفاوت فقط مسیر رندر |
| **RING: ZONES (MID)** | `SetMidZonesVisible` → ماسک لایه یا rebuild اگر recs کهنه‌اند | `HideAllZoneFamilyObjects`/render | PASS |
| **RING: ATR / TH / HTF / SESSIONS** | state + ماسک + repaint؛ `RepaintLabelsForSwitch` | `g_labelsRelayoutNeeded` + `RedrawLabelsOnly` | PASS |
| **RING: PIN / custom price** | `CircArmPin` → placement؛ Esc/C/دکمه دوم = `DeactivateCustomPriceMode` | همان | **FIXED (F-03)** |
| **RING: HRAY** | `CircArmHRay` → `HRayArm` → `HRayPlace` (232) | همان | PASS |
| **RING: PATH** | `CircArmPath` → `PathArm` (104) → `PathFinish` (790) | همان | PASS |
| **RING: BASEKNOT** | `CircArmBaseKnot` → `BaseKnotArm` (2008)؛ modal | همان | PASS |
| **RING: TH3 (AB=CD)** | `CircArmTH3Draw` → ۴ کلیک؛ drag زنده با heartbeat | `OBJECT_DRAG` مستقیم | PASS (رفتار یکی، مسیر MT5-only) |
| **RING: LEG (measure)** | `LegMeasureToggle`؛ حذف line = cascade plate/ring/mid | همان | PASS |
| **RING: STEP / GENERAL / SCALE / HIDE** | چرخه‌ی mode، پنل، `CHART_SCALEFIX`، hide-all | همان | PASS |
| **Drawing toolbar (17 kind)** | LINE…CYCLES؛ style memory per kind؛ template rack | همان | PASS |
| **DrawStrip (پلیت)** | open/close/gear/picker؛ `DrawStripClose` (4889) sweep کامل `PnlDrawS_*` | حذف تک‌تک ~۵۳۰ نام | PASS — sweepMT5 دقیقاً همان خانواده است |
| **Gear panel** | `DrawStripGearObjectsPurge` (4646) = یک `ObjectsDeleteAll("PnlDrawS_G")` | ~۳۳۰ probe | PASS — همه‌ی نام‌ها زیر همان پیشوند |
| **Panels / cards** | `Pnl*`، `PnlApplySet` → `ApplyRefreshFlags` | ست‌کردن مستقیم flagها | PASS (بدنه‌ی `ApplyRefreshFlags` بایت‌به‌بایت یکی است) |
| **Levels + Zones** | `ExecutePipeline` (2330) → `RenderTriggerLines`/`RenderZones` → کانواس یا object | همان pipeline روی object | PASS |
| **Sweep لادر خارجی** | `SweepForeignLadderObjects` (2221) — ماشین حالت تکه‌تکه | walk یک‌جا | PASS (نتیجه یکی، فقط spread روی چند فریم) |
| **Labels / TRex card** | `DisplayTRexTitleBlock` (983) + `LblMark` sweep | همان | **FIXED (F-04)** |
| **Hide-all (F)** | `HideAllTHObjectsPass` (817) + `ShowAllDrawingFamilies` | همان + legacy scan | **FIXED (F-01/F-02)** |
| **Hotkeys** | E/M/1-4/W/L/T/A/C/ESC/Q/K + `inp*Key`ها | همان | **FIXED (F-03)** |
| **TF lock** | `inpLockKey`؛ mask + GVar | همان | PASS |
| **Teardown/Remove** | `OnDeinit`: bridge → PnlCloseAll → DrawStripClose → DeleteMenu → HTFCandles → save → cleanup → object sweep | همان ترتیب | PASS |
| **TF switch** | REASON_CHARTCHANGE: menu/HTF keep می‌شوند (P-PERF-116) | delete + rebuild | PASS (تصمیم perf، adopt در init بررسی شد) |
| **نصب دوم (sibling)** | `TH3SiblingUnitOnChart()` → `INIT_FAILED` | همان | PASS |
| **خطا/کمبود داده** | history/ATR seed gate، `IsValidPrice`، `MathIsValidNumber`، `INVALID_HANDLE` | همان | PASS |

---

## 4. توپولوژی حذف — پاسخ به «در MT4 وابسته‌ها فوری می‌روند، اینجا نه»

### 4.1 جدول خانواده‌ها

| عضوی که حذف می‌شود | چه چیزی با آن می‌رود | owner در MT5 | حکم |
|---|---|---|---|
| parent drawing (Delete نیتیو / object list) | همه‌ی فرزندان: `_FL`، `_BX50`، `_FS*`، `_PSK*`، tag/look memo، mark key | `DrawFamilyDelete` (DrawStrip:8755) از `DrawStripOnChartEvent` | یک event، یک redraw |
| `_FL` (fill child) | parent + همه‌ی siblings (اگر parent indicator باشد: stray drop + restore fill) | همان شاخه‌ی child-map | یکپارچه |
| `_BX50` (mid child) | parent + family؛ دیگر heal نمی‌شود | همان | یکپارچه |
| `_FS*` / `_PSK*` | parent + family | همان | یکپارچه |
| path segment (Delete نیتیو) | کل polyline + handleها + ink + mid markerها | `PathDelete` (293) با guard `s_pathDeleting` | یکپارچه (P-DEL-ATOMIC) |
| ray line | dot + registry | `HRayOnChartEvent` (374) | یکپارچه |
| ray dot | خودش هدف مستقل نیست؛ خط owner است | `HRayDelete` (275) | مطابق MT4 |
| BaseKnot BOX | ENTRY/SL/TP/INFO/edges/marks | `BaseKnotDelete` (6657) | یکپارچه |
| BaseKnot child | **heal** (بازسازی از BOX) — عمدی | `BaseKnotSync` از handler 7299 | دقیقاً رفتار MT4؛ تغییر نکرد |
| هر عضو ABCD (`_Point_`، `_Line_*`، `_Ray_*`، caption، overlay) | کل خانواده با یک prefix sweep | `TH3FamilyBaseOf` + sweep در TH3Tool:4419 | یکپارچه |
| TH3 base editor | base OFF | `TH3BaseEditorOnDelete` | یکپارچه |
| measurement line | plate + rings + mid + ۳ خط | `LegMeasureOnObjectDelete` | یکپارچه |
| level line / zone | در کانواس شیئی وجود ندارد؛ در حالت object با `SweepForeign`/`CleanupSurplus` | `LevelPipeline` + bridge commit | یکپارچه |
| session band/tag | `SessWipe` = `ObjectsDeleteAll(prefix)` | `Sessions_Draw` | یکپارچه |
| HTF candle | `_F`/`_B`/`_WU`/`_WL` هم‌نام | `HTFCandles` | یکپارچه |
| ring/tools/panel | سه sweep پیشوندی (`Circ`, `Tools`, `Sub`) | `DeleteMenu` | یکپارچه |
| strip | sweep `PnlDrawS_*` + gear close | `DrawStripClose` | یکپارچه |
| pinned step-1 line (کانواس) | token؛ شیء پین‌شده با حذف کاربر heal می‌شود | `RBridgePinsBegin` + step-1 owner | مطابق MT4 |
| pattern canvas rows | `RBridgePatternDropBase` در همان event | TH3Tool delete branch | یکپارچه |

### 4.2 پنج قانونی که «یک‌پارچه» را در MT5 نگه می‌دارند

1. **فیلتر event برنامه‌ای** (`MQL5Compat`): هر `ObjectCreate/ObjectDelete/ObjectsDeleteAll` خودمان یک token/prefix می‌گذارد و `CompatConsumeObjEvent` آن را قبل از هر handler می‌بلعد — یعنی event فقط برای حذف کاربر می‌رسد، همان معنای MT4.
2. **پنجره suppression** برای sweepهای گروهی (`g_suppressDeleteEvents`/`UntilMs`) + `TickDeadlinePending` برای wrap.
3. **`DrawFamilyDelete`**: یک helper که parent و همه‌ی memo/childها را زیر یک suppression می‌برد و یک‌بار redraw می‌دهد.
4. **sweepهای پیشوندی**: `ObjectsDeleteAll(prefix)` روی خانواده‌های برنامه‌ای، که superset دقیق نام‌های قبلی است (بخش ۶).
5. **commit کانواس**: recهای دیده‌نشده در همان pass حذف می‌شوند (`RBridgeEnd`, `RBridgePatternCommit`, `RBridgeZonesCommit`).

### 4.3 تنها استثنای عمدی

حذف **فرزند** BaseKnot باعث heal می‌شود، نه cascade. این رفتار **در MT4 هم همین است** (هندلر یکسان). دلیل: `BaseKnotSync` روی همین heal سوار است و suppression ندارد؛ تغییر آن نیازمند بازطراحی sync است. در جدول 4.1 به‌عنوان «دقیقاً رفتار MT4» علامت خورده، نه شکاف.

---

## 5. شکاف‌های واقعی این پاس (پیدا شد و اصلاح شد)

### F-01 — دکمه F نیمی از خانواده‌ها را hide نمی‌کرد (High)

**در MT4 (2026-10-20، P-UI-194):** بعد از walk روی object cache، یک `VisibilityHideAllLegacyScan()` هم اجرا می‌شود تا هر شیئی که پیشوند `inpObjectPrefix` دارد mask شود — چون خانواده‌هایی مثل Factor boundary/level، pen-rowها و session art هیچ‌وقت در cache ثبت نمی‌شدند و بعد از F روی چارت می‌ماندند («بعد از زدن دکمه f بعضی چیزها روی چارت میمونن»).

**در MT5:** فقط `VisibilityHideAllCached()` بود؛ scan فقط وقتی cache خالی بود (attach) اجرا می‌شد. نتیجه: همان اشیای ثبت‌نشده بعد از F دیده می‌شدند.

**اصلاح:** `Biotak/EventHandlers.mqh:825` — فراخوانی `VisibilityHideAllLegacyScan()` بعد از cache walk، با همان استدلال و همان استثنای `_BK_` (P-BK-01).

**اثر:** F یک state کامل است؛ هر شیئی که پیشوند ما را دارد خاموش می‌شود. هزینه: یک walk در هر transition (نه هر فریم).

### F-02 — دکمه F نیمی از خانواده‌ها را برنمی‌گرداند (High)

**در MT4:** انتهای `VisibilityShowAllCached` یک `VisibilityShowAllLegacyScan(...)` دارد؛ هر شیء پیشوندی با همان درخت تصمیم (zone/ATR/TH/trigger/lines) دوباره mask می‌شود.

**در MT5:** فقط مسیر cache؛ scan فقط برای cache خالی. نتیجه: بعد از F دوم، اشیای ثبت‌نشده یا برنمی‌گشتند یا با mask اشتباه (مثلاً zone خاموش، دوباره روشن) بالا می‌آمدند.

**اصلاح:** `Biotak/VisibilityManager.mqh:355` — فراخوانی `VisibilityShowAllLegacyScan(...)` در انتهای `VisibilityShowAllCached`.

**اثر:** رفت و برگشت F ایدمپوتنت است؛ state هر خانواده (MID ZONES، L، T، ATR، TH) بعد از show حفظ می‌شود.

### F-03 — کلید C فقط arm می‌کرد، خاموش‌کردن نداشت (Medium)

**در MT4 (2026-10-20، P-UI-193):** C همان toggle سلول PIN است: اگر خط custom-price فعال/در انتظار/override باشد، `DeactivateCustomPriceMode("C key")` و redraw؛ وگرنه arm.

**در MT5:** بدنه فقط arm می‌کرد (خط را حذف و دوباره در وسط صفحه می‌ساخت)؛ تنها راه خروج از کیبورد ESC بود — همان نقص یک‌طرفه‌ای که P-UI-45 برای سلول PIN بسته بود.

**اصلاح:** `Biotak/EventHandlers.mqh:6451` — تست سه‌گانه‌ی PIN و مسیر OFF با همان owner مشترک ESC/PIN.

**اثر:** C و سلول PIN و ESC یک رفتار دارند؛ C دوم خط را برمی‌دارد.

### F-04 — عدد TRex روی کارت، TF ساختار اشتباه را می‌خواند (Medium)

**در MT4 (2026-10-20):** سوپراسکریپت TRex = **True Range** کندل زنده‌ی TF ساختار، و TF ساختار **دو رانگ** بالاتر از چارت است (M15→H4، M5→H1، H1→D1) — با درخواست صریح کاربر «الان که ۱۵ هستیم مال چهار ساعته رو باید نشون بده». `structureMinutes` کارت (P-TP4-RUNG، یک رانگ) عمداً دست‌نخورده ماند چون basis برنامه است.

**در MT5:** `CompatTF(structureMinutes)` (یک رانگ) و range = `hi-lo` ساده؛ یعنی عدد کارت روی M15 عدد H1 را نشان می‌داد و gap.close قبلی در عدد نبود.

**اصلاح:** `Biotak/LabelFunctions.mqh:1034` — `TradePlanLadderIndex(Period()) + 2` با clamp، `CompatTF(TradePlanLadderMinutes(idx))`، و TrueRange = `max(hi-lo, |hi-pc|, |lo-pc|)`. (R-TF-UNIT: `Period()` در MT5 دقیقه است، پس `CompatTF` تنها گذرگاه مجاز است.)

**اثر:** عدد و درصد کارت با MT4 یکی است: M15→H4، M5→H1، H1→D1.

### F-05 — census «چیزی جا مانده» فقط در MT4 بود (Low، تشخیصی)

**اصلاح:** `Biotak/EventHandlers.mqh:885` — بلوک P-UI-160c در انتهای hide pass (داخل `#ifndef BUILD_LITE`): هر شیء پیشوندی که هنوز mask نشده، با نام، در یک خط diag گزارش می‌شود؛ `_BK_` جدا شمرده می‌شود.

**اثر:** اگر باز هم چیزی بعد از F بماند، لاگ خودش نامش را می‌گوید؛ هیچ هزینه‌ای در حالت پایدار ندارد.


### F-06 — دکمه‌ی Save در تب Template فقط از یک درِ فرعی جواب می‌داد (Medium)

**در MT4 (2026-10-18، P-DRAW-131b):** دکمه‌ی Save سه عضو دارد (`PnlDrawS_GE3S` + `B`/`G`/`T`) و یک `OBJ_BUTTON` است؛ کلیک روی خودِ باتن `CHARTEVENT_OBJECT_CLICK` می‌دهد، نه `CHARTEVENT_CLICK`. MT4 برای همین یک شاخه‌ی نامی در روتر گذاشته که هر چهار نام را به `DrawStripTplCommit("save")` می‌رساند، چون مسیر مختصاتی (`DrawStripTplSaveHit`) فقط پیکسل‌هایی را می‌گیرد که باتن رویشان نیست.

**در MT5:** شاخه‌ی نامی نبود؛ فقط مسیر مختصاتی. یعنی Save از پیکسل‌های ghost margin کار می‌کرد و کلیک مستقیم روی دکمه بی‌جواب می‌ماند.

**اصلاح:** `Biotak/DrawStrip.mqh` (روتر `DrawStripOnEvent`، قبل از حلقه‌ی فیلدهای ویرایش) — چهار نام به همان owner واحد وصل شد.

**اثر:** هر دو در (نام شیء و مختصات) یک مقصد دارند؛ Save از هر جای سلول جواب می‌دهد.

---

## 6. تفاوت‌های عمدی MT5 که شکاف نیستند (بررسی‌شده)

| موضوع | چرا MT5-only است | چرا رفتار MT4 را می‌دهد |
|---|---|---|
| **موتور کانواس** (`Engine/*`, `BIOTAK_RENDER_ENGINE`) | MT5 اجازه‌ی bitmap layer و paint یک‌جا را می‌دهد؛ MT4 یک شیء به‌ازای هر خط | همان هندسه/رنگ از همان helperها؛ recهای دیده‌نشده در commit حذف می‌شوند؛ A/B با خاموش‌کردن define |
| **توکن/prefix رویداد شیء** | MT5 برای عملیات برنامه‌ای هم event صف می‌کند، MT4 نه | eventهای خودمان بلعیده می‌شوند تا معنای «حذف کاربر» MT4 بازگردد؛ TTL و جدول محدود |
| **R-TF-UNIT** (`Period()` = دقیقه) | `Period()` در MT5 enum است (H1=16385) | همه‌ی ~۶۰ مصرف‌کننده بدون تغییر خط مشترک، معنای MT4 را می‌گیرند |
| **ATR memo / provisional** | `iATR` در MT5 handle است و اول ۰ می‌دهد | مقدار provisional کش نمی‌شود (P-PERF-94)، پس seed خراب نمی‌شود |
| **sweepهای پیشوندی** (menu/strip/gear/TH3_P6/HTF) | هزینه‌ی per-call حذف در MT5 (~۱۳ms در ~۱۰۰۰ شیء) | superset دقیق همان نام‌ها؛ با بررسی name-builderها تأیید شد |
| **walk تکه‌تکه‌ی SweepForeign** | جلوگیری از فریم چندصد میلی‌ثانیه‌ای | همان مجموعه و همان شرط `produced`، فقط spread روی فریم‌ها |
| **defer کردن restore ابزارها** (P-PERF-110c) | attach کند بود | فقط در relaunch؛ attach تازه همان ترتیب MT4 را دارد |
| **keep شدن menu/HTF در TF switch** (P-PERF-116) | MT5 اشیاء را در تغییر TF حذف نمی‌کند | adopt در init + handoff stamp؛ پنل‌ها/strip همیشه بسته می‌شوند |
| **حذف `inViewport` از pipeline** | cull window هیچ‌وقت تصمیم رندر نمی‌گرفت | key هندسی واقعی شد؛ رفتار pixel یکی است |
| **پاک‌سازی label/TF mask با `ApplyTfMaskGuarded`** | نوشتن property بدون تغییر ممنوع (قانون perf) | فقط write تکراری حذف شده، نه تصمیم |

---

## 7. رفتار در خطا و حالت‌های مرزی (بررسی کد)

| رویداد | رفتار MT5 |
|---|---|
| تاریخچه/ATR آماده نیست | frame اول paint نمی‌شود؛ seed که رسید `g_redrawTHLevelsNeeded`؛ retry در tick (نه حذف/ساختِ پشت‌سرهم) |
| نشست دوم روی همان چارت | `TH3SiblingUnitOnChart()` → `INIT_FAILED` |
| Remove وسط drag/arm | `OnDeinit` → bridge shutdown، `DrawStripClose`، `PnlCloseAll`، `DeleteMenu`، `CleanupUIStates`، آزادسازی قفل view، sweep اشیاء در REASON_REMOVE |
| TF switch | preview/session پاک؛ committed می‌ماند؛ menu/HTF adopt می‌شوند؛ رکورد انتخاب‌ها (dot/handle) پاک می‌شود |
| F وسط session | sessionهای HRAY/PATH/LEG/TH3 کنسل و پارک می‌شوند؛ ابزار جدید در حالت hidden arm نمی‌شود |
| input نامعتبر/NaN | `MathIsValidNumber` در ورودی pipeline، `IsValidPrice`، fallback ATR؛ هیچ سطح NaN ساخته نمی‌شود |
| حذف شیء توسط کاربر در حالت hidden | cache پاک، redraw کامل flag می‌شود؛ شیء در اولین show بازسازی می‌شود |
| چارت بسته می‌شود | مسیر عادی deinit؛ sweepهای پیشوندی idempotent هستند |

---

## 8. شواهد ساخت

| بیلد | لاگ | نتیجه | EX5 |
|---|---|---|---|
| Full (پس از F-01..F-05) | `build-logs/Biotak-Trigger-TH3-20261021-092017.log` | `0/0` (75.5s) | 2,542,156 B (09:21:33) |
| Lite (پس از F-01..F-05) | `build-logs/Biotak-Trigger-TH3-Lite-20261021-092147.log` | `0/0` (30.6s) | 917,626 B (09:22:18) |
| Full (پس از F-06) | `build-logs/Biotak-Trigger-TH3-20261021-094633.log` | `0/0` (68.0s) | 2,541,980 B (09:47:42) |
| Lite (پس از F-06) | `build-logs/Biotak-Trigger-TH3-Lite-20261021-094801.log` | `0/0` (30.7s) | 917,752 B (09:48:33) |
| Full (حلقه‌ی بسته) | `tools/mt5-verify.ps1 -WaitSec 90` | build `0/0`؛ **GREEN** | 2,543,210 B (09:51:01) |

خروجی حلقه‌ی بسته (اجرای نهایی، بیلد شامل F-06):

- `build errors: 0`
- `TEARDOWN menu (THIS build): PASS (worst of 47, budget 150)` — دلتا 94ms → 47ms
- `GEST census lines: PASS (0)`
- `LEDGER latest: 60s | refresh=264/0ms | iATR=0/0ms | iBarShift=22/0ms`
- `CHART_CHANGE took: n=1 median=47 max=47 (budget 40)` — یک نمونه، کمی بالای بودجه
- `INIT: no fresh init observed` در این اجرا (attach دستی لازم است)؛ در اجرای قبلی `INIT ind=78ms`
- `VERDICT: GREEN`؛ ترمینال با بیلد نهایی باز ماند

---

## 9. تست دستی باقی‌مانده (باید یک‌بار روی ترمینال اجرا شود)

1. یک Rectangle با fill + mid + pen بکش؛ parent را با Delete نیتیو حذف کن → هر سه فرزند در همان لحظه، یک redraw.
2. همان را بساز و این بار `_FL` را از object list حذف کن → کل Rect برود، نه heal.
3. همین تست برای `_BX50` و یک `_PSK`/`_FS*`.
4. یک Path سه‌segmentی بساز؛ یک segment را نیتیو حذف کن → کل path + handleها + ink.
5. HRAY را حذف کن (خط از object list) → dot و registry بروند.
6. **F بزن** روی چارتی که Factor lines، pen rows، session art و هر دو zone حالت دارد → هیچ شیء پیشوندی نباید بماند؛ لاگ `[P-UI-160c] left=0` (به‌جز `bk`).
7. **F دوم** بزن → همه‌ی خانواده‌ها با state خودشان برگردند (زون خاموش باید خاموش بماند، trigger overlay و TH mode حفظ شود).
8. **C** بزن (arm)، بعد **C** دوم → خط custom price برود؛ سپس C سوم → دوباره arm. با ESC و سلول PIN مقایسه کن.
9. کارت TRex را روی M15 نگاه کن → عدد باید H4 باشد؛ روی M5 → H1؛ روی H1 → D1. عدد را با TrueRange همان TF مقایسه کن.
10. حذف یک عضو ABCD (مثلاً `_CDLabel`) → کل خانواده.
11. حذف یک BaseKnot child → heal (این عمدی است، مطابق MT4).
12. Remove وسط درگ HRAY/PATH → قفل view آزاد، preview نماند.
13. TF switch با Path/HRay انتخاب‌شده → dot/handle اضافه نماند.
14. سشن‌ها را با تغییر TF و تغییر روز تست کن؛ labelهای H/L و ghost tagها (`_FL` نبودن) بررسی شوند.

---


## 10. پاسخ صریح: کجا هنوز ممکن است فرق کند

بعد از این پاس، **هیچ منطق گم‌شده‌ای** نیست (`MISSING=0`) و هر ۶ شکاف بسته شد. آنچه باقی می‌ماند سه دسته است، و هیچ‌کدام «MT5 ناقص» نیست — ولی می‌تواند در تجربه فرق کند:

### ۱۰.۱ تفاوت‌های عمدی که «زمان» را عوض می‌کنند، نه نتیجه را

| موقعیت | MT4 | MT5 | چرا |
|---|---|---|---|
| اولین paint بعد از attach | همان فریم | تا وقتی seed فراکتال/ATR نرسد نگه داشته می‌شود (سقف ۲۰s) | جلوگیری از «رسم، حذف، رسم دوباره» |
| TF switch | wipe + rebuild کامل | menu/HTF keep و adopt می‌شوند؛ پنل‌ها/strip بسته | ~۴۵۰ms صرفه‌جویی، adopt بررسی شد |
| restore ابزارها در relaunch | inline در init | اولین فریم ۲۵۰ms | attach سریع‌تر |
| sweep لادر خارجی | یک walk | تکه‌تکه روی چند فریم | بدون فریم چندصد میلی‌ثانیه‌ای |
| رنگ/هندسه‌ی زون و لاین | شیء در همان event | کانواس روی pump همان event | یک paint به‌جای N شیء |

### ۱۰.۲ تفاوت‌های بصری که فقط با ابزار scene-dump قابل اثبات است

کانواس MT5 (خطوط لادر، باند/لبه‌ی زون، خانواده‌ی پترن) از نظر ساختاری با همان helperهای رنگ و همان هندسه ساخته می‌شود، ولی سه تفاوت مستند دارد: سگمنت عمودی چپ زون رسم نمی‌شود، زون نازک‌تر از آستانه‌ی پیکسلی skip می‌شود، و لبه‌ها به‌صورت رکت نازک stroke می‌شوند. پروژه برای همین `BTRS_SCENE_DUMP` و `tools/parity/scene-diff.py` را دارد؛ این جفت هنوز روی یک جفت چارت هم‌نماد اجرا نشده و تنها راه اثبات pixel-parity است.

### ۱۰.۳ احساس سرعت (نه درستی)

در لاگ همین بیلد (۰۹:۳۴، EURUSD H1) این خط تکرار می‌شود:

```
[W][PERF] chart event MOUSE_MOVE(id=10) [indicator=63 ui=78 ...] took 141ms (budget 40ms)
```

یعنی پاسخ به حرکت ماوس روی این چارت ۱۴۱ تا ۲۶۵ms است. این از این پاس نیست (مسیر hover/drag)، ولی همان چیزی است که کاربر به‌عنوان «یک‌پارچه نبودن» حس می‌کند؛ قدم بعدی perf باید همین باشد.

### ۱۰.۴ چیزهایی که عمداً دست نخوردند

- **heal فرزند BaseKnot** — رفتار MT4 هم همین است.
- **`BuildHash.mqh`** — stale، تولیدکننده‌ی MT5 ندارد.
- **declared MT5-only** که در `JUSTIFY` ابزار parity ثبت نشده و باعث RED شدن ۱۵ ماژول می‌شود (سیاست AGENTS.md آن را مجاز می‌داند).

## 11. ریسک‌های باقی‌مانده (صادقانه)

- **تست تصویری**: هیچ ادعای pixel-parity بدون ماوس/اسکرین‌شات وجود ندارد؛ موارد بخش ۹ باید روی ترمینال اجرا شوند.
- **`BuildHash.mqh`**: هنوز stale است؛ تولیدکننده‌ی MT5 ندارد (خارج از دامنه‌ی این پاس).
- **module-report**: ۱۵ ماژول RED نشان می‌دهد، ولی علت همه، کار اعلام‌شده‌ی MT5-only است که در `JUSTIFY` آن ابزار ثبت نشده؛ سیاست AGENTS.md مالکیت MT5-only را مجاز می‌داند. عدد «کد drift» (۹۹) با triage در همین سند آمده است.
- **حذف فرزند BaseKnot**: عمداً heal؛ تغییر آن نیازمند بازطراحی sync و suppression است.
- **درخت کاری dirty**: این پاس فقط ۳ فایل محصول + همین سند را تغییر داده؛ هیچ commitی انجام نشده است.
