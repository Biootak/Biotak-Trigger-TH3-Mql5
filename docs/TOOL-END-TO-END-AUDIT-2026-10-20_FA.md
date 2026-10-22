# ممیزی End-to-End ابزارهای Biotak Trigger TH3 (MT5)

تاریخ: 2026-10-20
دامنه: `Biotak Trigger TH3.mq5` (Full) و `Biotak Trigger TH3 Lite.mq5`
مرجع رفتاری: مخزن MT4، بدون هیچ نوشتن در آن
وضعیت: بازبینی ایستای کد + ساخت هر دو نسخه + teardown واقعی ترمینال. تست تعاملی تکمیلی در انتهای سند آمده است.

## 1. قانون مشترک همه ابزارها

هر ابزار باید در این چرخه پاسخ قابل پیش‌بینی بدهد:

1. **Arm**: کلیک روی seat یا hotkey، بدون اجرای هم‌زمان ابزار دیگر.
2. **Preview**: فقط قبل از commit؛ با Esc، right-click، hide یا deinit پاک شود.
3. **Commit**: یک owner برای نوشتن هندسه و state.
4. **Select/Edit**: نقطه، دسته یا body؛ بدون حذف ناخواسته در کلیک بعدی.
5. **Delete**: یک مسیر مشخص، همراه با فرزندان (dot/handle/plate/box).
6. **Persistence**: شیء committed بعد از TF switch بماند؛ selection و preview نماند.
7. **Teardown**: قفل view، preview، handle و session در هر reason آزاد شود.
8. **UI surface**: کلیک روی پنل/استریپ هرگز به chart نشت نکند.

## 2. ماتریس پوشش

| گروه | ابزارها | مرز اصلی | وضعیت این پاس |
|---|---|---|---|
| Ring family | TRIGGER, ZONES, ATR, TH, HTF, SESSIONS | mask/state/persist | PASS |
| Ring tools | PIN, STEP, GENERAL, HRAY, PATH, SCALE, HIDE | arm/action/teardown | FIXED / PASS |
| Measuring | BASEKNOT, LEG, TH3 (AB=CD), TH3 base mark | gesture/session/click | FIXED / PASS |
| Drawing kinds | LINE, HLINE, VLINE, CHANNEL, FIBO, FIBOFAN, FIBOCHAN, EXPANSION, GANN, PITCHFORK, RECT, TRIANGLE, ELLIPSE, ARROW, TEXT, TANGLE, CYCLES | native draw + strip | PASS |
| Drawing surface | DrawStrip, style memory, templates, lock, 50% markers | selection/style/delete | PASS |
| Persistence | chart objects, GVar, RuntimeSettings, templates | switch/attach/remove | FIXED / PASS |

`PASS` یعنی مسیر کد و build بررسی شده است، نه جایگزین تست ماوس واقعی.

## 3. رفتار ابزارهای Ring

