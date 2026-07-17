import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';

/// صفحه‌ی تنظیمات مسیریابی (مطابق تصویر «تنظیمات مسیریابی»).
class RoutingSettingsScreen extends ConsumerWidget {
  const RoutingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(routingSettingsProvider);
    final n = ref.read(routingSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.routingSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // رنگ مسیر
          const SectionHeader('رنگ مسیر'),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(AppColors.routeColors.length, (i) {
                    final c = AppColors.routeColors[i];
                    final active = s.routeColorIndex == i;
                    return GestureDetector(
                      onTap: () => n.setColor(i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: active
                              ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 10)]
                              : null,
                        ),
                        child: active
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.palette_rounded,
                        color: AppColors.textSecondaryDark, size: 18),
                    SizedBox(width: 8),
                    Text('رنگ مسیر پیشنهادی شما روی نقشه',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryDark)),
                  ],
                ),
              ],
            ),
          ),

          // شدت رنگ مسیر
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('شدت رنگ مسیر',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('میزان روشنایی و برجستگی مسیر روی نقشه',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryDark)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: s.routeIntensity,
                        onChanged: n.setIntensity,
                      ),
                    ),
                    Text('${(s.routeIntensity * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          // طرح مسیر (استاندارد/سه‌بعدی)
          const SectionHeader('طرح مسیر'),
          Row(
            children: [
              Expanded(
                child: _MapStyleCard(
                  label: 'استاندارد',
                  selected: !s.threeDMap,
                  icon: Icons.map_rounded,
                  onTap: () => n.set3D(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MapStyleCard(
                  label: 'سه‌بعدی',
                  selected: s.threeDMap,
                  icon: Icons.threed_rotation_rounded,
                  onTap: () => n.set3D(true),
                ),
              ),
            ],
          ),

          // خودرو و نمایش
          const SectionHeader('خودرو و نمایش'),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        color: AppColors.primary, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('انتخاب خودرو',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('انتخاب نماد خودرو روی نقشه',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
                const Divider(height: 20),
                ToggleTile(
                  title: 'نمایش خودرو',
                  subtitle: 'نمایش خودرو روی نقشه در حالت هدایت',
                  value: s.showVehicle,
                  onChanged: n.setShowVehicle,
                ),
                ToggleTile(
                  title: 'چراغ جلو در شب',
                  subtitle: 'نمایش نور چراغ جلو در محیط تاریک',
                  value: s.headlightsAtNight,
                  onChanged: n.setHeadlights,
                ),
              ],
            ),
          ),

          // گزینه‌های مسیر
          const SectionHeader('گزینه‌های مسیر'),
          AppCard(
            child: Column(
              children: [
                _navRow('نوع مسیر پیش‌فرض', 'سریع‌ترین'),
                const Divider(height: 20),
                _navRow('اجتناب از', 'انتخاب موارد حذف‌شده از مسیر'),
                const Divider(height: 20),
                ToggleTile(
                  title: 'مسیرهای جایگزین',
                  subtitle: 'نمایش مسیرهای جایگزین در هنگام هدایت',
                  value: s.alternativeRoutes,
                  onChanged: n.setAlternatives,
                ),
              ],
            ),
          ),

          // راهنمای مسیر
          const SectionHeader('راهنمای مسیر'),
          AppCard(
            child: Column(
              children: [
                ToggleTile(
                  title: 'نمایش راهنمای خطوط',
                  subtitle: 'نمایش خطوط راهنما در تقاطع‌ها و پیچ‌ها',
                  value: s.laneGuidance,
                  onChanged: n.setLaneGuidance,
                ),
                const Divider(height: 20),
                _navRow('اعلان پیچ‌ها', '۳۰۰ متر'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _navRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
            ],
          ),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondaryDark)),
        const Icon(Icons.chevron_left_rounded, color: AppColors.textMutedDark),
      ],
    );
  }
}

class _MapStyleCard extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _MapStyleCard({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDark,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 40,
                color: selected ? AppColors.primary : AppColors.textMutedDark),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimaryDark)),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
