import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';

/// صدای موجود برای موتور TTS فارسی.
class _Voice {
  final String id;
  final String name;
  final String desc;
  final bool recommended;
  const _Voice(this.id, this.name, this.desc, {this.recommended = false});
}

const _voices = [
  _Voice('mahsa', 'مهسا', 'زن • فارسی • واضح و طبیعی', recommended: true),
  _Voice('negar', 'نگار', 'زن • فارسی • گرم و دوستانه'),
  _Voice('parisa', 'پریسا', 'زن • فارسی • رسمی و گویا'),
  _Voice('amir', 'امیر', 'مرد • فارسی • عمیق و رسمی'),
];

/// صفحه‌ی تنظیمات صدا و راهنمای صوتی (مطابق تصویر «صدا»).
class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(voiceSettingsProvider);
    final n = ref.read(voiceSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.voiceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // راهنمای صوتی مسیر (سوییچ اصلی)
          AppCard(
            child: Row(
              children: [
                const GlowIcon(Icons.volume_up_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppStrings.voiceGuide,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        v.guideEnabled ? AppStrings.voiceGuideActive : 'غیرفعال',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
                Switch(
                    value: v.guideEnabled,
                    onChanged: n.toggleGuide),
              ],
            ),
          ),

          // موتور TTS
          const SectionHeader(AppStrings.ttsEngine),
          AppCard(
            onTap: () {},
            child: Row(
              children: [
                const GlowIcon(Icons.record_voice_over_rounded, size: 42),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.ttsPersian,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(AppStrings.ttsDefault,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),

          // انتخاب صدا
          const SectionHeader(AppStrings.voiceSelection),
          ..._voices.map((voice) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VoiceTile(
                  voice: voice,
                  selected: v.selectedVoiceId == voice.id,
                  onTap: () => n.selectVoice(voice.id),
                ),
              )),
          AppCard(
            onTap: () {},
            child: Row(
              children: const [
                GlowIcon(Icons.cloud_download_rounded, size: 42),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('دریافت صداهای بیشتر',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('دانلود بسته‌های صوتی جدید',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),

          // تنظیمات پخش
          const SectionHeader(AppStrings.playbackSettings),
          AppCard(
            child: Column(
              children: [
                _SliderRow(
                  icon: Icons.speed_rounded,
                  label: AppStrings.speechRate,
                  value: v.speechRate,
                  min: 0.5,
                  max: 2.0,
                  display: '${v.speechRate.toStringAsFixed(1)}x',
                  onChanged: n.setRate,
                ),
                _SliderRow(
                  icon: Icons.volume_up_rounded,
                  label: AppStrings.volume,
                  value: v.volume,
                  min: 0,
                  max: 1,
                  display: '${(v.volume * 100).round()}%',
                  onChanged: n.setVolume,
                ),
                _SliderRow(
                  icon: Icons.graphic_eq_rounded,
                  label: AppStrings.pitch,
                  value: v.pitch,
                  min: -1,
                  max: 1,
                  display: v.pitch.toStringAsFixed(0),
                  onChanged: n.setPitch,
                ),
              ],
            ),
          ),

          // نمونه صدا
          const SectionHeader(AppStrings.voiceSample),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('مسیر نمونه',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('پخش راهنمای نمونه برای ارزیابی صدا',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _previewVoice(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: AppColors.primary, size: 30),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoBanner(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _previewVoice(BuildContext context) {
    // در نسخه‌ی نهایی از flutter_tts آفلاین استفاده می‌شود.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('۵۰۰ متر جلوتر به راست بپیچید'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final _Voice voice;
  final bool selected;
  final VoidCallback onTap;
  const _VoiceTile(
      {required this.voice, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline_rounded,
              color: AppColors.primary, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(voice.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (voice.recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('پیشنهادی',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF04201D),
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(voice.desc,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryDark)),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: selected ? AppColors.primary : AppColors.textMutedDark,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value, min, max;
  final String display;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(display,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryDark)),
            ],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'تمام راهنماها با موتور TTS فارسی آفلاین پخش می‌شوند. برای بهترین کیفیت، از اتصال اینترنت استفاده نمی‌شود.',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