| feat | Arm / Action | حالت دوم | خروجی و persist | ریسک بررسی‌شده |
|---|---|---|---|---|
| `CIR_TRIGGER` | `SetTriggerLevelsVisible(wantOn)` | همان دکمه خاموش می‌کند | state + mask، بدون delete | mute با `wantOn` هم‌راستا است |
| `CIR_ZONES` | `SetMidZonesVisible(wantOn)` | flip | mask؛ خطوط را روشن نمی‌کند | لایه ZONES مستقل از SHOW LINES است |
| `CIR_ATR` | `g_atrLabelsVisible=wantOn` | flip | GVar + mask + repaint | mirror کارت ATR هم به‌روز می‌شود |
| `CIR_TH` | چرخه mode صفر/آخرین mode | flip بین OFF و remembered ON | GVar + mask | mode صفر با mute به ON برمی‌گردد |
| `CIR_HTF` | `SetHTFVisible(!show)` | flip | GVar + mask/cull | کارت HTF با `RequestUISync` هم‌گام می‌شود |
| `CIR_SESSIONS` | `g_sessMaster=wantOn` | flip | `OV_SSON` + tick | خاموش‌کردن، family را rebuild نمی‌کند |
| `CIR_TH3` | `CircArmTH3Draw` | دکمه دوم cancel | 4-click AB=CD | enable و mode قبل از arm repair می‌شوند |
| `CIR_BASEKNOT` | `CircArmBaseKnot` | ring را مخفی می‌کند | drag-draw + committed box | session modal است؛ ابزارهای دیگر کنسل می‌شوند |
| `CIR_LEG` | `LegMeasureToggle` | دکمه دوم cancel | 2-click measurement | delete خط، family را cascade پاک می‌کند |
| `CIR_PIN` | custom price placement | دکمه دوم `DeactivateCustomPriceMode` | GVar + line + marker | placement معلق با tool switch کنسل می‌شود |
| `CIR_STEP_OVERRIDE` | چرخه 0..3 | هر کلیک mode بعدی | GVar حذف + rebuild | mode در UI و رندر هم‌گام می‌شود |
| `CIR_GENERAL` | `PnlOpen(FeaturePanel)` | — | پنل | `stopped` از ادامه‌ی click جلوگیری می‌کند |
| `CIR_HRAY` | `HRayArm` | دکمه دوم cancel | یک کلیک = ray + dot | menu باز می‌ماند؛ ابزارهای دیگر کنسل می‌شوند |
| `CIR_PATH` | `PathArm` | دکمه دوم cancel | چند vertex + double-click finish | bin استریپ owner حذف است |
| `CIR_SCALE` | flip `CHART_SCALEFIX` | — | chart property | persist مستقل ندارد، مطابق MT4 |
| `CIR_HIDE` | `ApplyHideAllState(!hidden)` | — | hide-all + پنل/ring | repaint و state هم‌گام می‌شوند |

## 4. ابزارهای اندازه‌گیری و رسم

### 4.1 Horizontal Ray (`HRayTool.mqh`)

- Arm: `CircArmHRay` (`BiotakMenu.mqh:4467`).
- Place: `HRayPlace` (`HRayTool.mqh:232`) یک `OBJ_TREND` غیرقابل‌انتخاب با `RAY_RIGHT`.
- Move: press روی خط، drag؛ قیمت و زمان شروع با هم جابه‌جا می‌شوند و طول حفظ می‌شود.
- Select: dot مخصوص ray انتخاب‌شده.
- Delete: double-click روی dot (`HRayDelete`، `HRayTool.mqh:275`) یا bin استریپ. حذف نیتیو خط از object list هم در `HRayOnChartEvent` (`:391`) dot را با خود می‌برد؛ dot یک handle/child است و خودش هدف حذف مستقل نیست (`P-HR-07`).
- Teardown: `HRayOnDeinit` (`HRayTool.mqh:587`).

### 4.2 Path (`PathTool.mqh`)

- Arm: `CircArmPath` (`BiotakMenu.mqh:4449`).
- Build: کلیک اول anchor، کلیک‌های بعدی vertex، double-click پایان (`PathFinish`، `PathTool.mqh:779`).
- Edit: فقط vertex handleها؛ body press فقط select است (`P-UI-145`).
- Delete: bin استریپ یا Delete نیتیو روی هر segment؛ هر دو حالا **کل path** را می‌برند (segment، segmentهای خواهر، handleها، ink و mid markerها). double-click delete عمداً retired است (`P-UI-146`).
- Guard: `s_pathDeleting` از re-entry در watcher جلوگیری می‌کند و `PathDelete` پنجره‌ی suppression را برای eventهای بعدی ترمینال arm می‌کند (`PathTool.mqh`، `PathDelete`).
- Teardown: `PathOnDeinit` (`PathTool.mqh:1206`).

### 4.3 Base / Knot (`BaseKnotTool.mqh`)

