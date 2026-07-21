import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/page_header.dart';
import '../../routing/presentation/routing_providers.dart';

class OfflineRoutingSettingsScreen extends ConsumerWidget {
  const OfflineRoutingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(routingSettingsProvider);
    final osrmAvailability = ref.watch(osrmAvailabilityProvider);
    final osrmStats = ref.watch(osrmStatsProvider);

    return Scaffold(
      appBar: const PageHeader(title: 'تنظیمات مسیریابی آفلاین'),
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
                      // وضعیت سرور OSRM محلی
                      _buildServerStatusCard(osrmAvailability),

                      const SizedBox(height: 24),

                      // تنظیمات
                      const Text(
                        'تنظیمات',
                        style: TextStyle(
                          color: AppColors.subAccentB,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // فعال‌سازی آفلاین فقط
                      _buildToggleOption(
                        title: 'استفاده فقط از آفلاین',
                        description: 'اگر فعال باشد، فقط سرور محلی استفاده می‌شود',
                        value: settings.useOfflineOnly,
                        onChanged: (value) {
                          ref
                              .read(routingSettingsProvider.notifier)
                              .setUseOfflineOnly(value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // فعال‌سازی کش
                      _buildToggleOption(
                        title: 'کش کردن مسیرها',
                        description: 'ذخیره‌ی نتایج برای بهره‌وری بهتر',
                        value: settings.enableRouteCache,
                        onChanged: (value) {
                          ref
                              .read(routingSettingsProvider.notifier)
                              .setEnableRouteCache(value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // URL سرور محلی
                      _buildUrlInputField(
                        title: 'URL سرور محلی OSRM',
                        initialValue: settings.localOsrmUrl,
                        onChanged: (value) {
                          ref
                              .read(routingSettingsProvider.notifier)
                              .setLocalOsrmUrl(value);
                        },
                      ),

                      const SizedBox(height: 24),

                      // آمار کش
                      _buildStatsCard(osrmStats),

                      const SizedBox(height: 24),

                      // دکمه‌های عمل
                      _buildActionButtons(ref),
                    ],
                  ),
                ),
              ),
            ),
            const BottomNav(currentPage: NavKey.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusCard(AsyncValue<bool> osrmAvailability) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.subGlassBgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subGlassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              osrmAvailability.when(
                data: (isAvailable) {
                  return Icon(
                    isAvailable
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isAvailable ? Colors.green : Colors.red,
                    size: 24,
                  );
                },
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                error: (err, st) => const Icon(
                  Icons.error_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'وضعیت سرور OSRM محلی',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    osrmAvailability.when(
                      data: (isAvailable) => Text(
                        isAvailable
                            ? '✓ سرور محلی فعال است'
                            : '✗ سرور محلی در دسترس نیست',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      loading: () => const Text(
                        'در حال بررسی...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      error: (err, st) => const Text(
                        'خطا در بررسی',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subGlassBgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subGlassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.subAccentB,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInputField({
    required String title,
    required String initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.subGlassBgSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.subGlassBorder),
          ),
          child: TextField(
            onChanged: onChanged,
            controller: TextEditingController(text: initialValue),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              hintText: 'مثال: http://192.168.1.100:5000',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.subGlassBgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subGlassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آمار',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مسیرهای کش‌شده:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '${stats['cached_routes'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'سرور محلی:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                stats['local_osrm_url'] ?? 'نامشخص',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            ref.read(offlineRoutingServiceProvider).clearCache();
            ScaffoldMessenger.of(
              navigatorKey.currentContext ?? (throw 'No context'),
            ).showSnackBar(
              const SnackBar(content: Text('کش پاک شد')),
            );
          },
          icon: const Icon(Icons.delete_rounded),
          label: const Text('پاک کردن کش'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.2),
            foregroundColor: Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            // منطق دانلود نقشه‌ها
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('دانلود نقشه‌های آفلاین'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.subAccentB.withOpacity(0.2),
            foregroundColor: AppColors.subAccentB,
          ),
        ),
      ],
    );
  }
}

// یک متغیر برای NavigatorKey (باید در main.dart تعریف شود)
final navigatorKey = GlobalKey<NavigatorState>();
