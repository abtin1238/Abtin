import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// نتیجه تشخیص گفتار آفلاین.
class SttResult {
  final String text;
  final bool isFinal;
  final double confidence;
  const SttResult(this.text, {this.isFinal = true, this.confidence = 1});
}

/// انواع فرمان صوتی ناوبری.
enum VoiceCommandType {
  stopNavigation,
  resumeGuidance,
  navigateHome,
  navigateWork,
  whereAmI,
  repeatManeuver,
  reroute,
  navigateToQuery,
  unknown,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String raw;
  const VoiceCommand(this.type, this.raw);
}

/// سرویس STT آفلاین مبتنی بر Vosk (MethodChannel).
///
/// بدون مدل/باینری نیتیو، [isAvailable]=false و [parseCommand] همچنان
/// برای فرمان‌های متنی/شبیه‌سازی‌شده کار می‌کند.
class VoskSttService {
  VoskSttService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('ir.abtin.navigator/vosk');

  final MethodChannel _channel;
  final _controller = StreamController<SttResult>.broadcast();
  bool? _available;
  bool _listening = false;

  Stream<SttResult> get results => _controller.stream;
  bool get isListening => _listening;

  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final res = await _channel.invokeMethod<bool>('isModelReady');
      _available = res == true;
    } on MissingPluginException {
      _available = false;
    } catch (e) {
      debugPrint('Vosk unavailable: $e');
      _available = false;
    }
    return _available!;
  }

  Future<void> startListening() async {
    if (_listening) return;
    _listening = true;
    try {
      if (await isAvailable) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onPartial' || call.method == 'onFinal') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            _controller.add(SttResult(
              (args['text'] as String?) ?? '',
              isFinal: call.method == 'onFinal',
              confidence: ((args['confidence'] as num?) ?? 1).toDouble(),
            ));
          }
        });
        await _channel.invokeMethod('start');
      }
    } catch (e) {
      debugPrint('Vosk start failed: $e');
    }
  }

  Future<void> stopListening() async {
    _listening = false;
    try {
      if (_available == true) {
        await _channel.invokeMethod('stop');
      }
    } catch (_) {}
  }

  /// تزریق متن (برای تست یا ورودی کیبورد به‌جای میکروفون).
  void injectText(String text, {bool isFinal = true}) {
    _controller.add(SttResult(text, isFinal: isFinal));
  }

  /// نگاشت فرمان فارسی به اکشن ناوبری.
  static VoiceCommand parseCommand(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) {
      return VoiceCommand(VoiceCommandType.unknown, raw);
    }
    if (t.contains('توقف') || t.contains('بایست') || t.contains('cancel')) {
      return VoiceCommand(VoiceCommandType.stopNavigation, raw);
    }
    if (t.contains('ادامه') || t.contains('resume')) {
      return VoiceCommand(VoiceCommandType.resumeGuidance, raw);
    }
    if (t.contains('خانه') || t.contains('home')) {
      return VoiceCommand(VoiceCommandType.navigateHome, raw);
    }
    if (t.contains('محل کار') || t.contains('work')) {
      return VoiceCommand(VoiceCommandType.navigateWork, raw);
    }
    if (t.contains('کجا') || t.contains('مقصد') || t.contains('where')) {
      return VoiceCommand(VoiceCommandType.whereAmI, raw);
    }
    if (t.contains('دوباره') || t.contains('تکرار') || t.contains('repeat')) {
      return VoiceCommand(VoiceCommandType.repeatManeuver, raw);
    }
    if (t.contains('مسیر') && (t.contains('عوض') || t.contains('جایگزین'))) {
      return VoiceCommand(VoiceCommandType.reroute, raw);
    }
    if (t.contains('برو به') || t.contains('navigate') || t.contains('مسیریابی')) {
      return VoiceCommand(VoiceCommandType.navigateToQuery, raw);
    }
    return VoiceCommand(VoiceCommandType.unknown, raw);
  }

  Future<void> dispose() async {
    await stopListening();
    await _controller.close();
  }
}
