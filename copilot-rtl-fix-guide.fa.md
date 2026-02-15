# راهنمای کامل Copilot RTL Fix

این راهنما مربوط به فایل `copilot-rtl-fix.js` است.

هدف اسکریپت:
- راست‌چین کردن بخش‌های متنی چت
- حفظ خوانایی متن‌های ترکیبی فارسی/انگلیسی
- دست‌نخوردن نمایش بلاک‌های کد
- خودترمیم (Self-heal) پس از رندر مجدد UI
- پشتیبانی از `Shadow DOM` و `iframe` (در صورت same-origin)

---

## 1) شروع سریع

1. محتوای `copilot-rtl-fix.js` را در DevTools Console اجرا کنید.
2. API جهانی آماده می‌شود:
   - `window.CopilotRTLFix`

پیش‌فرض‌ها:
- `autoApply: true`
- `autoHeal: true`
- `preset: "balanced"`

---

## 2) API اصلی

### کنترل اجرا
- `CopilotRTLFix.apply()`
  - اعمال/بازاعمال استایل
- `CopilotRTLFix.remove()`
  - حذف استایل‌ها و توقف observer
- `CopilotRTLFix.toggle(true | false)`
  - روشن/خاموش سریع
- `CopilotRTLFix.uninstall()`
  - حذف کامل (استایل + observer + API)

### تنظیمات
- `CopilotRTLFix.update(partialConfig)`
  - اعمال تنظیمات دلخواه
- `CopilotRTLFix.setPreset("safe" | "balanced" | "aggressive")`
  - تغییر حالت آماده
- `CopilotRTLFix.listPresets()`
  - لیست presetها

### Observer
- `CopilotRTLFix.startObserver()`
- `CopilotRTLFix.stopObserver()`

### ذخیره تنظیمات
- `CopilotRTLFix.saveConfig()`
- `CopilotRTLFix.loadSavedConfig()`
- `CopilotRTLFix.restoreConfig()`
- `CopilotRTLFix.clearSavedConfig()`

### پایش وضعیت
- `CopilotRTLFix.status()`
  - وضعیت کلی (observer, healCount, شمارنده‌ها)
- `CopilotRTLFix.healthCheck()`
  - گزارش سلامت و پوشش (main style / shadow / iframe)

---

## 3) Presetها

### `balanced` (پیش‌فرض)
متعادل برای اکثر سناریوها.

### `safe`
کم‌ریسک‌تر و سبک‌تر:
- حساسیت کمتر
- مصرف کمتر
- `supportsIframes: false`

### `aggressive`
حساس‌تر برای UIهای خیلی پویا:
- debounce کمتر
- سقف پردازش بالاتر
- مناسب وقتی UI مدام عوض می‌شود

---

## 4) مهم‌ترین گزینه‌های Config

- `styleId`: شناسه style اصلی
- `autoApply`: اعمال خودکار پس از لود
- `autoHeal`: فعال بودن خودترمیم
- `observeSubtree`: مانیتور subtree
- `supportsShadowDom`: پوشش shadow root
- `supportsIframes`: پوشش iframeهای قابل دسترسی
- `enableBidiFallback`: fallback برای `unicode-bidi`
- `persistConfig`: ذخیره تنظیمات در `localStorage`
- `storageKey`: کلید ذخیره تنظیمات
- `observerDebounceMs`: تاخیر self-heal
- `maxMutationsPerWindow`: حد burst mutation
- `mutationBurstWindowMs`: بازه burst
- `maxHealsPerMinute`: سقف heal در دقیقه
- `watchHints`: hintها برای تشخیص mutation مهم
- `rules`: قوانین CSS

---

## 5) سناریوهای آماده

### فقط فعال‌سازی سریع
- `CopilotRTLFix.apply()`

### تغییر به حالت سبک
- `CopilotRTLFix.setPreset("safe")`

### پایدارسازی تنظیمات برای دفعات بعد
- `CopilotRTLFix.update({ persistConfig: true })`
- `CopilotRTLFix.saveConfig()`

### تست سلامت کامل
- `CopilotRTLFix.healthCheck()`

### خاموش‌سازی موقت
- `CopilotRTLFix.toggle(false)`

### حذف کامل
- `CopilotRTLFix.uninstall()`

---

## 6) محدودیت‌های طبیعی

- iframeهای cross-origin به دلایل امنیتی قابل دسترسی نیستند.
- اگر کلاس‌های داخلی UI در نسخه‌های آینده VS Code/Copilot تغییر بزرگ کند، ممکن است نیاز به تنظیم `watchHints` یا `rules` باشد.

---

## 7) عیب‌یابی سریع

### مشکل: RTL اعمال نشده
1. `CopilotRTLFix.status()` را بررسی کنید.
2. اگر `hasStyleElement` برابر false بود: `CopilotRTLFix.apply()`
3. اگر `autoHeal` روشن است ولی observer فعال نیست: `CopilotRTLFix.startObserver()`

### مشکل: روی کدها به‌هم‌ریختگی
- `preset` را روی `safe` بگذارید.
- در صورت نیاز، `rules.inlineCodeSafety` و `rules.blockCodeSafety` را سفارشی کنید.

### مشکل: مصرف بالا
- `observerDebounceMs` را بیشتر کنید (مثلاً 120 تا 200)
- `maxHealsPerMinute` را کمتر کنید
- از preset `safe` استفاده کنید

---

## 8) نسخه و نگهداری

- این راهنما برای نسخه hardened فعلی `copilot-rtl-fix.js` نوشته شده است.
- در صورت توسعه اسکریپت، این فایل را همزمان آپدیت کنید تا تیم دچار دوباره‌کاری نشود.
