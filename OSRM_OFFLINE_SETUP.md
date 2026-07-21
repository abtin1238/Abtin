## 🚀 راهنمای نصب و استفاده OSRM آفلاین

این راهنما شامل نحوه‌ی نصب سرور OSRM محلی و استفاده آن از اپ Flutter است.

---

## 📋 پیش‌نیازها

- **Docker** (توصیه می‌شود برای نصب سریع)
- یا **Node.js** و **npm** برای نصب مستقیم
- حداقل **2 GB** فضای خالی برای داده‌های یک استان
- **حداقل 1 GB RAM** برای اجرای سرور

---

## ✅ روش 1: استفاده Docker (توصیه‌شده)

### مرحله 1: نصب Docker

**برای Windows/Mac:**
- دانلود [Docker Desktop](https://www.docker.com/products/docker-desktop)

**برای Linux:**
```bash
sudo apt-get install docker.io
```

### مرحله 2: دانلود و اجرای OSRM

```bash
# دانلود تصویر OSRM
docker pull osrm/osrm-backend

# دانلود داده‌های OSM برای ایران
# (این فایل حوالی 500 MB است)
wget https://download.geofabrik.de/asia/iran-latest.osm.pbf
```

### مرحله 3: پردازش داده‌ها

```bash
# نام‌گذاری فایل برای سادگی
mv iran-latest.osm.pbf iran.osm.pbf

# پردازش فایل (این ۵-۱۰ دقیقه طول می‌کشد)
docker run -t -v $(pwd):/data osrm/osrm-backend osrm-extract -p /opt/car.lua /data/iran.osm.pbf

docker run -t -v $(pwd):/data osrm/osrm-backend osrm-partition /data/iran.osm.pbf

docker run -t -v $(pwd):/data osrm/osrm-backend osrm-customize /data/iran.osm.pbf
```

### مرحله 4: اجرای سرور

```bash
# اجرای سرور OSRM روی پورت 5000
docker run -t -i -p 5000:5000 -v $(pwd):/data osrm/osrm-backend osrm-routed --algorithm mld /data/iran.osm.pbf
```

سرور اکنون در `http://localhost:5000` در دسترس است! ✓

---

## ✅ روش 2: نصب مستقیم (بدون Docker)

### مرحله 1: نصب وابستگی‌ها

**برای Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install build-essential cmake pkg-config libbz2-dev zlib1g-dev libstxxl-dev libboost-all-dev git
```

**برای macOS (با Homebrew):**
```bash
brew install cmake boost osm2pgsql
```

### مرحله 2: دانلود و ترجمه OSRM

```bash
# دانلود کد OSRM
git clone https://github.com/Project-OSRM/osrm-backend.git
cd osrm-backend
mkdir build
cd build

# ترجمه
cmake ..
make -j4  # استفاده از 4 هسته CPU
```

### مرحله 3: پردازش داده‌ها

```bash
# دانلود داده‌های ایران
cd /path/to/data
wget https://download.geofabrik.de/asia/iran-latest.osm.pbf

# پردازش
/path/to/osrm-backend/build/osrm-extract -p /path/to/osrm-backend/profiles/car.lua iran.osm.pbf
/path/to/osrm-backend/build/osrm-partition iran.osm.pbf
/path/to/osrm-backend/build/osrm-customize iran.osm.pbf
```

### مرحله 4: اجرای سرور

```bash
/path/to/osrm-backend/build/osrm-routed --algorithm mld iran.osm.pbf
```

---

## 📱 استفاده در Flutter

### مرحله 1: تنظیم URL سرور

```dart
import 'package:abtin_navigator/features/routing/data/offline_routing_service.dart';

// ایجاد نمونه‌ی سرویس
final offlineRoutingService = OfflineRoutingService();

// تنظیم URL سرور محلی (پیش‌فرض: localhost:5000)
offlineRoutingService.setLocalOsrmUrl('http://localhost:5000');

// برای تست روی دستگاه واقعی با سرور روی یک دستگاه دیگر:
// offlineRoutingService.setLocalOsrmUrl('http://192.168.1.100:5000');
```

### مرحله 2: استفاده در Provider

```dart
// ساده‌ترین راه: استفاده از calculateRouteProvider
final route = await ref.read(calculateRouteProvider.future);

// یا فقط آفلاین (اگر سرور محلی در دسترس نبود، مسیر خط مستقیم برگردانده می‌شود)
final offlineRoute = await ref.read(calculateOfflineRouteOnlyProvider.future);

// بررسی دسترسی به سرور
final isAvailable = await ref.read(osrmAvailabilityProvider.future);
```

### مرحله 3: نمایش وضعیت آفلاین/آنلاین در UI

```dart
Consumer(
  builder: (context, ref, child) {
    final navigation = ref.watch(activeNavigationProvider);
    
    if (navigation != null) {
      return Column(
        children: [
          Text(
            navigation.isOfflineRoute 
              ? '📡 مسیریابی آفلاین' 
              : '🌐 مسیریابی آنلاین',
          ),
          Text('${navigation.route.distanceKm.toStringAsFixed(1)} کیلومتر'),
        ],
      );
    }
    return SizedBox.shrink();
  },
)
```

---

## 🧪 تست سرور

### فرمان cURL برای تست

```bash
# تست ساده
curl "http://localhost:5000/route/v1/driving/51.3,35.7;51.4,35.8?overview=full&geometries=geojson"

# تست با زبان فارسی
curl "http://localhost:5000/route/v1/driving/51.3,35.7;51.4,35.8?overview=full&geometries=geojson&language=fa"
```

### برنامه‌ی تست Flutter

```dart
Future<void> testLocalOsrm() async {
  final service = OfflineRoutingService();
  
  // بررسی دسترسی
  final isAvailable = await service.isLocalOsrmAvailable();
  print('سرور محلی در دسترس: $isAvailable');
  
  if (isAvailable) {
    // محاسبه مسیر
    final origin = LatLng(35.6892, 51.3890); // تهران
    final destination = LatLng(33.3139, 44.3661); // بغداد
    
    final route = await service.calculateRoute(
      origin: origin,
      destination: destination,
    );
    
    if (route != null) {
      print('فاصله: ${route.distanceKm} کیلومتر');
      print('زمان: ${route.durationMin} دقیقه');
      print('دستورات: ${route.instructions.length}');
    }
  }
}
```

---

## 🛠 تنظیمات پیشرفته

### محدودیت CPU و RAM

اگر سرور از منابع فیزیکی محدودی استفاده می‌کند:

```bash
# محدودیت CPU و RAM (Docker)
docker run -t -i \
  --cpus="2" \
  --memory="1g" \
  -p 5000:5000 \
  -v $(pwd):/data \
  osrm/osrm-backend \
  osrm-routed --algorithm mld /data/iran.osm.pbf
```

### استفاده از داده‌های مناطق مختلف

```bash
# دانلود چند منطقه
wget https://download.geofabrik.de/asia/iran-latest.osm.pbf
wget https://download.geofabrik.de/asia/iraq-latest.osm.pbf

# ترکیب داده‌ها (اختیاری)
osmosis --read-pbf iran-latest.osm.pbf --read-pbf iraq-latest.osm.pbf --merge --write-pbf merged.osm.pbf

# پردازش فایل ترکیبی
osrm-extract -p car.lua merged.osm.pbf
osrm-partition merged.osm.pbf
osrm-customize merged.osm.pbf
osrm-routed --algorithm mld merged.osm.pbf
```

---

## 📊 بهینه‌سازی کارایی

### کش کردن نتایج

سرویس `OfflineRoutingService` به‌طور خودکار نتایج مسیریابی را کش می‌کند. برای مدیریت کش:

```dart
final service = OfflineRoutingService();

// پاک کردن کش
service.clearCache();

// دریافت آمار کش
final stats = service.getCacheStats();
print('تعداد مسیرهای کش‌شده: ${stats['cached_routes']}');
```

### تنظیم timeout

```dart
// در حال حاضر timeout ۱۵ ثانیه است
// برای تغییر، ویرایش کنید: _httpTimeout
static const Duration _httpTimeout = Duration(seconds: 15);
```

---

## ⚠️ مشکلات رایج و حل‌ها

| مشکل | علت | حل |
|---|---|---|
| سرور پاسخ نمی‌دهد | درگیری CPU | آپشن `--max-table-size` را کاهش دهید |
| مسیریابی آفلاین بسیار کند | داده‌های بزرگ | تقسیم داده‌ها به مناطق کوچک‌تر |
| خطای حافظه | فضای کافی نیست | تقسیم داده‌های OSM بزرگ به بخش‌های کوچک‌تر |
| ارتباط ندارد | IP/Port اشتباه | بررسی URL و پورت، firewall را چک کنید |

---

## 🔗 منابع مفید

- [OSRM Backend Docs](https://github.com/Project-OSRM/osrm-backend/wiki)
- [Geofabrik Downloads](https://download.geofabrik.de/)
- [OpenStreetMap Data](https://www.openstreetmap.org/)
- [Docker OSRM Image](https://hub.docker.com/r/osrm/osrm-backend)

---

## 📝 خلاصه

✅ **OSRM محلی** برای مسیریابی بدون اینترنت  
✅ **Fallback خودکار** به OSRM عمومی اگر محلی در دسترس نبود  
✅ **کش اتوماتیک** برای کاهش بار سرور  
✅ **دعم کامل فارسی** برای دستورات مسیریابی  

موفق باشید! 🚀
