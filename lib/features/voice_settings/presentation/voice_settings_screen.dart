import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/thumb_back_button.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  bool masterOn = true;
  double volume = 0.75;
  double rate = 0.5;
  String gender = 'female';
  String voice = 'sara';
  String engine = 'system';
  bool streetNames = true;
  bool cameraAlerts = true;
  bool duckMusic = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'تنظیمات صدا', backRoute: '/settings'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF1E1B42), Color(0xFF0B0A1E)],
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: GlassPanel(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SwitchRow(
                        label: 'راهنمای صوتی',
                        value: masterOn,
                        onChanged: (v) => setState(() => masterOn = v),
                      ),
                      const SizedBox(height: 16),
                      _Slider(
                        label: 'میزان بلندی صدا',
                        value: volume,
                        valueLabel: '${(volume * 100).round()}%',
                        onChanged: (v) => setState(() => volume = v),
                      ),
                      const SizedBox(height: 16),
                      _Slider(
                        label: 'سرعت خواندن',
                        value: rate,
                        valueLabel: _rateLabel(rate),
                        onChanged: (v) => setState(() => rate = v),
                      ),
                      const SizedBox(height: 16),
                      const Text('جنسیت گوینده', style: TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 8),
                      _Segmented(
                        options: const {'female': 'زن', 'male': 'مرد'},
                        selected: gender,
                        onSelect: (v) => setState(() => gender = v),
                      ),
                      const SizedBox(height: 20),
                      const Text('صدای گوینده', style: TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 8),
                      ..._voices.map((v) => _OptionRow(
                            title: v.$1,
                            subtitle: v.$2,
                            selected: voice == v.$3,
                            onTap: () => setState(() => voice = v.$3),
                          )),
                      const SizedBox(height: 10),
                      _TestVoiceButton(),
                      const SizedBox(height: 20),
                      const Text('موتور تبدیل متن به گفتار (TTS)', style: TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 8),
                      _OptionRow(
                        title: 'موتور پیش‌فرض سیستم',
                        subtitle: 'بدون نیاز به اینترنت، سریع‌تر',
                        selected: engine == 'system',
                        onTap: () => setState(() => engine = 'system'),
                      ),
                      _OptionRow(
                        title: 'موتور آنلاین (کیفیت بالا)',
                        subtitle: 'نیاز به اینترنت، طبیعی‌تر',
                        selected: engine == 'cloud',
                        onTap: () => setState(() => engine = 'cloud'),
                      ),
                      const SizedBox(height: 16),
                      _SwitchRow(
                        label: 'اعلام نام خیابان‌ها',
                        value: streetNames,
                        onChanged: (v) => setState(() => streetNames = v),
                      ),
                      _SwitchRow(
                        label: 'هشدار صوتی دوربین و رادار',
                        value: cameraAlerts,
                        onChanged: (v) => setState(() => cameraAlerts = v),
                      ),
                      _SwitchRow(
                        label: 'کاهش صدا هنگام پخش موزیک',
                        desc: 'صدای راهنما روی موزیک/پادکست دیگر پایین میاد',
                        value: duckMusic,
                        onChanged: (v) => setState(() => duckMusic = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const BottomNav(currentPage: NavKey.settings),
            const ThumbBackButton(backRoute: '/settings'),
          ],
        ),
      ),
    );
  }

  String _rateLabel(double p) {
    final speed = (0.5 + p * 1.5);
    final label = speed == 1.0 ? 'متوسط' : (speed < 1.0 ? 'کند' : 'سریع');
    return '$label (${speed.toStringAsFixed(1)}x)';
  }

  static const _voices = [
    ('سارا', 'صدای پیش‌فرض، لحن آرام', 'sara'),
    ('نیلوفر', 'لحن رسمی و شمرده', 'niloofar'),
    ('آرش', 'لحن جدی و رسا', 'arash'),
    ('کیان', 'لحن دوستانه و صمیمی', 'kian'),
  ];
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.label, this.desc, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.06))),
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF1B1638),
            activeTrackColor: AppColors.subAccentB,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFFF0F2F4), fontSize: 15)),
                if (desc != null) ...[
                  const SizedBox(height: 3),
                  Text(desc!, style: const TextStyle(color: Color(0xFF8B929B), fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        Text(valueLabel, style: const TextStyle(color: AppColors.subAccentA, fontWeight: FontWeight.bold, fontSize: 15)),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.subAccentB,
            inactiveTrackColor: Colors.white.withOpacity(.1),
            thumbColor: Colors.white,
            overlayColor: AppColors.subAccentB.withOpacity(.2),
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _Segmented({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x8C1E1A3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.entries.map((e) {
          final active = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.subAccentGradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFC7CCD1),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.subAccentB.withOpacity(.14) : AppColors.subGlassBgSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.subAccentB : AppColors.subGlassBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.subAccentB : const Color(0xFF6B7280), width: 2),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.subAccentGradient),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestVoiceButton extends StatefulWidget {
  @override
  State<_TestVoiceButton> createState() => _TestVoiceButtonState();
}

class _TestVoiceButtonState extends State<_TestVoiceButton> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => playing = true);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => playing = false);
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.subAccentB.withOpacity(.14),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.subAccentB, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: AppColors.subAccentA, size: 18),
            const SizedBox(width: 6),
            Text(
              playing ? 'در حال پخش...' : 'پخش نمونه صدا',
              style: const TextStyle(color: AppColors.subAccentA, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
