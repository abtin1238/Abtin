# راهنمای Build آبتین (CI-ready)

## GitHub Actions (پیشنهادی)
1. همین ریپو را push کنید روی `main` یا `master`
2. تب **Actions** → workflow **Build Abtin APK**
3. Artifact: **`abtin-apks`** (armeabi-v7a / arm64-v8a / x86_64)

Workflow:
- Flutter **3.24.5** + Java 17
- `flutter create` برای ساخت `android/`/`ios/`
- `minSdk = 24`
- unit tests هسته آفلاین
- `flutter build apk --release --split-per-abi`
- **بدون minify/R8** (پایدارتر روی CI)

## بیلد محلی
```bash
flutter create --platforms=android,ios --org ir.abtin --project-name abtin_navigator .
bash tool/ci_prepare_android.sh   # merge applicationId/manifest/gradle واقعی — الزامی
flutter pub get
flutter build apk --release --split-per-abi --tree-shake-icons
```

### اجرای تست‌های واحد به‌صورت محلی (لینوکس)
پکیج `sqlite3` برای اجرای `flutter test` روی هاست (نه روی دستگاه/شبیه‌ساز) به
کتابخانه‌ی بومی `libsqlite3` نیاز دارد که با نصب پیش‌فرض Ubuntu همراه نیست:
```bash
sudo apt-get update && sudo apt-get install -y libsqlite3-dev
flutter test test/routing_engine_test.dart test/offline_complete_test.dart
```
(روی macOS معمولاً از قبل موجود است؛ روی ویندوز باید `sqlite3.dll` را در PATH
قرار دهید.) این مرحله در GitHub Actions به‌صورت خودکار انجام می‌شود.

### چرا `tool/ci_prepare_android.sh` الزامی است
چون `pubspec.yaml` از قبل وجود دارد، دستور `flutter create` نام پروژه را از
همان pubspec می‌خواند، نه از `--project-name` — در نتیجه applicationId تولیدی
برابر `ir.abtin.abtin_navigator` می‌شود، در حالی‌که کد نیتیو واقعی (کانال‌های
routing/vosk/car_projection) در `MainActivity.kt` با پکیج `ir.abtin.navigator`
نوشته شده. `AndroidManifest.xml.template` (مجوزها، دیپ‌لینک‌ها، متادیتای
Android Auto) و `build.gradle.snippet` (minSdk، multiDex، jniLibs) هم به‌صورت
پیش‌فرض هرگز ادغام نمی‌شوند. اسکریپت `tool/ci_prepare_android.sh` این سه مورد
را به‌صورت خودکار روی خروجی `flutter create` اعمال می‌کند تا اپلیکیشنِ ساخته‌شده
واقعاً همان کدِ نیتیوِ داخل ریپو را اجرا کند، نه استاب خالی.

## اگر pub get روی intl خطا داد
`pubspec.yaml` از قبل `dependency_overrides: intl: 0.19.0` دارد (سازگار با Flutter 3.24).

## اگر SQLCipher روی دستگاه مشکل داد
- minSdk ≥ 24 (توسط `tool/ci_prepare_android.sh` تنظیم می‌شود)
- `packagingOptions.jniLibs.useLegacyPackaging = true` (همان‌طور)

## iOS (محلی، خارج از CI)
CI فقط APK اندروید می‌سازد. برای بیلد iOS محلی، بعد از `flutter create` باید
کلیدهای `ios/Runner/Info.plist.additions.xml` (مجوز موقعیت/میکروفون،
CFBundleURLTypes برای `abtin://`) را دستی داخل `ios/Runner/Info.plist` ادغام
کنید؛ `ios/Runner/AppDelegate.swift` سفارشی از قبل در مسیر درست قرار دارد و
توسط `flutter create` بازنویسی نمی‌شود.

## دانلود نقشه استانی
تنظیمات → دانلود نقشهٔ آفلاین → تب «استان‌های ایران»
(کاشی نقشه؛ گراف مسیر نمونه تهران bundled است)