- Arm: `BaseKnotArm` (`BaseKnotTool.mqh:2008`) با قفل view.
- Draw: drag یا دو کلیک؛ preview و live در `BaseKnotPress`/`BaseKnotCommit`.
- Committed box: move/resize از grip و body؛ فرزندان همراه آن می‌روند.
- Delete: `BaseKnotDelete` (`BaseKnotTool.mqh:6657`) با یک prefix sweep؛ حذف box از object list هم فرزندان را می‌برد.
- Child delete: `BaseKnotSync` عمداً child را heal می‌کند (`BaseKnotTool.mqh:7238`، handler `:7299`) چون sync داخلی روی همین heal سوار است و suppression ندارد؛ بنابراین child-level atomic delete برای BaseKnot فعلاً تغییر نکرده است.
- Teardown: `BaseKnotOnDeinit` (`BaseKnotTool.mqh:2044`) قفل و preview را در هر reason آزاد می‌کند.

### 4.4 TH3 / AB=CD / Leg / Base mark

- `CircArmTH3Draw` (`BiotakMenu.mqh:4510`) چهار pivot را arm می‌کند؛ دکمه دوم cancel.
- `LegMeasureToggle` (`TH3Tool.mqh:3232`) اندازه‌گیری دو کلیکی/درگ.
- `TH3BaseMarkToggle` (`TH3Tool.mqh:3750`) دو edge برای base mark.
- حذف measurement با حذف line و `LegMeasureOnObjectDelete` cascade می‌شود.
- state الگوی TH3 در store خودش می‌ماند؛ previewها در deinit پاک می‌شوند.

### 4.5 Drawing toolbar و DrawStrip

- 17 kind در `EDrawKind` (`DrawToolbar.mqh:46`): LINE, HLINE, VLINE, CHANNEL, FIBO, FIBOFAN, FIBOCHAN, EXPANSION, GANN, PITCHFORK, RECT, TRIANGLE, ELLIPSE, ARROW, TEXT, TANGLE, CYCLES.
- Style memory per kind؛ templateها در `DrawTpl*` (`DrawToolbar.mqh:3316` به بعد) و فایل `Biotak\DrawTemplates.csv`.
- انتخاب/ویرایش با hold چپ روی drawing و باز شدن strip؛ کلیک روی UI با `UIPointerOverSurface` از chart جدا می‌شود.
- Delete: bin استریپ؛ برای ray/path هم owner همان bin است. **P-DEL-ATOMIC (2026-10-20)**: حذف هر عضو خانواده — parent، fill (`_FL`)، mid (`_BX50`)، pen (`_FS*`) یا `_PSK` — در همان event کل خانواده را می‌برد (parent + فرزندان + memoها) و فقط یک redraw دارد.
- Lock، 50% marker، fill/second colour و body slots از capهای همان kind پیروی می‌کنند.

**صف حذف خانواده (P-DEL-ATOMIC):**

| عضو حذف‌شده | قبل | حالا |
|---|---|---|
| parent drawing (native Delete/object list) | فرزندان drop می‌شدند ولی هر child یک `DELFLUSH`/`ChartRedraw` جدا می‌داد | `DrawFamilyDelete` زیر یک suppression؛ یک redraw |
| `_FL` fill child | `FillChildSync(parent)` آن را دوباره می‌ساخت | parent + همه‌ی siblings حذف می‌شوند |
| `_BX50` mid child | `BoxMidSync(parent)` heal می‌کرد | parent + family حذف می‌شوند |
| `_FS*` / `_PSK` child | heal/یتیم می‌ماند یا orphan sweep دیرتر می‌گرفت | parent + family در همان event |
| child با parent indicator | — | child به‌عنوان stray drop می‌شود؛ fill parent در صورت لزوم restore |
| path segment (native Delete) | فقط همان segment می‌رفت و بقیه‌ی polyline می‌ماند | `PathDelete` کل path را می‌برد (هم‌رفتار با bin، `P-UI-136`) |

