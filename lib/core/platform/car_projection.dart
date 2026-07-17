import 'package:flutter/services.dart';

/// پل ارتباطی برای Android Auto و Apple CarPlay.
///
/// پیاده‌سازی کامل UI خودرو به MethodChannel بومی نیاز دارد
/// (Kotlin / Swift). این لایه قرارداد و deep-link مقصد را فراهم می‌کند.
class CarProjectionService {
  static const _channel = MethodChannel('ir.abtin.navigator/car_projection');

  /// اعلام آمادگی اپ به‌عنوان ناوبری پیش‌فرض.
  Future<void> registerAsNavigationApp() async {
    try {
      await _channel.invokeMethod('registerNavigationApp');
    } on MissingPluginException {
      // در شبیه‌ساز/دسکتاپ پلاگین بومی نیست — نادیده.
    }
  }

  /// ارسال مانور بعدی به صفحه خودرو.
  Future<void> pushManeuver({
    required String instruction,
    required double distanceMeters,
    required double remainingMeters,
    required int etaEpochMs,
  }) async {
    try {
      await _channel.invokeMethod('pushManeuver', {
        'instruction': instruction,
        'distanceMeters': distanceMeters,
        'remainingMeters': remainingMeters,
        'etaEpochMs': etaEpochMs,
      });
    } on MissingPluginException {
      // no-op
    }
  }

  /// گوش‌دادن به مقصد ارسالی از سیستم خودرو / Intent.
  void listenForDestinations(void Function(double lat, double lon, String? title) onDest) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        onDest(
          (args['lat'] as num).toDouble(),
          (args['lon'] as num).toDouble(),
          args['title'] as String?,
        );
      }
    });
  }
}
