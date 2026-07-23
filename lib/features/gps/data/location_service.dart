import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// موقعیت فیلترشده‌ی خودرو — چیزی که به نقشه و مارکر داده می‌شود.
class VehiclePosition {
  final double lat;
  final double lng;
  final double headingDeg; // 0-360، شمال = 0
  final double speedKmh;
  final double accuracyM; // شعاع خطای تخمینی فعلی (متر) — از واریانس فیلتر کالمن

  const VehiclePosition({
    required this.lat,
    required this.lng,
    required this.headingDeg,
    required this.speedKmh,
    required this.accuracyM,
  });
}

/// یک فیلتر کالمن یک‌بعدی (واریانس-محور) برای موقعیت GPS — همان الگوریتم
/// شناخته‌شده‌ای که در اغلب اپ‌های ناوبری اندروید/iOS استفاده می‌شود (نسخه‌ی
/// معروف Chatty). چون روی مقیاس کوچک (چند متر تا چند صد متر)، lat/lng را
/// می‌شود مثل دو محور مستقل تقریباً خطی در نظر گرفت، نیازی به ماتریس
/// کوواریانس ۴×۴ کامل نیست — همین مدل ساده‌تر در عمل به‌خوبی کار می‌کند و
/// چون کاملاً دستی (بدون وابستگی به یک پکیج ماتریس‌جبر) نوشته شده، به هیچ
/// پکیج اضافه‌ای هم نیاز ندارد.
///
/// نکته‌ی کلیدی که EMA قبلی نداشت: هر نمونه‌ی GPS بر اساس دقتِ خودش
/// (`accuracy`) وزن‌دهی می‌شود — نمونه‌ی نامطمئن (accuracy بزرگ) کمتر روی
/// نتیجه اثر می‌گذارد، نمونه‌ی دقیق بیشتر. همچنین بین دو آپدیت، عدم‌قطعیت
/// (variance) طبق زمان سپری‌شده و یک نرخ نویز فرآیند (Q) رشد می‌کند —
/// دقیقاً مدل‌سازی این‌که «خودرو ممکن است حرکت کرده باشد».
class _Kalman1D {
  double? _value;
  double _variance = -1;
  int? _lastTimestampMs;

  /// نرخ نویز فرآیند: چقدر سریع مقدار واقعی می‌تواند بین دو نمونه تغییر کند
  /// (واحد بستگی به کمیت دارد — برای موقعیت متر/ثانیه، برای سرعت متر/ثانیه‌مربع).
  final double processNoisePerSecond;

  _Kalman1D({required this.processNoisePerSecond});

  double get value => _value ?? 0;
  double get uncertainty => _variance < 0 ? 0 : math.sqrt(_variance);

  void reset() {
    _value = null;
    _variance = -1;
    _lastTimestampMs = null;
  }

  double process(double measurement, double measurementAccuracy, int timestampMs) {
    // حداقل دقت معقول برای اندازه‌گیری (بعضی گوشی‌ها گاهی accuracy=0 یا
    // خیلی خوش‌بینانه گزارش می‌دهند؛ بدون این کف، فیلتر بیش‌ازحد به یک نمونه‌ی
    // احتمالاً پرت اعتماد می‌کند).
    final acc = math.max(measurementAccuracy, 1.0);
    final measurementVariance = acc * acc;

    if (_value == null || _variance < 0) {
      _value = measurement;
      _variance = measurementVariance;
      _lastTimestampMs = timestampMs;
      return _value!;
    }

    final dtSec = math.max((timestampMs - (_lastTimestampMs ?? timestampMs)) / 1000.0, 0.0);
    _lastTimestampMs = timestampMs;

    if (dtSec > 0) {
      // رشد عدم‌قطعیت با زمان (پیش‌بینی): هرچه زمان بیشتری از آخرین نمونه
      // گذشته باشد، کمتر می‌توان به مقدار قبلی اطمینان کرد.
      _variance += dtSec * processNoisePerSecond * processNoisePerSecond;
    }

    final kalmanGain = _variance / (_variance + measurementVariance);
    _value = _value! + kalmanGain * (measurement - _value!);
    _variance = (1 - kalmanGain) * _variance;
    return _value!;
  }
}

/// استریم GPS با فیلتر کالمن روی موقعیت و سرعت، به‌علاوه‌ی یک هدینگ که در
/// سرعت‌های خیلی کم منجمد می‌شود (چون GPS heading زیر ~۲ کیلومتر/ساعت عملاً
/// نویز محض است و باعث چرخش بی‌دلیل پیکان روی نقشه می‌شد).
class LocationService {
  final _controller = StreamController<VehiclePosition>.broadcast();
  StreamSubscription<Position>? _sub;