## 5. یافته‌ها و اصلاح‌های این پاس

### F-01 — دو ابزار می‌توانستند هم‌زمان arm شوند (High)

**رفتار قبلی:**
- `CircArmHRay` فقط BaseKnot، Leg و TH3 را بررسی می‌کرد؛ Path را نه.
- `CircArmPath` فقط BaseKnot، Leg و TH3 را بررسی می‌کرد؛ HRay را نه.
- در نتیجه HRay و Path هر دو armed می‌شدند. چون `HRayOnChartEvent` در `OnChartEventHandler` اول اجرا می‌شود (`EventHandlers.mqh:6148`)، کلیک را می‌بلعید و Path هیچ vertexی نمی‌گرفت؛ چراغ Path روشن می‌ماند و ابزار «مرده» به نظر می‌رسید.
- همین ناسازگاری برای TH3/Leg و PIN/ابزارهای دیگر هم قابل بازتولید بود.

**اصلاح:**
- یک owner مرکزی: `CancelOtherToolSessions(const int keep)` در `Biotak/EventHandlers.mqh:2162`.
- قبل از arm شدن هر ابزار، sessionهای دیگر کنسل می‌شوند: PIN معلق، HRay، Path، BaseKnot، TH3، Leg.
- نقاط فراخوانی:
  - `CircArmBaseKnot` — `BiotakMenu.mqh:4441`
  - `CircArmPath` — `BiotakMenu.mqh:4454`
  - `CircArmHRay` — `BiotakMenu.mqh:4475`
  - `CircArmTH3Draw` — `BiotakMenu.mqh:4531`
  - `CIR_PIN` — `BiotakMenu.mqh:4684`
  - `CIR_LEG` — `BiotakMenu.mqh:5085`
  - hotkeyهای V و P — `EventHandlers.mqh:6582` و `6599`
  - base mark B — `TH3Tool.mqh:3750` و Start در `LegMeasureToggle` (`TH3Tool.mqh:3232`).
- BaseKnot همچنان modal است و قبل از arm شدن، ابزارهای دیگر را می‌بندد.

**اثر:** کلیک بعدی فقط به ابزاری می‌رسد که چراغش روشن است؛ هیچ session معلقی باقی نمی‌ماند.

### F-02 — tooltip قدیمی Path (Medium)

**رفتار قبلی:** tooltip می‌گفت «double-click the dot to remove»، ولی `P-UI-146` حذف با double-click را عمداً retired کرده بود و حذف فقط از bin استریپ انجام می‌شود.

**اصلاح:** `PathTooltip` در `Biotak/PathTool.mqh:288` به «drag a point to move — delete from the strip bin» تغییر کرد.

**اثر:** راهنمای ابزار با رفتار واقعی یکی است و کاربر مسیر حذف را اشتباه نمی‌گیرد.

### F-03 — dot/handleهای انتخاب‌شده بعد از TF switch می‌ماندند (Medium)

**رفتار قبلی:**
- روی deinit، `s_hraySel` و `s_pathSel` خالی می‌شدند، ولی dot مربوط به ray و vertex handleهای path روی chart می‌ماندند.
- `OnInit` هم selection را خالی می‌کرد، پس این اجسام نه select می‌شدند و نه owner داشتند؛ نتیجه: ghost dot/handle بعد از تغییر تایم‌فریم یا attach.
- در Path، preview و نیمه‌ساخت با `P-UI-180` پاک می‌شد، ولی handleها نه.

**اصلاح:**
- `HRayHandlesWipe` (`HRayTool.mqh:571`) و `PathHandlesWipe` (`PathTool.mqh:1192`) فقط handleهای ray/pathهای شناخته‌شده را پاک می‌کنند؛ full-chart scan اضافه نشد.
- `HRayOnInit` بعد از `HRayAdoptOrphans` و `PathOnInit` بعد از `PathAdoptOrphans` این sweep را انجام می‌دهند.
- `HRayOnDeinit` و `PathOnDeinit` برای همه‌ی reasonها (به‌جز REASON_REMOVE که خودش prefix را می‌زداید) handleها را پاک می‌کنند.

