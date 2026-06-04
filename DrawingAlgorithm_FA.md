# الگوریتم رسم سطوح و زون‌ها — معماری Zone-First

> مستند الگوریتم رسم سطوح و زون‌های اندیکاتور Biotak Trigger TH3
> بر اساس پیاده‌سازی `Biotak/LevelPipeline.mqh` (نسخه MT5)
> هدف: مرجع واحد برای درک، بازبینی و مهاجرت منطق رسم

---

## فهرست

1. [فلسفه Zone-First](#1-فلسفه-zone-first)
2. [نمای کلی Pipeline](#2-نمای-کلی-pipeline)
3. [مرحله ① — تعیین Anchor](#3-مرحله--تعیین-anchor)
4. [مرحله ② — محاسبه سطوح خام](#4-مرحله--محاسبه-سطوح-خام)
5. [مرحله ③ — طبقه‌بندی سطوح](#5-مرحله--طبقه‌بندی-سطوح)
6. [مرحله ④ — ساخت زون‌ها (موجودیت اصلی)](#6-مرحله--ساخت-زون‌ها-موجودیت-اصلی)
7. [مرحله ⑤ — استخراج خطوط Trigger](#7-مرحله--استخراج-خطوط-trigger)
8. [مرحله ⑥ — رندر (ترتیب حیاتی)](#8-مرحله--رندر-ترتیب-حیاتی)
9. [مرحله ⑦ — پاکسازی](#9-مرحله--پاکسازی)
10. [مثال عددی کامل](#10-مثال-عددی-کامل)
11. [حالت‌های خاص](#11-حالت‌های-خاص)
12. [مقایسه با Line-First](#12-مقایسه-با-line-first)

---

## 1. فلسفه Zone-First

```
┌─────────────────────────────────────────────────────────────┐
│  Zone = موجودیت اصلی (PRIMARY ENTITY)                       │
│  Line = مشتق‌شده از مرز زون‌ها (DERIVED ENTITY)             │
│                                                             │
│  ❌ رویکرد قدیمی: اول خط بکش، بعد ببین چطور زون بساز       │
│  ✅ رویکرد MT5: اول زون بساز، خط دقیقاً وسط زون‌ها قرار    │
│     می‌گیرد                                                 │
└─────────────────────────────────────────────────────────────┘
```

**چرا؟**
- بدون drift (انحراف): زون مستقیماً روی سطح ساخته می‌شود، نه انباشته روی خطوط قبلی
- بدون همپوشانی: دو زون مجاور دقیقاً در نیمه‌راه به هم می‌رسند
- تست‌پذیر: Stages 1-4 فقط داده pure هستند (هیچ وابستگی به MT5)
- مستقل از ترتیب محاسبه: زون و خط می‌توانند در دو پاس جداگانه ساخته شوند
- افزودن مود جدید: فقط Stage 1 (محاسبه قیمت) باید نوشته شود

---

## 2. نمای کلی Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  Pipeline اصلی (ExecutePipeline)                             │
│                                                              │
│  ① Anchor ─────┐                                             │
│                ↓                                             │
│  ② CalculateLevels ───→ SCalculatedLevel[]                   │
│                ↓                                             │
│  ③ ClassifyLevels ─────→ SLevelClassified[]                  │
│                ↓                                             │
│  ④ BuildZones (PRIMARY) ─→ SZoneDefinition[]                 │
│                ↓                                             │
│  ⑤ DeriveTriggers ───────→ STriggerLine[]                    │
│                ↓                                             │
│  ⑥ RenderZones (FIRST) ───→ OBJ_RECTANGLE                    │
│  ⑥ RenderTriggers (SECOND) → OBJ_HLINE                       │
│                ↓                                             │
│  ⑦ CleanupSurplus ────────→ حذف اشیاء قدیمی                 │
└──────────────────────────────────────────────────────────────┘
```

**خروجی نهایی هر Stage فقط داده است، نه شیء گرافیکی.** این یعنی:
- می‌توان آن را unit-test کرد
- می‌توان در حافظه نگه داشت و چندبار رندر کرد
- می‌توان در فریم‌های مختلف فقط یک Stage را اجرا کرد

---

## 3. مرحله ① — تعیین Anchor

**هدف:** پیدا کردن نقطه صفر (مرکز کل ساختار).

```
ورودی:
  - g_thStartPointType: نوع نقطه شروع
  - بسته به نوع: قیمت فعلی / قیمت دلخواه کاربر / قیمت روز

خروجی:
  Anchor: عدد (double)

قوانین:
  - اگر Custom Price → کاربر دستی وارد کرده
  - در غیر این صورت → معمولاً قیمت فعلی یا قیمت شروع روز معاملاتی

اعتبارسنجی:
  - Anchor > 0
  - Anchor باید finite باشد (نه NaN, نه Inf)
```

---

## 4. مرحله ② — محاسبه سطوح خام

**هدف:** تولید لیست کامل سطوح قیمت در دو جهت بالا و پایین Anchor.

### 4.1. ساختار خروجی

```
SCalculatedLevel {
  price       : double   // قیمت واقعی
  logicalStep : int      // شماره پله (1, 2, 3, ..., -1, -2, ...)
  isMidpoint  : bool     // true فقط برای Anchor
  direction   : int      // +1 بالا, -1 پایین, 0 midpoint
}
```

### 4.2. الگوریتم

```
ورودی:
  centerPrice        : Anchor
  stepSizes[]        : آرایه‌ای از اندازه پله‌ها (می‌تواند چندتایی باشد)
  stepSizeCount      : تعداد stepSize ها
  stepMode           : UNIFORM یا CUMULATIVE
  maxLevelsAbove     : حداکثر تعداد سطح بالا
  maxLevelsBelow     : حداکثر تعداد سطح پایین
  boundByHistorical  : آیا محدود به بالاترین/پایین‌ترین تاریخی باشد؟
  maxPrice, minPrice : حدود قیمت

مراحل:
  ① Midpoint:  levels[0] = {centerPrice, step=0, isMidpoint=true, dir=0}

  ② سطوح بالا (i = 1, 2, 3, ...):
     اگر stepMode == UNIFORM:
        price = centerPrice + stepSizes[0] × i
     اگر stepMode == CUMULATIVE:
        cumAbove += stepSizes[(i-1) % stepSizeCount]
        price = centerPrice + cumAbove
     اگر boundByHistorical و price > maxPrice → توقف
     levels[count] = {price, i, false, +1}
     ادامه تا رسیدن به maxLevelsAbove

  ③ سطوح پایین (i = 1, 2, 3, ...):
     مشابه بالا، ولی:
        price = centerPrice - cumBelow
     اگر price < minPrice یا price <= 0 → توقف
     levels[count] = {price, -i, false, -1}

  ④ maxStepOut = max(تعداد بالا، تعداد پایین)

  ⑤ ArrayResize(levels, count)  // trim آرایه
```

### 4.3. نکات

- **هیچ سطحی skip نمی‌شود** — همه رسم می‌شوند، حتی اگر در آینده حذف شوند.
- اگر stepSize ترکیبی باشد (مثل Combo با چند TF)، به‌صورت چرخشی استفاده می‌شود.
- حلقه‌ها دارای `maxIterations = maxLevels × 2` هستند (جلوگیری از بی‌نهایت شدن).

---

## 5. مرحله ③ — طبقه‌بندی سطوح

**هدف:** تعیین نقش هر سطح (Structure / Trigger / Midpoint) و اختصاص رنگ/استایل.

### 5.1. ساختار خروجی

```
SLevelClassified {
  price          : double
  logicalStep    : int
  isMidpoint     : bool
  direction      : int

  // نتیجه طبقه‌بندی
  structureLevel : int      // 0 = نه structure، 1..5 = L1..L5
  isTrigger      : bool
  isStructure    : bool
  levelColor     : color
  levelStyle     : ENUM_LINE_STYLE
  levelWidth     : int
  zoneColor      : color    // رنگ زون متصل به این سطح
}
```

### 5.2. سلسله مراتب اولویت

```
Midpoint
   ↓
Structure L5
   ↓
Structure L4
   ↓
Structure L3
   ↓
Structure L2
   ↓
Structure L1
   ↓
Trigger (اگر trigger سطوح فعال باشد)
   ↓
Mode Fallback Color
```

### 5.3. الگوریتم تشخیص Structure

**محاسبه فاصله‌های Structure (cached):**
```
با base multiplier (مثلاً 4):
  L1 = base × 2^0 = 4
  L2 = base × 2^1 = 8
  L3 = base × 2^2 = 16
  L4 = base × 2^3 = 32
  L5 = base × 2^4 = 64
```

**تشخیص بالاترین سطح Structure برای هر step:**

```
function GetHighestStructureLevel(step):
    if step == 0 → return 0
    absStep = |step|

    if absStep % L5 == 0 → return 5
    if absStep % L4 == 0 → return 4
    if absStep % L3 == 0 → return 3
    if absStep % L2 == 0 → return 2
    if absStep % L1 == 0 → return 1
    return 0  // یعنی Trigger subdivision
```

### 5.4. الگوریتم کامل طبقه‌بندی

```
برای هر سطح i در rawLevels:

  ① اگر isMidpoint:
        کپی از raw
        استایل از GetPathForLevelOptimized(0, ...)
        continue

  ② structureLevel = GetHighestStructureLevel(step)

  ③ اگر structureLevel > 0:
        isStructure = true
        isTrigger = false
        استایل = GetPathForLevelOptimized(step, ...)  // L1..L5
     در غیر این صورت:
        isStructure = false
        isTrigger = true
        اگر trigger سطوح فعال باشد:
            استایل = inpTriggerColor/Style/Width
        در غیر این صورت:
            استایل = mode fallback

  ④ zoneColor = GetZoneColorForLevel(step, triggerEnabled, base)
     اگر zoneColor == NONE → zoneColor = levelColor
```

### 5.5. انواع Classifier (بسته به مود)

| مود | نوع Classifier | رفتار |
|---|---|---|
| Standard | `CLASSIFY_STANDARD` | منطق پیش‌فرض بالا |
| SSLS | `CLASSIFY_ALTERNATING` | سطوح غیرstructure بر اساس زوج/فرد بودن step یکی‌درمیان SS/LS می‌شوند |
| M-Mode | `CLASSIFY_MMODE` | هر step مضرب 3 = M level، بقیه C level |

---

## 6. مرحله ④ — ساخت زون‌ها (موجودیت اصلی)

**⛳ اینجا همان «first zone» است که از آن صحبت می‌کردیم.**

### 6.1. ساختار خروجی

```
SZoneDefinition {
  name         : string    // نام یکتا برای شیء گرافیکی
  midPrice     : double    // مرکز زون = خود سطح
  renderTop    : double    // مختصات بصری بالا
  renderBottom : double    // مختصات بصری پایین
  logicalStep  : int
  direction    : int
  zoneIndex    : int       // شماره ترتیبی در این جهت
  isStructure  : bool
  isTrigger    : bool
  zoneColor    : color
  transparency : int       // 0..100
  style        : ENUM_ZONE_STYLE
  filled       : bool
  inViewport   : bool      // آیا در محدوده دید است؟
}
```

### 6.2. جداسازی سطوح به سه دسته

```
ورودی: classified[] (همه سطوح)
خروجی:
  aboveLevels[]  → سطوح direction=+1
  belowLevels[]  → سطوح direction=-1
  midLevel       → سطح midpoint (اگر وجود داشته باشد)

در یک پاس:
  for i in classified:
      if isMidpoint: midLevel = classified[i]
      if direction > 0: aboveLevels.push(classified[i])
      if direction < 0: belowLevels.push(classified[i])
```

### 6.3. ساخت زون Midpoint (اولین زون)

```
اگر zonesEnabled و hasMid:
    ① پیدا کردن نزدیک‌ترین همسایه:
       اگر aboveCount > 0:
           neighborDist = aboveLevels[0].price - midLevel.price
       else if belowCount > 0:
           neighborDist = midLevel.price - belowLevels[0].price
       else:
           neighborDist = 100 × Point  // fallback

    ② zoneHeight = neighborDist × zoneHeightPercent × 0.5

    ③ ساخت زون:
       name        = prefix + modeName + "_Zone_Center_0"
       midPrice    = midLevel.price
       renderTop   = midLevel.price + zoneHeight
       renderBottom= midLevel.price - zoneHeight
       logicalStep = 0
       direction   = 0
       zoneIndex   = 0
       isStructure = true
       isTrigger   = false
       inViewport  = (renderTop >= vpBottom AND renderBottom <= vpTop)
```

### 6.4. ساخت زون‌های بالا (و خطوط trigger بینشان)

```
prevPrice = midLevel.price   (یا 0 اگر midpoint نیست)

for each level in aboveLevels:
    currentPrice = level.price
    if currentPrice <= prevPrice: continue  // safety

    stepSize = currentPrice - prevPrice

    // ⭐ ساخت زون روی این سطح
    zoneHeight = stepSize × zoneHeightPercent × 0.5
    zones[zIdx] = {
        name: prefix + modeName + "_Zone_Above_" + logicalStep,
        midPrice: currentPrice,
        renderTop: currentPrice + zoneHeight,
        renderBottom: currentPrice - zoneHeight,
        ...
    }
    zIdx++

    prevPrice = currentPrice
```

### 6.5. ساخت زون‌های پایین

```
مشابه بالا، ولی:
  - zoneIndex به ترتیب صعودی از Anchor به سمت پایین
  - renderTop = currentPrice + zoneHeight
  - renderBottom = currentPrice - zoneHeight
```

### 6.6. فرمول کلیدی

```
zoneHeight = stepSize × zoneHeightPercent / 2
```

**نتیجه:** اگر `zoneHeightPercent = 1.0`:
- زون از `currentPrice - stepSize/2` تا `currentPrice + stepSize/2` امتداد دارد
- دو زون مجاور دقیقاً در `currentPrice` به هم می‌رسند (بدون فاصله و بدون همپوشانی)
- خط trigger وسطشان دقیقاً همان `currentPrice` خواهد بود (نه نقطه وسط بصری، بلکه خود سطح)

**اگر `zoneHeightPercent < 1.0`:** زون‌ها کوچک‌تر می‌شوند و فاصله بصری بینشان ایجاد می‌شود.

**اگر `zoneHeightPercent > 1.0`:** زون‌ها همپوشانی پیدا می‌کنند.

---

## 7. مرحله ⑤ — استخراج خطوط Trigger

**⛳ این خطوط "موجودیت ثانویه" هستند — فقط برای نشانه‌گذاری مرز بین زون‌ها رسم می‌شوند.**

### 7.1. ساختار خروجی

```
STriggerLine {
  name        : string
  price       : double    // = zone midPrice سطح بالایی (یعنی خود سطح)
  logicalStep : int
  direction   : int
  lineColor   : color
  lineStyle   : ENUM_LINE_STYLE
  lineWidth   : int
  tooltip     : string
  setBack     : bool
  zOrder      : int
  inViewport  : bool
  isMidpoint  : bool
}
```

### 7.2. الگوریتم (در حلقه ساخت زون‌ها — single pass)

```
// در حلقه ساخت زون‌های بالا (مشابه برای پایین):
for each level in aboveLevels:
    currentPrice = level.price
    prevPrice = ... (Anchor یا سطح قبلی)

    // ⭐ خط trigger در وسط بین prevPrice و currentPrice
    lineMidPrice = (prevPrice + currentPrice) / 2

    // اگر zoneHeightPercent = 1.0، این دقیقاً = currentPrice است
    // اگر zoneHeightPercent < 1.0، این وسط فاصله خالی بین دو زون است

    lines[lIdx] = {
        name: prefix + modeName + "_Above_" + logicalStep,
        price: lineMidPrice,
        lineColor: level.levelColor,
        lineStyle: level.levelStyle,
        lineWidth: level.levelWidth,
        ...
    }
    lIdx++

    // بعد زون ساخته می‌شود
    ...
```

### 7.3. استثنا: Midpoint

```
⚠️  Midpoint = Anchor دیگر خط trigger نمی‌گیرد.
    به جایش یک زون Center می‌گیرد (مرحله 6.3).
    دلیل: Anchor خودش نقطه شروع است، نباید دو بار نمایش داده شود.
    (در حالت Legacy ممکن است خط Midpoint_0 نیز باشد، ولی در معماری جدید حذف شده)
```

---

## 8. مرحله ⑥ — رندر (ترتیب حیاتی)

### 8.1. ترتیب رندر

```
┌────────────────────────────────────────────────────┐
│  ⑥a RenderZones (FIRST)   → OBJ_RECTANGLE          │
│  ⑥b RenderTriggers (SECOND) → OBJ_HLINE             │
│  ⑥c CleanupSurplus (THIRD)                       │
└────────────────────────────────────────────────────┘
```

⚠️ **چون خطوط trigger روی مرز زون‌ها هستند، اگر زون بعد از خط رندر شود، زون خط را می‌پوشاند.** به همین دلیل زون‌ها اول رسم می‌شوند.

### 8.2. الگوریتم RenderZones

```
for each zone in zones[]:
    if zoneStyle == HIDDEN:
        if zone exists → ObjectDelete
        continue

    if zone.isTrigger and not triggerEnabled:
        if zone exists → ObjectDelete  // حذف زون trigger غیرفعال
        continue

    if zone.renderTop <= zone.renderBottom:
        continue  // نامعتبر

    if zoneStyle == LINES:
        CreateFactorMidZone_LinesStyle(
            name, renderTop, renderBottom, color, transparency
        )
    else:
        // Box style (filled یا empty)
        CreateZone({
            name: zone.name,
            topPrice: zone.renderTop,
            bottomPrice: zone.renderBottom,
            color: zone.zoneColor,
            transparency: zone.transparency,
            filled: (zoneStyle == BOX_FILLED),
            startTime: 0,    // auto
            endTime: 0       // auto
        })
```

### 8.3. الگوریتم RenderTriggers

```
for each line in lines[]:
    // مود Factor: اگر trigger فعال باشد، خط trigger پنهان شود
    if config.hideLineWhenTriggerOnly and not line.isMidpoint:
        if triggerEnabled and line exists:
            ObjectSetInteger(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)
        continue

    isNew = CreateOrUpdateHLine(
        name, price, color, style, width, tooltip
    )

    if isNew:
        if config.useObjPropBack:
            ObjectSetInteger(name, OBJPROP_BACK, false)
        if config.zOrder > 0:
            ObjectSetInteger(name, OBJPROP_ZORDER, zOrder)
```

### 8.4. CreateOrUpdateHLine (helper)

```
function CreateOrUpdateHLine(name, price, color, style, width, tooltip):
    if name not exists on chart:
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)
        ObjectSetInteger(name, OBJPROP_COLOR, color)
        ObjectSetInteger(name, OBJPROP_STYLE, style)
        ObjectSetInteger(name, OBJPROP_WIDTH, width)
        ObjectSetInteger(name, OBJPROP_SELECTABLE, false)
        ObjectSetString(name, OBJPROP_TOOLTIP, tooltip)
        CacheAddObject(name, price, color, style, width)
        ApplyVisibilityState(name, true)
        return true   // NEW
    else:
        if cached price differs:
            ObjectSetDouble(name, OBJPROP_PRICE, price)
        if cached color differs:
            ObjectSetInteger(name, OBJPROP_COLOR, color)
        CacheUpdateObject(name, price, color, style, width)
        ApplyVisibilityStateIfUnchangedSkip(name, true)
        return false  // EXISTING
```

---

## 9. مرحله ⑦ — پاکسازی

**هدف:** حذف اشیاء قدیمی که در رندر فعلی تولید نشده‌اند.

### 9.1. الگوریتم CleanupSurplusObjects

```
function CleanupSurplusObjects(prefix, startIdx, maxConsecutiveMiss=6):
    if (customPriceLineDragging and "_Zone_" in prefix):
        return  // حین drag، cleanup متوقف شود (anti-flicker)

    misses = 0
    idx = startIdx
    while misses < maxConsecutiveMiss:
        name = prefix + idx.ToString()
        if name exists on chart:
            CacheRemoveObject(name)
            ObjectDelete(0, name)
            misses = 0
        else:
            misses++
        idx++

    // ۶ miss متوالی = پایان
```

### 9.2. دلیل استفاده از "consecutive misses"

به جای حلقه بی‌نهایت روی همه اشیاء چارت:
- وقتی به ۶ miss پشت‌سر‌هم رسیدیم، یعنی دیگر شیئی از این prefix نیست → توقف
- این کار هزینه را از O(n کل اشیاء چارت) به O(n اشیاء این prefix) کاهش می‌دهد

### 9.3. پاکسازی‌های اضافی

```
CleanupSurplusPipeline(config, maxLogicalStep):
    // زون‌ها
    CleanupSurplusObjects(prefix + modeName + "_Zone_Above_", maxStep + 1)
    CleanupSurplusObjects(prefix + modeName + "_Zone_Below_", maxStep + 1)
    CleanupSurplusObjects(prefix + modeName + "_Zone_Center_", 1)

    // خطوط
    CleanupSurplusObjects(prefix + modeName + "_Above_", maxStep + 1)
    CleanupSurplusObjects(prefix + modeName + "_Below_", maxStep + 1)

    // حذف midpoint legacy
    if exists(prefix + modeName + "_Midpoint_0"):
        ObjectDelete
```

---

## 10. مثال عددی کامل

**تنظیمات:**
- Anchor = `100.00`
- stepSize = `10.00`
- base = `4` (Structure L1 = 4، L2 = 8، L3 = 16، L4 = 32، L5 = 64)
- maxAbove = 17, maxBelow = 17
- zoneHeightPercent = 1.0
- zoneStyle = FILLED

**خروجی Stage 2 (محاسبه خام):**

| step | price | direction | isMidpoint |
|------|-------|-----------|------------|
| 0    | 100.00 | 0 | ✓ |
| 1    | 110.00 | +1 | |
| 2    | 120.00 | +1 | |
| 3    | 130.00 | +1 | |
| 4    | 140.00 | +1 | |
| 5    | 150.00 | +1 | |
| 6    | 160.00 | +1 | |
| 7    | 170.00 | +1 | |
| 8    | 180.00 | +1 | |
| ... | ... | ... | ... |
| -1   | 90.00 | -1 | |
| -2   | 80.00 | -1 | |
| -4   | 60.00 | -1 | ← L1 |
| -8   | 20.00 | -1 | ← L2 |

**خروجی Stage 3 (طبقه‌بندی):**

| step | price | نقش | رنگ |
|------|-------|-----|-----|
| 0    | 100.00 | Midpoint | رنگ Midpoint |
| 1    | 110.00 | Trigger | رنگ Trigger |
| 2    | 120.00 | Trigger | رنگ Trigger |
| 3    | 130.00 | Trigger | رنگ Trigger |
| 4    | 140.00 | Structure L1 | رنگ L1 |
| 5    | 150.00 | Trigger | رنگ Trigger |
| 6    | 160.00 | Trigger | رنگ Trigger |
| 7    | 170.00 | Trigger | رنگ Trigger |
| 8    | 180.00 | Structure L2 | رنگ L2 |
| ... | ... | ... | ... |

**خروجی Stage 4 (ساخت زون):**

| نام زون | midPrice | renderTop | renderBottom |
|---------|----------|-----------|--------------|
| `_Zone_Center_0` | 100.00 | 105.00 | 95.00 |
| `_Zone_Above_1` | 110.00 | 115.00 | 105.00 |
| `_Zone_Above_2` | 120.00 | 125.00 | 115.00 |
| `_Zone_Above_3` | 130.00 | 135.00 | 125.00 |
| `_Zone_Above_4` | 140.00 | 145.00 | 135.00 |
| ... | ... | ... | ... |
| `_Zone_Below_1` | 90.00 | 95.00 | 85.00 |
| `_Zone_Below_2` | 80.00 | 85.00 | 75.00 |

**خروجی Stage 5 (خطوط trigger):**

| نام خط | price | رنگ |
|--------|-------|-----|
| `_Above_1` | 105.00 | Trigger |
| `_Above_2` | 115.00 | Trigger |
| `_Above_3` | 125.00 | Trigger |
| `_Above_4` | 135.00 | L1 |
| `_Above_5` | 145.00 | Trigger |
| ... | ... | ... |
| `_Below_1` | 95.00 | Trigger |
| `_Below_2` | 85.00 | Trigger |

**نمودار بصری نهایی (Anchor=100، بالا تا step=8):**

```
قیمت    180 ─┬─────────┐                  L2
             │   L2    │
       175 ─┤  zone   ├──── line (L2)
             │         │
       170 ─┤         ├──── line (Trigger)
             │         │
       165 ─┤         ├──── line (Trigger)
             │         │
       160 ─┤         ├──── line (Trigger)
             │         │
       155 ─┤         ├──── line (Trigger)
             │         │
       150 ─┤         ├──── line (Trigger)
             │         │
       145 ─┤         ├──── line (Trigger)
             │         │
       140 ─┬─────────┐                  L1
             │   L1    │
       135 ─┤  zone   ├──── line (L1)
             │         │
       130 ─┤         ├──── line (Trigger)
             │         │
       125 ─┤         ├──── line (Trigger)
             │         │
       120 ─┤         ├──── line (Trigger)
             │         │
       115 ─┤         ├──── line (Trigger)
             │         │
       110 ─┬─────────┐                  Step 1
             │  Step1  │
       105 ─┤  zone   ├──── line (Trigger) ← "first zone" اینجاست
             │         │
       100 ─┬─────────┐                  Midpoint
             │  Center │
        95 ─┤  zone   ├──── line (Trigger)
             │         │
        90 ─┬─────────┐                  Step -1
             │  Step-1 │
        85 ─┤  zone   ├──── line (Trigger)
             │         │
        ...
```

---

## 11. حالت‌های خاص

### 11.1. تعداد stepSize صفر
```
if stepSizeCount < 1 → return بدون رسم
if هر stepSize[s] <= 0 → return بدون رسم
```

### 11.2. Anchor بی‌نهایت یا منفی
```
if centerPrice <= 0 → return error
```

### 11.3. هیچ همسایه‌ای برای Midpoint
```
اگر بالا و پایین هر دو خالی:
    neighborDist = 100 × Point  // fallback
```

### 11.4. Trigger غیرفعال
```
zones trigger → ObjectDelete
lines trigger → ObjectSetInteger(OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)
```

### 11.5. Custom Price در حال drag
```
g_customPriceLineDragging = true
→ Cleanup Surplus متوقف می‌شود
→ Throttled cleanup هر 250ms
```

### 11.6. Viewport Culling
```
هر زون/خطی که خارج از محدوده دید باشد:
    inViewport = false
    در رندر نادیده گرفته می‌شود
    ولی geometry آن محاسبه شده (برای تغییر viewport بعدی)
```

### 11.7. Zone Style = LINES
```
به جای OBJ_RECTANGLE:
    دو خط افقی (top + bottom) با HLINE رسم می‌شود
    با همان color و transparency
```

### 11.8. Zone Style = HIDDEN
```
همه زون‌های این مود حذف می‌شوند
خطوط trigger باقی می‌مانند
```

---

## 12. مقایسه با Line-First

| ویژگی | Line-First (مرسوم) | Zone-First (MT5 فعلی) |
|---|---|---|
| موجودیت اصلی | خط | زون |
| ترتیب ساخت | خط → زون | زون → خط |
| موقعیت خط trigger | روی سطح | وسط بین دو زون |
| همپوشانی زون | ممکن است | غیرممکن (اگر %=1) |
| Drift در سطوح بالا | بله (انباشتگی خطا) | خیر |
| قابلیت تست | سخت | آسان (stages pure data) |
| افزودن مود جدید | تغییر در چند جا | فقط Stage 1 |
| سربار حافظه | کم | بیشتر (آرایه‌های intermediate) |
| سرعت رندر | سریع‌تر | کندتر (ولی با cache سریع) |
| دقت بصری | ممکن است drift کند | همیشه دقیق |

---

## پیوست: نگاشت مودها به Pipeline

| مود | stepMode | classifyMode | ویژگی خاص |
|-----|----------|--------------|-----------|
| TH_Level | UNIFORM | STANDARD | سطوح بر اساس TH% |
| SSLS | UNIFORM | ALTERNATING | زوج/فرد → SS/LS |
| M | UNIFORM | MMODE | هر 3 یکی M |
| MEqual | UNIFORM | STANDARD | useStepFilter=false (همه رسم) |
| TP | UNIFORM | STANDARD | Trigger+Pattern |
| Combo | UNIFORM/CUMULATIVE | STANDARD | stepSize ترکیبی |
| Factor | UNIFORM | STANDARD | useObjPropBack=true, zOrder=1 |
| Factor_Harmonic | UNIFORM | STANDARD | مشابه Factor |

---

## پیوست: ساختار Pipeline Executor

```
function ExecutePipeline(
    config,        // SModeConfig
    centerPrice,   // Anchor
    stepSizes[],   // آرایه stepSize
    stepSizeCount,
    stepMode,      // UNIFORM / CUMULATIVE
    classifyMode,  // STANDARD / ALTERNATING / MMODE
    lsFirst,       // فقط برای SSLS
    maxAbove,
    maxBelow
) → SPipelineResult:

    // ① Validation
    if centerPrice <= 0: return error
    for s in stepSizes: if <= 0: return error

    triggerEnabled  = IsTriggerLevelsEnabled()
    baseMultiplier  = GetValidatedBaseMultiplier()
    vpTop, vpBottom = GetViewportBounds()

    // ② Stage 1: Calculate
    rawLevels[] = CalculateLevels(...)
    if rawCount == 0: return error

    // ③ Stage 2: Classify (mode-specific)
    switch classifyMode:
        ALTERNATING → ClassifyLevelsAlternating
        MMODE       → ClassifyLevelsMMode
        STANDARD    → ClassifyLevels

    // ④ Stage 3+4: Build zones + derive lines (merged)
    BuildZonesAndLines(
        classified, config, vpTop, vpBottom,
        zones, zoneCount,
        lines, lineCount
    )

    // ⑤ Stage 5: Render
    RenderZones(zones, zoneCount, config)        // FIRST
    RenderTriggerLines(lines, lineCount, config) // SECOND
    CleanupSurplusPipeline(config, maxStep)      // THIRD

    return { zoneCount, lineCount, success=true }
```

---

**نسخه:** 1.0
**تاریخ:** 2026-06-04
**نویسنده:** الگوریتم استخراج‌شده از `Biotak/LevelPipeline.mqh` (MT5)
**هدف:** مرجع واحد برای درک، بازبینی و مهاجرت منطق رسم سطوح و زون‌ها
