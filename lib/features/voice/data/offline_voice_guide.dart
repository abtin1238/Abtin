import '../../navigation/domain/entities/route_info.dart';
import '../../../core/services/tts_service.dart';

/// ماشین حالت راهنمای صوتی آفلاین (FA/EN).
///
/// حالت‌ها: idle → navigating → announcing → idle
enum VoiceGuideState { idle, navigating, announcing }

class OfflineVoiceGuide {
  OfflineVoiceGuide(this._tts);

  final TtsService _tts;
  VoiceGuideState state = VoiceGuideState.idle;
  int _lastAnnouncedStep = -1;
  DateTime? _lastAnnounceAt;

  Future<void> start() async {
    state = VoiceGuideState.navigating;
    await _tts.speak('مسیریابی آغاز شد');
  }

  Future<void> stop() async {
    state = VoiceGuideState.idle;
    _lastAnnouncedStep = -1;
    await _tts.speak('مسیریابی پایان یافت');
  }

  /// اعلام مانور بر اساس فاصله باقی‌مانده تا گام بعدی.
  Future<void> onNavigationTick({
    required List<ManeuverStep> steps,
    required int currentStepIndex,
    required double distanceToNextMeters,
    required double speedKmh,
    bool announceSpeedLimit = true,
    int? speedLimit,
  }) async {
    if (state == VoiceGuideState.idle) return;
    if (currentStepIndex < 0 || currentStepIndex >= steps.length) return;

    final now = DateTime.now();
    if (_lastAnnounceAt != null &&
        now.difference(_lastAnnounceAt!).inSeconds < 4) {
      return;
    }

    final step = steps[currentStepIndex];
    final should =
        currentStepIndex != _lastAnnouncedStep && distanceToNextMeters < 250 ||
            (distanceToNextMeters < 80 &&
                currentStepIndex == _lastAnnouncedStep);

    if (should && currentStepIndex != _lastAnnouncedStep) {
      state = VoiceGuideState.announcing;
      final distLabel = distanceToNextMeters >= 1000
          ? '${(distanceToNextMeters / 1000).toStringAsFixed(1)} کیلومتر'
          : '${distanceToNextMeters.round()} متر';
      await _tts.speak('$distLabel دیگر، ${step.instruction}');
      _lastAnnouncedStep = currentStepIndex;
      _lastAnnounceAt = now;
      state = VoiceGuideState.navigating;
    }

    if (announceSpeedLimit &&
        speedLimit != null &&
        speedKmh > speedLimit + 8) {
      if (_lastAnnounceAt == null ||
          now.difference(_lastAnnounceAt!).inSeconds > 12) {
        await _tts.speak('کاهش سرعت، محدودیت $speedLimit کیلومتر بر ساعت');
        _lastAnnounceAt = now;
      }
    }
  }

  Future<void> announceHazard(String title) async {
    state = VoiceGuideState.announcing;
    await _tts.speak('هشدار: $title');
    state = VoiceGuideState.navigating;
    _lastAnnounceAt = DateTime.now();
  }
}
