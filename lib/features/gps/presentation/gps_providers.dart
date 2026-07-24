import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/permissions/location_permission_flow.dart';
import '../data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});

/// وضعیت آماده‌بودن GPS (مجوز + سرویس روشن) — به‌صورت زنده رصد می‌شود.
///
/// نکته‌ی مهم (رفع باگ اصلی «نوتیفیکیشن GPS/سرعت صفر/پیکان ثابت هیچ‌وقت درست
/// نمی‌شود»): نسخه‌ی قبلی این Provider یک FutureProvider بود که فقط یک‌بار،
/// همان لحظه‌ی باز شدن اپ، وضعیت را چک می‌کرد. اگر آن لحظه GPS خاموش بود،
/// [LocationPermissionFlow.ensureReady] فقط صفحه‌ی تنظیمات را باز می‌کرد و
/// بلافاصله (پیش از این‌که کاربر واقعاً GPS را روشن کند) دوباره چک می‌کرد؛
/// یعنی تقریباً همیشه نتیجه serviceDisabled می‌ماند و هرگز به‌روزرسانی
/// نمی‌شد — حتی اگر کاربر برگردد و GPS را روشن کند. نتیجه‌ی این باگ:
/// [locationServiceProvider.start()] هیچ‌وقت صدا زده نمی‌شد، پس استریم موقعیت
/// خودرو هیچ‌وقت مقدار واقعی نمی‌داد؛ سرعت همیشه ۰، پیکان همیشه روی موقعیت
/// اولیه‌ی ثابت (میدان آزادی) می‌ماند، و بنر «GPS خاموش است» برای همیشه
/// می‌ماند — دقیقاً همان چیزهایی که کاربر می‌دید.
///
/// الان این یک StreamProvider است که:
/// ۱) همان بار اول با [ensureReady] فلوی تعاملی (درخواست مجوز/باز کردن
///    تنظیمات) را انجام می‌دهد.
/// ۲) از آن به بعد به [Geolocator.getServiceStatusStream] گوش می‌دهد تا هر
///    وقت کاربر GPS را روشن/خاموش کند، بلافاصله وضعیت به‌روزرسانی شود.
/// ۳) هر وقت اپ از پس‌زمینه برمی‌گردد (مثلاً بعد از دادن مجوز در تنظیمات)
///    هم دوباره چک می‌شود — با [locationLifecycleTickProvider] که در
///    main.dart با WidgetsBindingObserver افزایش می‌یابد.
final locationLifecycleTickProvider = StateProvider<int>((ref) => 0);

final locationReadinessProvider = StreamProvider<LocationReadiness>((ref) async* {
  final locationService = ref.read(locationServiceProvider);
  bool serviceStarted = false;

  Future<LocationReadiness> reportAndMaybeStart(LocationReadiness r) async {
    if (r == LocationReadiness.ready && !serviceStarted) {
      serviceStarted = true;
      locationService.start();
    }
    return r;
  }

  // ۱) بررسی اولیه‌ی تعاملی (ممکن است دیالوگ/صفحه‌ی تنظیمات باز کند)
  yield await reportAndMaybeStart(await LocationPermissionFlow.ensureReady());

  // ۲) رصد زنده‌ی روشن/خاموش شدن GPS
  final serviceStatusStream = Geolocator.getServiceStatusStream();

  // ۳) هر بار اپ resume می‌شود (تیک این Provider تغییر می‌کند) هم دوباره چک کن
  final lifecycleStream = ref.watch(locationLifecycleTickProvider.notifier).stream;

  // نکته‌ی مهم (رفع باگ «اگه مجوز داده نشده بود اپ دیگه دوباره سوال نمی‌کرد»):
  // قبلاً این‌جا از [checkStatus] استفاده می‌شد که کاملاً غیرتعاملی بود و
  // فقط وضعیت فعلی مجوز را می‌خواند — یعنی اگر کاربر بار اول مجوز را رد
  // می‌کرد، اپ تا ابد فقط بنر هشدار را نشان می‌داد و هیچ‌وقت خودش دوباره
  // درخواست مجوز نمی‌کرد؛ کاربر مجبور بود دستی برود تنظیمات گوشی. حالا از
  // [checkStatusAndRetryIfDenied] استفاده می‌شود: اگر مجوز فقط «denied»
  // ساده باشد (نه برای همیشه رد شده)، هر بار GPS/چرخه‌ی حیات اپ تغییر کند
  // (مثلاً کاربر از تنظیمات برگردد)، دوباره دیالوگ سیستمی مجوز نشان داده
  // می‌شود.
  await for (final _ in _merge(serviceStatusStream, lifecycleStream)) {
    yield await reportAndMaybeStart(
      await LocationPermissionFlow.checkStatusAndRetryIfDenied(),
    );
  }
});

/// برای ضربه‌ی دستی کاربر روی بنر هشدار GPS: بلافاصله یک تلاش مجدد انجام
/// می‌دهد (دوباره درخواست مجوز، یا باز کردن تنظیمات اپ اگر برای همیشه رد
/// شده) و چرخه‌ی حیات را هم تیک می‌زند تا [locationReadinessProvider]
/// نتیجه‌ی تازه را بگیرد.
final retryLocationPermissionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await LocationPermissionFlow.retryFromUserTap();
    ref.read(locationLifecycleTickProvider.notifier).state++;
  };
});

/// یک Stream ساده که هر رویداد از هر دو منبع را عبور می‌دهد (نیازی به مقدار
/// واقعی رویداد نیست، فقط «یک تغییری رخ داد» مهم است).
Stream<void> _merge(Stream<ServiceStatus> a, Stream<int> b) {
  final controller = StreamController<void>();
  final subA = a.listen((_) => controller.add(null));
  final subB = b.listen((_) => controller.add(null));
  controller.onCancel = () {
    subA.cancel();
    subB.cancel();
  };
  return controller.stream;
}

/// استریم موقعیت هموارشده‌ی خودرو — منبع اصلی برای مارکر و دوربین نقشه.
final vehiclePositionProvider = StreamProvider<VehiclePosition>((ref) {
  // اطمینان از این‌که سرویس GPS استارت خورده
  ref.watch(locationReadinessProvider);
  return ref.watch(locationServiceProvider).stream;
});