**اثر:** پایه‌های ray/path بعد از TF switch می‌مانند، ولی dot/handleهای انتخاب قبلی برنمی‌گردند و selection تازه روی chart تمیز انجام می‌شود.

### F-04 — teardown وسط arm/drag قفل view را با شمارنده‌ی درست آزاد نمی‌کرد (Medium)

**رفتار قبلی:** `HRayOnDeinit` و `PathOnDeinit` فقط flagها را صفر می‌کردند. `ChartViewLockForceRelease` در `OnDeinitHandler` به‌عنوان net وجود دارد، ولی owner خودش release نمی‌داد و شمارنده‌ی lock نادرست می‌ماند.

**اصلاح:**
- `HRayOnDeinit`: `HRayDragRelease()` و `ChartViewLockRelease()` معادل arm.
- `PathOnDeinit`: `PathDragRelease()` و `ChartViewLockRelease()` معادل arm.
- BaseKnot از قبل `BaseKnotUnlockChart` را در `BaseKnotOnDeinit` داشت.

**اثر:** حتی اگر حذف/تعویض TF وسط درگ رخ دهد، chart-scroll/context-menu از همان owner آزاد می‌شود؛ net هم دست‌نخورده می‌ماند.

### F-05 — base mark و leg می‌توانستند زیر ray/path arm شوند (Low)

**اصلاح:** `TH3BaseMarkToggle` قبل از arm شدن، `HRaySessionActive`/`PathSessionActive` را کنسل می‌کند (`TH3Tool.mqh:3750`). `LegMeasureToggle` هم در شروع، ray/path/base را می‌بندد (`TH3Tool.mqh:3232`). در پاس P-DEL-ATOMIC، B hotkey هم قبل از arm شدن `CancelOtherToolSessions(TOOL_OWN_TH3 | TOOL_OWN_LEG)` را صدا می‌زند تا PIN معلق و BaseKnot/HRay/Path armed را ببندد، و `TH3BaseMarkToggle` خودش `BaseKnotSessionActive` را cancel می‌کند.

### F-06 — متن «drag to move» برای body path (Low)

**اصلاح:** متن tooltip از «drag to move» به «drag a point to move» تغییر کرد؛ body path فقط select می‌شود و جابه‌جایی از vertex است.

### 4.6 ممیزی تک‌به‌تک 17 kind

همه‌ی kindها یک چرخه‌ی مشترک دارند: arm از toolbar → preview فقط قبل از commit → کلیک/درگ commit → انتخاب با strip → ویرایش با grip/body → حذف خانواده با `DrawFamilyDelete` → ماندگاری committed پس از TF switch. تفاوت kindها در هندسه و اعضای اختیاری است:

| kind | هندسه / اعضای اختیاری | حذف |
|---|---|---|
| `LINE` | دو نقطه، master تنها | family helper؛ فرزند ندارد |
| `HLINE` | خط افقی، master تنها | همان |
| `VLINE` | خط عمودی، master تنها | همان |
| `CHANNEL` | سه نقطه؛ fill/mid/pen در صورت فعال بودن | parent + `_FL`/`_BX50`/`_FS*` |
| `FIBO` | سطوح fibo؛ pen/look در صورت فعال بودن | parent + `_FS*` + look/tag |
| `FIBOFAN` | fan؛ pen/look | همان |
| `FIBOCHAN` | channel؛ pen/look | همان |
| `EXPANSION` | سه نقطه؛ pen/look | همان |
| `GANN` | fan/grid؛ master و خطوط | family helper |
| `PITCHFORK` | سه نقطه؛ master و خطوط | family helper |
| `RECT` | چهار گوشه؛ fill/mid/pen | parent + `_FL`/`_BX50`/`_FS*` |
| `TRIANGLE` | سه گوشه؛ fill/mid/pen | همان |
| `ELLIPSE` | مرکز/شعاع؛ fill/mid/pen | همان |
| `ARROW` | دو نقطه، master | family helper |
| `TEXT` | anchor + متن، master | family helper |
| `TANGLE` | triangle angle؛ master | family helper |
| `CYCLES` | cycles؛ master | family helper |

