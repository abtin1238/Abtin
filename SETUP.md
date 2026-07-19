# 🚀 دستورالعمل راه‌اندازی پروژه آبتین ناویگیتور

## پیش‌نیازها
- Flutter SDK 3.3.0 یا بالاتر
- Android Studio یا VS Code
- Git

## مراحل راه‌اندازی

### ۱. کلون کردن پروژه
```bash
git clone [آدرس ریپازیتوری]
cd abtin_navigator
```

### ۲. ساخت فایل‌های اولیه Flutter
```bash
# این دستور پوشه‌های android/ و ios/ و سایر فایل‌های پایه را می‌سازد
flutter create . --org ir.abtin --project-name abtin_navigator
```

### ۳. نصب پکیج‌ها
```bash
flutter pub get
```

### ۴. اجرای Code Generation برای Drift (دیتابیس)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### ۵. دانلود فونت فارسی
- فونت **Vazirmatn** را از [این لینک](https://github.com/rastikerdar/vazirmatn/releases) دانلود کنید
- فایل‌های TTF را در پوشه `assets/fonts/` قرار دهید:
  - `Vazirmatn-Regular.ttf`
  - `Vazirmatn-Medium.ttf`
  - `Vazirmatn-Bold.ttf`
  - `Vazirmatn-ExtraBold.ttf`

### ۶. تنظیمات Android
در فایل `android/app/src/main/AndroidManifest.xml`، محتوای فایل `android_manifest_reference/AndroidManifest_additions.xml` را اضافه کنید:

```xml
<!-- مجوزهای GPS -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Deep Link Support -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="abtin" android:host="navigate" />
</intent-filter>
```

### ۷. اجرای پروژه
```bash
# اجرا روی دستگاه متصل
flutter run

# یا برای debug روی اندروید
flutter run -d android

# یا برای iOS
flutter run -d ios
```

---

## 🎯 ویژگی‌های پیاده‌سازی‌شده

### ✅ GPS و موقعیت‌یابی
- دریافت مجوز خودکار از کاربر
- پیگیری موقعیت real-time
- هموارسازی موقعیت GPS (Exponential Moving Average)
- نمایش سرعت فعلی

### ✅ نقشه سه‌بعدی
- نقشه آنلاین با MapLibre GL
- دوربین سه‌بعدی (tilt, bearing)
- حالت دنبال‌کردن خودرو
- مارکر خودرو/پیکان

### ✅ مسیریابی
- محاسبه مسیر با OSRM API
- رسم خط مسیر روی نقشه
- دستورات پیچ‌به‌پیچ به فارسی
- نمایش فاصله و زمان باقیمانده
- تشخیص خودکار رسیدن به مقصد

### ✅ Deep Linking
- پشتیبانی از لینک `abtin://navigate?lat=35.6997&lng=51.3380&label=میدان+آزادی`
- دریافت مقصد از اپ‌های دیگر (مثل اسنپ)

### ✅ دیتابیس محلی
- ذخیره مکان‌های علاقه‌مندی با SQLite (Drift)
- مدیریت تاریخچه جستجوها

### ✅ UI/UX
- طراحی RTL فارسی
- تم تیره با گلس‌مورفیسم
- انیمیشن‌های روان
- رابط کاربری بومی و حرفه‌ای

---

## 🔧 تنظیمات پیشرفته

### استفاده از Style نقشه سفارشی
در فایل `lib/features/map/presentation/home_screen.dart`، خط زیر را ویرایش کنید:

```dart
static const String _demoStyleUrl = 'https://demotiles.maplibre.org/style.json';
```

می‌توانید از سرویس‌های زیر استفاده کنید:
- [MapTiler](https://www.maptiler.com/)
- [Stadia Maps](https://stadiamaps.com/)
- سرور Vector Tile اختصاصی

### استفاده از سرور مسیریابی اختصاصی
در فایل `lib/features/routing/data/routing_service.dart`، URL زیر را تغییر دهید:

```dart
static const String _baseUrl = 'https://router.project-osrm.org';
```

برای نصب سرور OSRM یا Valhalla خودتان:
- [راهنمای نصب OSRM](https://github.com/Project-OSRM/osrm-backend)
- [راهنمای نصب Valhalla](https://github.com/valhalla/valhalla)

---

## 📝 نکات مهم

### ۱. محدودیت سرور عمومی OSRM
سرور عمومی OSRM برای تست مناسب است اما برای Production:
- محدودیت تعداد درخواست دارد
- ممکن است کند باشد
- از سرور اختصاصی استفاده کنید

### ۲. مجوزهای iOS
برای iOS، باید توضیحات مجوزها را در `ios/Runner/Info.plist` اضافه کنید:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>برای نمایش موقعیت شما روی نقشه و مسیریابی</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>برای پیگیری مسیر در حین مسیریابی</string>
```

### ۳. رندر مدل سه‌بعدی GLB
فایل `assets/models/bmw_i8.glb` در پروژه موجود است اما رندر آن روی نقشه
نیاز به یک لایه Native دارد. در حال حاضر، یک آیکون دوبعدی جایگزین نمایش داده می‌شود.

---

## 🐛 عیب‌یابی

### خطای "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### خطای "No implementation found for method"
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

### خطای مربوط به Drift/SQLite
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### مشکل در نمایش فونت فارسی
- مطمئن شوید فایل‌های TTF در `assets/fonts/` قرار دارند
- `flutter clean` و `flutter pub get` را اجرا کنید

---

## 📱 تست روی دستگاه واقعی

برای تست GPS و مسیریابی، حتماً روی دستگاه واقعی تست کنید، نه شبیه‌ساز.

### اندروید
```bash
# فهرست دستگاه‌های متصل
flutter devices

# اجرا روی دستگاه مشخص
flutter run -d [device-id]
```

### iOS
```bash
# اجرا روی iPhone متصل
flutter run -d ios
```

---

## 🎉 تست Deep Link

برای تست deep link از ترمینال:

### اندروید
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "abtin://navigate?lat=35.6997&lng=51.3380&label=میدان+آزادی" \
  ir.abtin.abtin_navigator
```

### iOS
از Safari باز کنید:
```
abtin://navigate?lat=35.6997&lng=51.3380&label=میدان+آزادی
```

---

## 📧 پشتیبانی
در صورت بروز مشکل، issue باز کنید یا با تیم توسعه تماس بگیرید.

---

**نسخه**: 0.1.0+1  
**آخرین به‌روزرسانی**: فاز ۳ - مسیریابی واقعی ✅
