# آبتین — مسیریاب هوشمند آفلاین 🧭
### Aabtin — Offline Smart Navigator (Flutter)

اپلیکیشن مسیریاب **کاملاً آفلاین** با Flutter، معماری Clean Architecture و مدیریت وضعیت Riverpod.  
رابط کاربری RTL فارسی، تم تیره/فیروزه‌ای، برندینگ «آبتین».

---

## ✅ وضعیت پیاده‌سازی (نسخه تکمیل‌شده)

| بخش | وضعیت | مسیر |
|---|---|---|
| Clean Architecture + Riverpod | ✅ | `lib/core`, `lib/features` |
| تم روشن/تیره + RTL + Vazirmatn | ✅ | `core/theme` |
| نوار ناوبری پایین شیشه‌ای (۵ تب) | ✅ | `core/widgets/app_bottom_nav.dart` |
| موتور A* آفلاین + چندحالته | ✅ | `features/routing/data/offline_routing_engine.dart` |
| بارگذاری گراف از JSON asset | ✅ | `features/maps/data/graph_asset_loader.dart` |
| پل نیتیو GraphHopper/Valhalla | ✅ قرارداد + Kotlin/Swift | `core/native`, `MainActivity.kt`, `AppDelegate.swift` |
| مسیریابی offline-first | ✅ | `core/services/routing_service.dart` |
| Reroute + Hazard + Voice در ناوبری | ✅ | `navigation_controller.dart` |
| Kalman + Dead Reckoning + GPS watchdog | ✅ | `location_service`, `navigation_controller` |
| SQLite رمزنگاری‌شده (SQLCipher) + Migration | ✅ | `core/database/app_database.dart` |
| علاقه‌مندی‌ها روی DB | ✅ | `features/favorites` |
| جستجوی POI آفلاین | ✅ | `offline_search_service.dart` |
| Lane Guidance UI | ✅ | `lane_guidance.dart` |
| AR Navigation HUD | ✅ | `features/ar/.../ar_navigation_screen.dart` |
| Vosk STT API + فرمان صوتی فارسی | ✅ | `vosk_stt_service.dart` |
| مشاور مسیر هوشمند آفلاین | ✅ | `smart_route_advisor.dart` |
| Deep Link (geo/abtin/maps) | ✅ | `deeplink_parser.dart` + `main.dart` |
| Android Auto / CarPlay bridge | ✅ قرارداد + manifest | `car_projection.dart` |
| بسته نقشه نمونه + گراف JSON | ✅ | `assets/maps/` |
| مدل خودرو GLB | ✅ | `assets/models/car.glb` |
| GitHub Actions APK | ✅ | `.github/workflows/build-apk.yml` |
| Unit / Widget tests | ✅ | `test/` |

---

## اجرای سریع
```bash
flutter create --platforms=android,ios --org ir.abtin --project-name abtin_navigator .
# ادغام MainActivity.kt / AppDelegate.swift / AndroidManifest template
flutter pub get
flutter test
flutter run
```
جزئیات: [BUILD.md](./BUILD.md) · [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) · [docs/DELIVERABLES.md](./docs/DELIVERABLES.md)

---

## اصل طلایی
> مسیریابی، جستجو، علاقه‌مندی، هشدار، reroute و راهنمای صوتی **بدون شبکه** کار می‌کنند.  
> شبکه فقط برای دانلود اولیهٔ کاشی نقشه اختیاری است.  
> باینری GraphHopper/Valhalla و مدل Vosk قابل اتصال از طریق MethodChannel هستند.

---

## برند
- فیروزه‌ای: `#00E5D0` · طلایی: `#D4AF37` · پس‌زمینه تیره: `#0A0E1A`