نکته: orphan net (`DrawStrip.mqh` ~3480) و `BoxExtrasPump` هر ۲ ثانیه فقط برای childهای یتیمِ جامانده از مسیرهای قدیمی/indicator هستند؛ مسیر عادی حذف دیگر به آن‌ها تکیه نمی‌کند.

### F-07 — حذف خانواده‌ی drawing یک‌پارچه نبود (High)

**رفتار قبلی:**
- parent drawing در `DrawStripOnChartEvent` فرزندان را drop می‌کرد، اما بعد از هر `ObjectDelete` ترمینال یک `CHARTEVENT_OBJECT_DELETE` جدا می‌فرستاد؛ هر event دوباره `DELFLUSH` و `ChartRedraw` می‌داد. حذف یک family سنگین (fill + mid + pen + tag) چند redraw و چند ده میلی‌ثانیه طول می‌کشید و در log فقط `DELFLUSH`های پراکنده دیده می‌شد، نه یک cascade واحد.
- حذف یک child (مثلاً `_FL` یا `_BX50`) به‌جای حذف drawing، parent را **heal** می‌کرد: child دوباره ساخته می‌شد و کاربر فکر می‌کرد حذف نشده است.
- `Path` این ناسازگاری را داشت: bin کل path را می‌برد (`P-UI-136`)، ولی Delete نیتیو روی یک segment فقط همان segment را حذف می‌کرد و بقیه‌ی polyline می‌ماند.
- `BaseKnot` child delete عمداً heal می‌شود و دست نخورد (ریسک تخریب boxهای در حال sync).

**اصلاح:**
- `DrawFamilyDelete(obj)` در `DrawStrip.mqh:8755` قبل از `DrawStripFireDelete`: تمام memoها/فرزندان (`BoxEdgeForget`, `BoxMarkDrop`, `FibPenStraysDrop`, `FibPenTagDrop`, `FibPenLookDrop`, `PenStackStraysDrop`, `BoxMidDrop`, `FillChildDrop`) و خود parent را زیر `g_suppressDeleteEvents` حذف می‌کند؛ بعد پنجره‌ی 250ms را arm می‌کند تا eventهای queued ترمینال دوباره وارد نشوند.
- `DrawStripFireDelete` (bin) و شاخه‌ی native delete از همین helper استفاده می‌کنند.
- در `DrawStripOnChartEvent` (`:10390`) هر child (`_BX50`, `_FL`, `_FS*`, `_PSK`) به parent map می‌شود: parent غیر-indicator → `DrawFamilyDelete(parent)`؛ parent indicator → `DrawOrphanDrop(child)` و در صورت fill، restore؛ parent غایب → `DrawOrphanDrop` فوری.
- `PathTool`: `s_pathDeleting` re-entry guard (`:56`, watcher `:932`)؛ Delete نیتیو هر segment → `PathDelete(pid)` (`:293`) برای کل path؛ `PathDelete`/`PathSessionClear` پنجره‌ی suppression را arm می‌کنند.
- `userDel` قبل از helper محاسبه می‌شود (helper خودش suppression را arm می‌کند) و logهای `CASCADE child=... parent=...` دلیل حذف را ثبت می‌کنند.

**اثر:** حذف هر عضو یک drawing، کل خانواده را در همان event و با یک redraw می‌برد؛ دیگر child دوباره ساخته نمی‌شود و segment تنها نمی‌ماند. این همان «یک‌پارچه بودن» حذف در MT4 است.