  // نرخ نویز فرآیند موقعیت: فرض می‌کنیم خودرو می‌تواند تا ~۲۰ متر بر ثانیه
  // (۷۲ کیلومتر بر ساعت) شتاب موقعیتی غیرمنتظره داشته باشد؛ این عدد هرچه
  // بزرگ‌تر باشد فیلتر سریع‌تر به نمونه‌ی جدید واکنش نشان می‌دهد (نویز کمتر
  // حذف می‌شود)، هرچه کوچک‌تر باشد نرم‌تر ولی با تاخیر بیشتر دنبال می‌کند.
  final _latFilter = _Kalman1D(processNoisePerSecond: 20);
  final _lngFilter = _Kalman1D(processNoisePerSecond: 20);
  // سرعت هم جداگانه فیلتر می‌شود تا سرعت‌سنج پرش نداشته باشد (مشکل «۳۵ ناگهان
  // ۴۰ می‌شود»)؛ نرخ نویز فرآیند بزرگ‌تر چون شتاب واقعی خودرو می‌تواند سریع باشد.
  final _speedFilter = _Kalman1D(processNoisePerSecond: 3);

  double? _smoothHeading;

  static const double _headingAlpha = 0.25;
  static const double _headingFreezeSpeedKmh = 2.0; // زیر این سرعت، هدینگ عوض نمی‌شود

  Stream<VehiclePosition> get stream => _controller.stream;

  void start() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // متر — به‌روزرسانی حتی با حرکت کم؛ فیلتر کالمن خودش نویز را حذف می‌کند
    );
    _latFilter.reset();
    _lngFilter.reset();
    _speedFilter.reset();
    _smoothHeading = null;
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void _onPosition(Position p) {
    final tsMs = p.timestamp.millisecondsSinceEpoch;
    final posAccuracy = p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : 15.0;

    final filteredLat = _latFilter.process(p.latitude, posAccuracy, tsMs);
    final filteredLng = _lngFilter.process(p.longitude, posAccuracy, tsMs);

    // دقت سرعت گزارش‌شده‌ی GPS (اگر گوشی پشتیبانی نکند، یک مقدار پیش‌فرض
    // معقول در نظر می‌گیریم تا فیلتر همچنان کار کند، فقط کمی محتاط‌تر).
    final rawSpeedMs = p.speed.isFinite && p.speed >= 0 ? p.speed : 0.0;
    final speedAccuracy = p.speedAccuracy.isFinite && p.speedAccuracy > 0 ? p.speedAccuracy : 1.5;
    final filteredSpeedMs = _speedFilter.process(rawSpeedMs, speedAccuracy, tsMs);
    final speedKmh = math.max(filteredSpeedMs, 0) * 3.6;

    // هدینگ: زیر یک آستانه‌ی سرعت، GPS heading عملاً بی‌معنی و پرنویز است
    // (خودرو تقریباً ثابت است ولی هدینگ می‌تواند بین چند جهت تصادفی بپرد).
    // در این حالت آخرین جهت معتبر را نگه می‌داریم به‌جای این‌که پیکان بچرخد.
    if (speedKmh >= _headingFreezeSpeedKmh && p.heading >= 0 && p.heading.isFinite) {
      _smoothHeading = _lerpAngle(_smoothHeading, p.heading, _headingAlpha);
    } else {
      _smoothHeading ??= (p.heading >= 0 && p.heading.isFinite) ? p.heading : 0;
    }

    final accuracyM = math.sqrt(
      _latFilter.uncertainty * _latFilter.uncertainty + _lngFilter.uncertainty * _lngFilter.uncertainty,
    );

    _controller.add(VehiclePosition(
      lat: filteredLat,
      lng: filteredLng,
      headingDeg: _smoothHeading!,
      speedKmh: speedKmh,
      accuracyM: accuracyM,
    ));
  }

  /// میان‌یابی زاویه‌ای صحیح (برای این‌که چرخش از 359 به 1 درجه، یک دور کامل نچرخد)
  double _lerpAngle(double? current, double target, double alpha) {
    if (current == null) return target;
    var diff = (target - current + 540) % 360 - 180;
    return (current + diff * alpha + 360) % 360;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

double degToRad(double deg) => deg * math.pi / 180;
