# راهنمای Build آبتین (CI-ready)

پروژه‌ی Android (`android/`) از قبل کامل و self-contained است — applicationId،
namespace، AndroidManifest واقعی، minSdk=24، multiDex، jniLibs legacy
packaging، proguard-rules، آیکون لانچر و تم اسپلش همه از قبل داخل ریپو
commit شده‌اند. **دیگر نیازی به اجرای `flutter create` یا اسکریپت‌های
merge‌کننده نیست** — فقط کافی است `flutter pub get` بزنید و build بگیرید.

## GitHub Actions (پیشنهادی)
1. همین ریپو را push کنید روی `main` یا `master`
2. تب **Actions** → workflow **Build Abtin APK**
3. Artifact: **`abtin-apks`** (armeabi-v7a / arm64-v8a / x86_64)

اگر workflow قبلاً شامل مراحل `flutter create` و
`tool/ci_prepare_android.sh` بود، آن دو مرحله را حذف کنید — چون الان
`android/` از قبل نهایی است و اجرای دوباره‌ی آن‌ها لازم نیست (و در بهترین
حالت بی‌اثر، در بدترین حالت باعث بازنویسی فایل‌های نهایی می‌شود).

Workflow پیشنهادی:
- Flutter **3.24.5** + Java 17
- `flutter pub get`
- `dart run flutter_launcher_icons` (اختیاری — آیکون‌ها از قبل ساخته شده‌اند، فقط برای refresh)
- unit tests هسته آفلاین
- `flutter build apk --release --split-per-abi --tree-shake-icons`
- **بدون minify/R8** (پایدارتر روی CI؛ در `android/app/build.gradle` تنظیم شده)

## بیلد محلی
```bash
flutter pub get
flutter build apk --release --split-per-abi --tree-shake-icons
```
همین. `android/local.properties` را خودِ Flutter tooling (یا Android
Studio) در همین مرحله می‌سازد؛ نیازی به دست‌زدن به آن نیست.

### اجرای تست‌های واحد به‌صورت محلی (لینوکس)
پکیج `sqlite3` برای اجرای `flutter test` روی هاست (نه روی دستگاه/شبیه‌ساز) به
کتابخانه‌ی بومی `libsqlite3` نیاز دارد که با نصب پیش‌فرض Ubuntu همراه نیست:
```bash
sudo apt-get update && sudo apt-get install -y libsqlite3-dev
flutter test test/routing_engine_test.dart test/offline_complete_test.dart
```
(روی macOS معمولاً از قبل موجود است؛ روی ویندوز باید `sqlite3.dll` را در PATH
قرار دهید.) این مرحله در GitHub Actions به‌صورت خودکار انجام می‌شود.

### ساختار `android/` (از قبل کامل)
| فایل | نقش |
|---|---|
| `android/settings.gradle` | AGP 8.3.0 + Kotlin 1.8.22، هم‌راستا با Gradle wrapper 8.7 |
| `android/build.gradle` | تنظیمات root project |
| `android/gradle.properties` | AndroidX/Jetifier |
| `android/app/build.gradle` | applicationId=`ir.abtin.navigator`، minSdk=24، multiDex، jniLibs legacy packaging، proguard |
| `android/app/src/main/AndroidManifest.xml` | مجوزها، دیپ‌لینک‌ها، متادیتای Android Auto، **`flutterEmbedding=2`** |
| `android/app/src/main/kotlin/ir/abtin/navigator/MainActivity.kt` | کانال‌های routing/vosk/car_projection |
| `android/app/src/main/res/values*/styles.xml` + `drawable*/launch_background.xml` | تم/اسپلش |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | آیکون لانچر (تولیدشده از `assets/icons/app_icon.png`) |
| `android/app/proguard-rules.pro` | قوانین R8 (کپی از `build_config/`) |

اگر بعداً خواستید آیکون را عوض کنید، `assets/icons/app_icon.png` را جایگزین
کنید و `dart run flutter_launcher_icons` را اجرا کنید تا mipmapها رفرش شوند.

## اگر pub get روی intl خطا داد
`pubspec.yaml` از قبل `dependency_overrides: intl: 0.19.0` دارد (سازگار با Flutter 3.24).

## اگر SQLCipher روی دستگاه مشکل داد
- minSdk ≥ 24 ✅ (از قبل در `android/app/build.gradle`)
- `packagingOptions.jniLibs.useLegacyPackaging = true` ✅ (همان‌طور)

## iOS (محلی، خارج از CI)
CI فقط APK اندروید می‌سازد. پروژه‌ی iOS در این ریپو کامل نیست (فقط
`AppDelegate.swift` سفارشی و منابع کمکی). برای بیلد iOS محلی:
```bash
flutter create --platforms=ios .
```
این دستور فقط اسکلت `ios/` را کامل می‌کند (بدون دست‌زدن به `android/`).
سپس کلیدهای `ios/Runner/Info.plist.additions.xml` (مجوز موقعیت/میکروفون،
CFBundleURLTypes برای `abtin://`) را دستی داخل `ios/Runner/Info.plist` ادغام
کنید؛ `ios/Runner/AppDelegate.swift` سفارشی از قبل در مسیر درست قرار دارد و
توسط `flutter create` بازنویسی نمی‌شود.

## دانلود نقشه استانی
تنظیمات → دانلود نقشهٔ آفلاین → تب «استان‌های ایران»
(کاشی نقشه؛ گراف مسیر نمونه تهران bundled است)
