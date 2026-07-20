# آبتین (Abtin Navigator) — گزارش بررسی و TODO اولویت‌بندی‌شده

> بر اساس بررسی کد فعلی پروژه (Flutter, ۲۹ فایل Dart, ~۳۷۰۰ خط) و اسپک هدف (Prompt.txt)

---

## خلاصه وضعیت فعلی

| حوزه | وضعیت |
|---|---|
| موتور نقشه (MapLibre Native) | ✅ درست انتخاب شده |
| GPS Service (EMA Smoothing) | ⚠️ ساده، نه Kalman |
| Routing | ❌ کاملاً Online (OSRM عمومی) |
| Offline Map Tiles | ⚠️ فقط بصری، بدون دیتای POI/گراف جاده |
| Search | ❌ فقط UI، داده هاردکد |
| خودروی GLB | ⚠️ انتخاب‌گر آماده، رندر سه‌بعدی واقعی نیست |
| Navigation Camera (۳ حالته) | ❌ پیاده نشده |
| دیتابیس محلی (Drift) | ✅ SavedPlaces + RouteHistory آماده |
| Deep Link | ✅ پیاده، فقط رجیستر AndroidManifest مونده |
| مجوز GPS خودکار | ✅ کامل |
| معماری (Feature-based + Riverpod) | ✅ پایه خوب |
| README / تست / iOS | ❌ هیچ‌کدام موجود نیست |
| Workflow خطرناک (`Deletall.yml`) | 🚩 کل ریپو رو پاک می‌کنه |

---

## TODO — اولویت‌بندی‌شده

### 🔴 اولویت ۱ — زیرساخت (پیش‌نیاز همه‌چیز)
اینا باید اول انجام بشن چون Search، Routing، و Map Matching همه به‌شون وابسته‌ن.

- [ ] دانلود و پارس PBF خام OSM برای هر استان (نه فقط style tile بصری)
- [ ] ذخیره‌ی POI، نام خیابان‌ها، و گراف جاده در دیتابیس محلی (Drift)
- [ ] تصمیم نهایی موتور Routing آفلاین — **BRouter پیشنهادی** (سبک‌تر، embed ساده‌تر در Kotlin) در برابر Valhalla (قوی‌تر ولی سنگین‌تر)
- [ ] حذف یا محدود کردن دسترسی اجرای workflow خطرناک `Deletall.yml`

### 🟠 اولویت ۲ — Routing و GPS واقعی
- [ ] جایگزینی OSRM آنلاین با موتور آفلاین انتخاب‌شده (native، از طریق Kotlin + Platform Channel/FFI)
- [ ] پیاده‌سازی Turn-by-Turn, Rerouting, Off-Route Detection روی موتور جدید
- [ ] ارتقای GPS Service از EMA ساده به Kalman Filter
- [ ] پیاده‌سازی Map Matching (Snap to Road) روی گراف جاده‌ی مرحله ۱

### 🟡 اولویت ۳ — اتصال UI موجود به داده واقعی (بدون تغییر ظاهر)
- [ ] وصل صفحه‌ی جستجو به دیتابیس محلی (حذف مقادیر هاردکد مثل «میدان آزادی»)
- [ ] وصل صفحه‌ی مسیرها (Routes) به جدول RouteHistory موجود در دیتابیس
- [ ] پیاده‌سازی موتور TTS واقعی برای Voice Settings

### 🟢 اولویت ۴ — تجربه‌ی Navigation
- [ ] ساخت سه‌حالته Camera: Navigation Mode / Overview Mode / Free Explore
- [ ] بازگشت خودکار دوربین به Navigation Mode بعد از عدم تعامل کاربر
- [ ] رندر واقعی مدل سه‌بعدی خودرو (GLB) با لایه Native (Filament/SceneView) + چرخش بر اساس GPS Heading

### 🔵 اولویت ۵ — تکمیل نقشه و پرداخت نهایی
- [ ] لایه‌ی ساختمان‌های سه‌بعدی (fill-extrusion)
- [ ] بررسی سازگاری نسخه‌ی `maplibre_gl` فعلی با style-spec سه‌بعدی کامل (احتمال نیاز به آپدیت نسخه)
- [ ] رجیستر intent-filter در AndroidManifest برای فعال‌سازی کامل Deep Link (فایل مرجع آماده است)

### ⚪ اولویت ۶ — کیفیت و مستندسازی
- [ ] نوشتن README (نصب، اجرا، معماری)
- [ ] نوشتن تست واحد حداقل برای RoutingService و LocationService
- [ ] بهینه‌سازی برای گوشی‌های میان‌رده (Isolate برای پردازش سنگین Flutter، Native Thread برای سنگین Native)
- [ ] بررسی و رفع Memory Leak احتمالی، حذف Rebuild غیرضروری
- [ ] (اختیاری/آینده) پشتیبانی iOS

---

## نکات فنی مهم برای تصمیم‌گیری بعدی

1. **موتور Routing**: BRouter برای تعادل بین کیفیت، سادگی embed در Kotlin، و حجم داده روی گوشی میان‌رده توصیه می‌شود. OSRM آفلاین برای embed مستقیم در اپ موبایل عملاً مناسب نیست.
2. **دیتای Offline**: تایل بصری فعلی (OpenFreeMap) کافی نیست — باید PBF خام OSM هم دانلود و در دیتابیس محلی پردازش شود.
3. **ترتیب اجرا مهم است**: Search و Map Matching هر دو به گراف OSM محلی وابسته‌اند، پس زیرساخت داده باید قبل از این دو تکمیل شود.
