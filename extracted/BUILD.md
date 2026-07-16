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
flutter pub get
flutter test test/routing_engine_test.dart test/offline_complete_test.dart
flutter build apk --release --split-per-abi --tree-shake-icons
```

## اگر pub get روی intl خطا داد
`pubspec.yaml` از قبل `dependency_overrides: intl: 0.19.0` دارد (سازگار با Flutter 3.24).

## اگر SQLCipher روی دستگاه مشکل داد
- minSdk ≥ 24
- `packagingOptions.jniLibs.useLegacyPackaging = true`

## دانلود نقشه استانی
تنظیمات → دانلود نقشهٔ آفلاین → تب «استان‌های ایران»
(کاشی نقشه؛ گراف مسیر نمونه تهران bundled است)
