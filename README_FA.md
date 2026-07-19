# 🚗 آبتین ناویگیتور

<div dir="rtl">

> مسیریاب هوشمند آفلاین سه‌بعدی با Flutter

یک اپلیکیشن مسیریابی حرفه‌ای و کامل با GPS واقعی، نقشه سه‌بعدی، و دستورات پیچ‌به‌پیچ به زبان فارسی.

[![Flutter](https://img.shields.io/badge/Flutter-3.3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## ✨ ویژگی‌ها

<div dir="rtl">

### 🗺️ نقشه و GPS
- نقشه سه‌بعدی آنلاین با MapLibre GL
- پیگیری موقعیت real-time با GPS
- هموارسازی موقعیت و جهت (Exponential Moving Average)
- نمایش سرعت فعلی
- حالت دنبال‌کردن خودرو

### 🧭 مسیریابی
- محاسبه مسیر با OSRM API
- رسم خط مسیر روی نقشه
- دستورات پیچ‌به‌پیچ به فارسی
- نمایش فاصله و زمان باقیمانده
- پیگیری خودکار پیشرفت در مسیر
- تشخیص رسیدن به مقصد

### 📍 انتخاب مقصد
- انتخاب مقصد با تپ روی نقشه
- جستجوی مکان
- ذخیره مکان‌های علاقه‌مندی
- Deep linking از اپ‌های دیگر

### 🎨 رابط کاربری
- طراحی RTL فارسی
- تم تیره با گلس‌مورفیسم
- انیمیشن‌های روان
- کامپوننت‌های بومی و حرفه‌ای

### 💾 دیتابیس محلی
- ذخیره مکان‌های علاقه‌مندی با SQLite (Drift)
- کش مسیرها
- تاریخچه جستجوها

</div>

---

## 📸 اسکرین‌شات‌ها

<div dir="rtl">

_(اسکرین‌شات‌های اپ را اینجا قرار دهید)_

</div>

---

## 🚀 نصب و راه‌اندازی

<div dir="rtl">

### پیش‌نیازها
```bash
Flutter SDK 3.3.0+
Android Studio یا VS Code
Git
```

### مراحل نصب

#### ۱. کلون پروژه
```bash
git clone https://github.com/your-username/abtin-navigator.git
cd abtin-navigator
```

#### ۲. ساخت فایل‌های Flutter
```bash
flutter create . --org ir.abtin --project-name abtin_navigator
```

#### ۳. نصب پکیج‌ها
```bash
flutter pub get
```

#### ۴. Code Generation
```bash
dart run build_runner build --delete-conflicting-outputs
```

#### ۵. دانلود فونت فارسی
فونت [Vazirmatn](https://github.com/rastikerdar/vazirmatn) را دانلود کرده و در `assets/fonts/` قرار دهید.

#### ۶. اجرای اپ
```bash
flutter run
```

برای راهنمای کامل، فایل [SETUP.md](SETUP.md) را مطالعه کنید.

</div>

---

## 📁 ساختار پروژه

<div dir="rtl">

```
lib/
├── core/                       # هسته اصلی
│   ├── database/              # دیتابیس SQLite
│   ├── deep_link/             # سرویس Deep Link
│   ├── permissions/           # مدیریت مجوزها
│   ├── router/                # مسیریابی داخلی اپ
│   └── theme/                 # تم و رنگ‌ها
├── features/                  # فیچرها
│   ├── gps/                   # GPS و موقعیت‌یابی
│   ├── map/                   # نقشه و نمایش
│   ├── routing/               # مسیریابی
│   ├── search/                # جستجو
│   ├── saved_places/          # مکان‌های ذخیره‌شده
│   ├── routes/                # مسیرهای پیشنهادی
│   ├── settings/              # تنظیمات
│   └── vehicle/               # مارکر خودرو
├── shared/                    # کامپوننت‌های مشترک
│   └── widgets/
└── main.dart                  # نقطه ورود
```

</div>

---

## 🛠️ تکنولوژی‌ها

<div dir="rtl">

- **Framework**: Flutter 3.3.0+
- **زبان**: Dart 3.0+
- **State Management**: Riverpod 2.5.1
- **نقشه**: MapLibre GL 0.20.0
- **مسیریابی**: GoRouter 14.2.0
- **دیتابیس**: Drift 2.18.0 (SQLite)
- **GPS**: Geolocator 12.0.0
- **مجوزها**: Permission Handler 11.3.1
- **Deep Link**: App Links 6.1.1
- **HTTP**: http 1.2.0

</div>

---

## 🔌 API‌ها

<div dir="rtl">

### سرویس مسیریابی
پروژه از OSRM API رایگان استفاده می‌کند. برای Production:

```dart
// lib/features/routing/data/routing_service.dart
static const String _baseUrl = 'https://your-osrm-server.com';
```

گزینه‌های جایگزین:
- [OSRM](https://github.com/Project-OSRM/osrm-backend) (خودتان نصب کنید)
- [Valhalla](https://github.com/valhalla/valhalla) (پیشرفته‌تر)
- [MapBox Directions](https://www.mapbox.com/) (پولی)

### Style نقشه
برای نقشه شب‌رنگ حرفه‌ای:

```dart
// lib/features/map/presentation/home_screen.dart
static const String _demoStyleUrl = 'https://api.maptiler.com/...';
```

</div>

---

## 🧪 تست

<div dir="rtl">

### تست روی دستگاه واقعی
```bash
flutter run -d android
flutter run -d ios
```

### تست Deep Link
```bash
# اندروید
adb shell am start -W -a android.intent.action.VIEW \
  -d "abtin://navigate?lat=35.6997&lng=51.3380&label=میدان+آزادی" \
  ir.abtin.abtin_navigator
```

</div>

---

## 📋 TODO

<div dir="rtl">

- [ ] نقشه آفلاین (دانلود PBF/PMTiles استانی)
- [ ] Map Matching (چسباندن به جاده)
- [ ] Kalman Filter برای GPS دقیق‌تر
- [ ] رندر مدل GLB سه‌بعدی خودرو
- [ ] Voice Navigation (دستورات صوتی)
- [ ] مسیریابی چند نقطه‌ای
- [ ] ترافیک real-time
- [ ] حالت شب/روز خودکار

</div>

---

## 🤝 مشارکت

<div dir="rtl">

مشارکت‌ها خوش‌آمد هستند! لطفاً:

1. Fork کنید
2. Branch جدید بسازید (`git checkout -b feature/amazing-feature`)
3. تغییرات را Commit کنید (`git commit -m 'Add amazing feature'`)
4. Push کنید (`git push origin feature/amazing-feature`)
5. Pull Request باز کنید

</div>

---

## 📄 لایسنس

<div dir="rtl">

این پروژه تحت لایسنس MIT منتشر شده است - فایل [LICENSE](LICENSE) را مشاهده کنید.

</div>

---

## 👨‍💻 سازندگان

<div dir="rtl">

- **نام شما** - توسعه‌دهنده اصلی

</div>

---

## 🙏 تشکر

<div dir="rtl">

- [MapLibre](https://maplibre.org/) - نقشه اوپن‌سورس
- [OSRM](http://project-osrm.org/) - موتور مسیریابی
- [Vazirmatn](https://github.com/rastikerdar/vazirmatn) - فونت فارسی

</div>

---

## 📞 پشتیبانی

<div dir="rtl">

اگر مشکلی دارید یا سوالی دارید:
- Issue باز کنید
- ایمیل بزنید: your-email@example.com
- [مستندات کامل](SETUP.md) را بخوانید

</div>

---

<div align="center" dir="rtl">

**ساخته شده با ❤️ با Flutter**

⭐ اگر این پروژه را دوست داشتید، یک ستاره بدهید!

</div>