## 6. رفتار در خطا و حالت‌های مرزی

| رویداد | رفتار فعلی |
|---|---|
| کلیک دوم روی ابزار toggle | همان ابزار cancel می‌شود؛ ابزارهای دیگر دست‌نخورده می‌مانند |
| کلیک روی ابزار دیگر | session قبلی کنسل می‌شود، بعد ابزار جدید arm می‌شود |
| Esc | drag/arm ابزار فعال را برمی‌گرداند؛ custom price هم مسیر خودش را دارد |
| right-click | Path/HRay/Leg/BaseMark را cancel می‌کند؛ در Custom Price نیز placement را لغو می‌کند |
| کلیک روی پنل/استریپ | با `UIPointerOverSurface` و claim UI از chart جدا می‌شود |
| hide (F) | familyهای mask شده park می‌شوند؛ ابزارهای جدید در حالت hidden arm نمی‌شوند |
| TF switch | preview و session پاک؛ committed objectها می‌مانند؛ handleهای انتخاب پاک می‌شوند |
| remove indicator | objectهای committed در REASON_REMOVE sweep می‌شوند؛ قفل و preview آزاد می‌شوند |
| حذف ray از object list | `OBJECT_DELETE` خط، dot و registry را پاک می‌کند؛ dot هدف مستقل نیست |
| حذف parent drawing از object list | `DrawFamilyDelete` همه‌ی فرزندان/memoها را زیر یک suppression می‌برد؛ یک redraw |
| حذف child drawing (`_FL`/`_BX50`/`_FS*`/`_PSK`) | parent + همه‌ی siblings حذف می‌شوند (اگر parent indicator باشد child stray drop می‌شود) |
| حذف path segment از object list | Delete نیتیو روی هر segment → `PathDelete` کل path را می‌برد |
| حذف path از bin | `PathDelete` همه‌ی segmentها، handleها، ink و mid markerها را می‌برد |
| حذف measurement | حذف line، `LegMeasureDelete` و plate/box را cascade می‌کند |

## 7. شواهد ساخت

- Full (standalone): `build-logs/Biotak-Trigger-TH3-20261020-205729.log`
  - `0 errors, 0 warnings`
  - EX5: `Biotak Trigger TH3.ex5` — 2,540,804 bytes (20:58:27)
- Lite: `build-logs/Biotak-Trigger-TH3-Lite-20261020-205848.log`
  - `0 errors, 0 warnings`
  - EX5: `Biotak Trigger TH3 Lite.ex5` — 917,476 bytes (20:59:13)
- verify: `build-logs/Biotak-Trigger-TH3--verify-20261020-205931.log`
  - rebuild: `0 errors, 0 warnings`; EX5 2,539,586 bytes (21:00:30)
  - VERDICT: GREEN
  - teardown menu این build: 78ms، budget 150ms
  - teardown build قبلی: 78ms؛ delta 78→78
  - `GEST census lines: PASS (0)`
  - `INIT`: fresh init مشاهده نشد (attach دستی لازم است)
  - `deinit handler breakdown` این build: `knot=31..46ms`؛ full-chart scan ندارد. build میانی sweep کامل handleها در یک اجرا `knot=1875ms` داد و دلیل حذف آن sweep بود.
- `CHART_CHANGE`: آخرین مشاهده n=1، median=47ms (budget 40ms، جزئی؛ در اجرای نهایی خطی چاپ نشد).
- preprocessor balance: `Biotak/DrawStrip.mqh` و `Biotak/PathTool.mqh` depth صفر؛ `git diff --check` تمیز.

## 8. تست تعاملی باقی‌مانده

این موارد با build فعلی باید یک‌بار روی ترمینال اجرا شوند:

