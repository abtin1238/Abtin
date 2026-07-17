import 'package:flutter_tts/flutter_tts.dart';

/// سرویس متن‌به‌گفتار آفلاین فارسی (راهنمای صوتی مسیر).
/// از موتور TTS دستگاه استفاده می‌کند؛ برای آفلاین کامل باید بسته‌ی صوتی
/// فارسی روی دستگاه نصب باشد. برای کیفیت بالاتر می‌توان یک موتور محلی
/// (مانند Piper) را از طریق MethodChannel جایگزین کرد.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init({
    double rate = 1.0,
    double volume = 0.8,
    double pitch = 1.0,
  }) async {
    await _tts.setLanguage('fa-IR');
    await _tts.setSpeechRate(_mapRate(rate));
    await _tts.setVolume(volume);
    await _tts.setPitch(_mapPitch(pitch));
    _ready = true;
  }

  /// نگاشت سرعت 0.5..2.0 به بازه‌ی موتور 0..1.
  double _mapRate(double r) => (r.clamp(0.5, 2.0) - 0.5) / 1.5 * 0.7 + 0.15;

  /// نگاشت زیر و بمی -1..1 به بازه‌ی موتور 0.5..2.0.
  double _mapPitch(double p) => 1.0 + p.clamp(-1.0, 1.0) * 0.5;

  Future<void> speak(String text) async {
    if (!_ready) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
