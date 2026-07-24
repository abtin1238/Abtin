import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

  /// حداقل دقت معقول برای اندازه‌گیری (کف). بعضی گوشی‌ها گاهی accuracy=0 یا
  /// خیلی خوش‌بینانه (مثلاً همیشه یک عدد ثابت کوچک) گزارش می‌دهند؛ بدون این
  /// کف، فیلتر بیش‌ازحد به یک نمونه‌ی احتمالاً پرت اعتماد می‌کند و مقدار
  /// جهش می‌کند (دقیقاً باگ «سرعت ۳۰ ناگهان ۴۵ می‌شود»). برای سرعت این کف
  /// بزرگ‌تر از موقعیت است چون speedAccuracy گوشی‌های اندروید معمولاً
  /// بی‌ربط‌تر/خوش‌بینانه‌تر از accuracy موقعیت است.
  final double minMeasurementAccuracy;

  _Kalman1D({required this.processNoisePerSecond, this.minMeasurementAccuracy = 1.0});

  double get value => _value ?? 0;
  double get uncertainty => _variance < 0 ? 0 : math.sqrt(_variance);

  void reset() {
    _value = null;
    _variance = -1;
    _lastTimestampMs = null;
  }

  double process(
    double measurement,
    double measurementAccuracy,
    int timestampMs, {
    double extraProcessNoise = 0,
  }) {
    final acc = math.max(measurementAccuracy, minMeasurementAccuracy);
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
      // گذشته باشد، کمتر می‌توان به مقدار قبلی اطمینان کرد. extraProcessNoise
      // به شتاب‌سنج فیزیکی گوشی وصل است (نگاه کنید به LocationService): وقتی
      // خودرو واقعاً در حال شتاب‌گرفتن/ترمزکردن است، این عدد بزرگ می‌شود تا
      // فیلتر سریع‌تر به نمونه‌ی تازه‌ی GPS اعتماد کند و سرعت واقعی را با
      // تاخیر کمتر نشان دهد؛ در سرعت ثابت نزدیک صفر می‌ماند تا عدد صاف/بدون
      // لرزش بماند.
      final totalNoise = processNoisePerSecond + extraProcessNoise;
      _variance += dtSec * totalNoise * totalNoise;
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
///
/// نکته‌ی مهم درباره‌ی «اتصال سرعت‌سنج به شتاب‌سنج گوشی»: شتاب‌سنج به‌تنهایی
/// نمی‌تواند سرعت مطلق بدهد — نه جهت مرجع دارد (بدون قطب‌نما/ژیروسکوپ کامل
/// نمی‌دانیم شتاب اندازه‌گیری‌شده هم‌جهت حرکت خودرو است یا نه) و نه مرجع
/// مطلق سرعت (هر خطای کوچک با انتگرال‌گیری در طول زمان بی‌نهایت رشد می‌کند —
/// دقیقاً همان مشکلی که همه‌ی سیستم‌های INS خالص دارند و برای همین حتی در
/// هواپیما/کشتی هم با GPS تصحیح می‌شوند). به همین دلیل جایگزین‌کردن کامل GPS
/// با شتاب‌سنج، سرعت را واقعی‌تر نشان نمی‌دهد، برعکس؛ راه‌حل درست و رایج در
/// همه‌ی اپ‌های ناوبری واقعی (گوگل‌مپس/Waze) «فیوژن» است: GPS همچنان منبع
/// اصلیِ سرعت مطلق می‌ماند، اما شتاب‌سنج فیزیکی گوشی به‌صورت زنده اندازه‌ی
/// شتاب/ترمزِ واقعی خودرو را اندازه می‌گیرد و به فیلتر کالمن می‌گوید «الان
/// سرعت واقعاً در حال تغییر است، سریع‌تر به GPS تازه اعتماد کن» — همان چیزی
/// که باگ «کالمن درست کار نمی‌کند» (سرعت‌سنج در شتاب‌گیری/ترمز با تاخیر
/// دنبال می‌کند یا برعکس در سرعت ثابت می‌لرزد) را واقعاً حل می‌کند.
class LocationService {
  final _controller = StreamController<VehiclePosition>.broadcast();
  StreamSubscription<Position>? _sub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  // خط پایه‌ی شتاب (میانگین متحرک کند روی خروجیِ userAccelerometerEvents —
  // این استریم از قبل جاذبه را حذف کرده، پس در حالت سکون/سرعت‌ثابت نزدیک
  // صفر است) و اندازه‌ی شتاب «اضافه بر حالت عادی» که واقعاً به فیلتر سرعت
  // تزریق می‌شود — نگاه کنید به _onAccel و _onPosition.
  double _accelBaseline = 0;
  double _accelJerk = 0;

  // نرخ نویز فرآیند موقعیت: فرض می‌کنیم خودرو می‌تواند تا ~۲۰ متر بر ثانیه
  // (۷۲ کیلومتر بر ساعت) شتاب موقعیتی غیرمنتظره داشته باشد؛ این عدد هرچه
  // بزرگ‌تر باشد فیلتر سریع‌تر به نمونه‌ی جدید واکنش نشان می‌دهد (نویز کمتر
  // حذف می‌شود)، هرچه کوچک‌تر باشد نرم‌تر ولی با تاخیر بیشتر دنبال می‌کند.
  final _latFilter = _Kalman1D(processNoisePerSecond: 20);
  final _lngFilter = _Kalman1D(processNoisePerSecond: 20);
  // نکته‌ی مهم (رفع باگ «سرعت‌سنج ناگهان از ۳۰ به ۴۵ می‌پرد»): نسخه‌ی قبلی
  // processNoisePerSecond=3 داشت. این عدد در فرمول رشد واریانس فیلتر
  // (`variance += dt * processNoisePerSecond^2`) یعنی انحراف‌معیار مجاز
  // برای تغییر سرعت در هر ثانیه ~۳ متر/ثانیه (~۱۰.۸ کیلومتر/ساعت) بود — با
  // فاصله‌ی معمول ~۱ ثانیه بین آپدیت‌های GPS، واریانس فرآیند خیلی سریع‌تر از
  // واریانس اندازه‌گیری رشد می‌کرد و Kalman gain عملاً نزدیک ۱ می‌شد؛ یعنی
  // فیلتر تقریباً به‌طور کامل به هر نمونه‌ی تک و پرنویز GPS اعتماد می‌کرد و
  // یک جهش لحظه‌ای (مثلاً موقع عبور از کنار ساختمان/تونل کوتاه) مستقیم و
  // بدون میرایی روی صفحه ظاهر می‌شد. با کاهش به ۱.۱ و افزایش کف دقت اندازه‌گیری
  // (minMeasurementAccuracy) فیلتر به یک نمونه‌ی تکی کمتر اعتماد می‌کند و
  // جهش بین دو-سه نمونه‌ی پیاپی هموار می‌شود؛ شتاب واقعی و پیوسته (نه جهش
  // تک‌نمونه‌ای) همچنان ظرف ~۱-۲ ثانیه درست دنبال می‌شود.
  final _speedFilter = _Kalman1D(processNoisePerSecond: 1.1, minMeasurementAccuracy: 2.0);
  double? _lastRawSpeedMs;
  int? _lastRawSpeedTsMs;

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
    _accelBaseline = 0;
    _accelJerk = 0;
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
    // شتاب‌سنج فیزیکی گوشی با نرخ بالا (خیلی سریع‌تر از GPS) استریم می‌شود؛
    // فقط برای تخمین زنده‌ی «الان خودرو در حال شتاب‌گرفتن/ترمزکردن است یا
    // نه» استفاده می‌شود، نه برای محاسبه‌ی مستقیم سرعت (نگاه کنید به توضیح
    // بالای کلاس).
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccel, onError: (_) {
      // بعضی دستگاه‌ها/شبیه‌سازها شتاب‌سنج ندارند؛ در این حالت فیلتر فقط با
      // نویز فرآیند پایه (بدون کمک شتاب‌سنج) کار می‌کند، دقیقاً مثل قبل.
    });
  }

  void _onAccel(UserAccelerometerEvent e) {
    // اندازه‌ی برداری شتاب (جاذبه از قبل توسط پلتفرم حذف شده). خط پایه با
    // EMA بسیار کند دنبال می‌شود تا فقط نویز ثابت سنسور را مدل کند؛ فاصله‌ی
    // بین مقدار لحظه‌ای و این خط پایه یعنی «شتاب واقعی این لحظه».
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _accelBaseline += (mag - _accelBaseline) * 0.01;
    final instantJerk = (mag - _accelBaseline).abs();
    // EMA سریع‌تر روی خودِ jerk تا لرزش تک‌نمونه‌ای سنسور حذف شود ولی همچنان
    // در حد چند صدم ثانیه به شتاب/ترمز واقعی واکنش نشان دهد.
    _accelJerk += (instantJerk - _accelJerk) * 0.25;
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
    // نکته (اتصال واقعی سرعت‌سنج به شتاب‌سنج گوشی): وقتی شتاب‌سنج نشان
    // می‌دهد خودرو همین لحظه واقعاً در حال شتاب‌گرفتن/ترمزکردن است
    // (_accelJerk بزرگ)، به فیلتر کالمن اجازه می‌دهیم سریع‌تر به نمونه‌ی
    // تازه‌ی GPS اعتماد کند تا عدد نمایش‌داده‌شده با تاخیر کمتر دنبال کند؛
    // در سرعت ثابت (_accelJerk نزدیک صفر) نویز فرآیند اضافه هم صفر می‌شود،
    // پس فیلتر مثل قبل صاف/بدون لرزش می‌ماند. ضریب و سقف را طوری انتخاب
    // کرده‌ایم که حتی دست‌انداز/لرزش معمولی جاده (شتاب کوچک) اثر محسوسی
    // نگذارد و فقط شتاب‌گیری/ترمزِ واقعی (چند دهم g به بالا) فیلتر را
    // تندتر کند.
    final accelExtraNoise = math.min(_accelJerk * 2.5, 6.0);
    final filteredSpeedMs = _speedFilter.process(
      rawSpeedMs,
      speedAccuracy,
      tsMs,
      extraProcessNoise: accelExtraNoise,
    );
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
    _accelSub?.cancel();
    _controller.close();
  }
}

double degToRad(double deg) => deg * math.pi / 180;