1. HRAY را arm کن، بعد PATH را arm کن، یک کلیک بزن: فقط PATH باید vertex بگیرد؛ چراغ HRAY باید خاموش باشد.
2. برعکس: PATH سپس HRAY.
3. PIN را در حالت placement بگذار، سپس HRAY/PATH را arm کن: خط موقت PIN باید پاک شود و ابزار جدید کلیک بگیرد.
4. یک Path بکش، انتخاب کن، تایم‌فریم عوض کن و برگرد: هیچ dot اضافه‌ای نباید بماند؛ path و segmentها باید باشند.
5. همین تست را برای HRAY و dot آن انجام بده.
6. وسط arm یا drag، indicator را Remove کن: scroll/context-menu chart باید عادی باشد و preview نیمه‌کاره نماند.
7. B را با HRAY/PATH فعال بزن: base mark باید شروع شود و ابزار قبلی کنسل شود.
8. V و P را در حضور ابزار دیگر بزن.
9. tooltip Path: باید «strip bin» را نشان دهد، نه double-click.
10. یک Fibo Channel/Expansion/Rectangle و Ellipse/Triangle بکش و pen-heal را روی آن تست کن (از پاس قبلی).
11. یک Rectangle با fill + mid + pen بکش؛ parent را با Delete نیتیو حذف کن: هر سه فرزند باید در همان لحظه بروند و فقط یک redraw/log cascade دیده شود.
12. همان Rectangle را دوباره بساز؛ این بار `_FL` را از object list حذف کن: کل Rectangle و فرزندان باید بروند، نه اینکه fill دوباره ساخته شود.
13. همین تست را برای `_BX50` و یک `_PSK`/`_FS*` تکرار کن.
14. یک Path سه‌segmentی بساز؛ یک segment را با Delete نیتیو حذف کن: کل path، segmentها، handleها، ink و mid باید بروند.
15. یک `THLevelsSESS_*_FL` را (اگر در object list دیدی) حذف کن: فقط همان stray برود و parent indicator دست‌نخورده بماند؛ بعد از ۲ ثانیه هیچ fill یتیمی نماند.

## 9. ریسک‌های باقی‌مانده

- **Runtime visual**: هیچ ادعای pixel-parity برای این تغییرات بدون تست ماوس/اسکرین‌شات وجود ندارد؛ مخصوصاً حذف family و Path native delete که فقط با build 20:29 تست‌پذیرند.
- **BaseKnot child delete**: عمداً heal می‌ماند؛ `BaseKnotSync` روی همین heal سوار است و suppression ندارد. اگر کاربر child غیرقابل‌انتخاب را از object list حذف کند، box زنده می‌ماند. تغییر این رفتار نیازمند بازطراحی sync است و در این پاس انجام نشد.
- **DrawStrip suppression window**: پنجره‌ی 250ms برای eventهای queued است؛ اگر ترمینال بیش از 250ms eventهای حذف را تحویل دهد، بعضی `DELFLUSH`ها ممکن است دوباره ظاهر شوند. با اندازه‌گیری واقعی قابل تنظیم است.
- **CHART_CHANGE**: median 47ms کمی بالای budget 40ms است؛ GREEN را نشکسته ولی باقی‌مانده‌ی perf است.
- **Object-path A/B**: کامپایل Full با `BIOTAK_RENDER_ENGINE` خاموش همچنان pre-existing broken است (اولین خط: `TH3Renderer.mqh:1005`, error 133)؛ مسیر پیش‌فرض engine سبز است.
- **BuildHash**: `Biotak/BuildHash.mqh` همچنان stale است؛ تولیدکننده‌ی MT5 ندارد.
- **Icons**: 55 آیکن بازنشسته‌ی MT4 در MT5 وجود دارد ولی ارجاعی ندارند؛ عمدی نگه داشته شده‌اند.
- **فایل‌های تغییر‌یافته**: درخت کاری از قبل dirty است؛ این پاس فقط فایل‌های ابزار و همین سند را تغییر داده و هیچ commitی انجام نشده است.
