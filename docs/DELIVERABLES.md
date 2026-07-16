# خروجی‌های تحویل — آبتین (نسخه تکمیل‌شده)

## سورس
- سورس کامل Flutter
- لایه Kotlin (`MainActivity.kt`) و Swift (`AppDelegate.swift`) برای:
  - native routing (GraphHopper/Valhalla)
  - Vosk STT
  - Car projection
- قالب AndroidManifest + automotive_app_desc + Info.plist additions

## دارایی‌ها
| فایل | توضیح |
|------|--------|
| `assets/models/car.glb` | مدل سه‌بعدی خودرو |
| `assets/maps/tehran_sample_graph.json` | گراف جاده A* |
| `assets/maps/tehran_sample_pois.json` | POI آفلاین |
| `assets/maps/tehran_sample_manifest.json` | متادیتای بسته |
| `assets/vosk/README.md` | محل مدل فارسی Vosk |
| فونت/آیکون/گیج | bundled |

## قابلیت‌های runtime آفلاین
- A* + smart ETA
- Reroute هنگام انحراف > ۴۵m
- HazardMonitor (دوربین/مدرسه/تونل/...)
- OfflineVoiceGuide + TTS
- VoiceCommand parser (FA)
- AR HUD
- Deep link intake
- Encrypted SQLite favorites/history/settings/hazards

## Build
```bash
flutter create --platforms=android,ios --org ir.abtin --project-name abtin_navigator .
# کپی/ادغام فایل‌های android/ios از این بسته روی خروجی flutter create
flutter pub get && flutter test
flutter build apk --release --split-per-abi --tree-shake-icons
```
یا GitHub Actions → artifact `abtin-apks`.

## آنچه روی دستگاه واقعی باید فعال شود (باینری خارجی)
1. لینک کردن `.so`/framework موتور Valhalla یا GraphHopper و `isEngineReady=true`
2. قرار دادن مدل Vosk فارسی در `assets/vosk` و `isModelReady=true`
3. UI کامل Android Auto / CarPlay روی همان MethodChannel
4. اتصال پلاگین `camera` به `ArNavigationScreen` (منطق HUD آماده است)

تا قبل از آن، کل مسیر محصول با A* محلی + TTS دستگاه + کَش کاشی **قابل دمو و تست** است.
