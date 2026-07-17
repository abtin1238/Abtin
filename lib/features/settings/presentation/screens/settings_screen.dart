import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../routing/presentation/screens/routing_settings_screen.dart';
import 'offline_maps_screen.dart';
import 'offline_graphs_screen.dart';
import '../../../ar/presentation/screens/ar_navigation_screen.dart';

/// یک ردیف تنظیمات با آیکون و توضیح.
class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;
  const _SettingItem(this.icon, this.title, this.subtitle, {this.page});
}

/// صفحه‌ی تنظیمات اصلی (مطابق تصویر «تنظیمات»).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navItems = <_SettingItem>[
      _SettingItem(Icons.navigation_rounded, AppStrings.routingSettings,
          'مسیرها، رنگ مسیر، خودرو و اعلان‌های مسیر',
          page: const RoutingSettingsScreen()),
      const _SettingItem(Icons.map_rounded, AppStrings.mapSettings,
          'نمایش نقشه، لایه‌ها و دانلود نقشه‌ها',
          page: const OfflineMapsScreen()),
      const _SettingItem(Icons.hub_rounded, 'گراف مسیریابی آفلاین',
          'انتخاب گراف استان برای مسیر A*',
          page: const OfflineGraphsScreen()),
      const _SettingItem(Icons.view_in_ar_rounded, 'ناوبری AR',
          'نمایش مسیر و فلش روی تصویر دوربین',
          page: const ArNavigationScreen()),
      const _SettingItem(Icons.brightness_6_rounded, AppStrings.displaySettings,
          'ظاهر برنامه، تم و اندازه‌های نمایش'),
      const _SettingItem(Icons.volume_up_rounded, AppStrings.soundSettings,
          'راهنمای صوتی، صداها و اعلان‌ها'),
      const _SettingItem(Icons.warning_amber_rounded,
          AppStrings.trafficSettings, 'ترافیک لحظه‌ای، هشدارها و دوربین‌ها'),
    ];

    final accountItems = const <_SettingItem>[
      _SettingItem(Icons.person_rounded, 'حساب کاربری',
          'ورود، همگام‌سازی و مدیریت حساب'),
      _SettingItem(Icons.star_rounded, 'علاقه‌مندی‌ها و مکان‌ها',
          'خانه، محل کار و مکان‌های ذخیره‌شده'),
      _SettingItem(Icons.history_rounded, 'تاریخچه مسیرها',
          'مسیرهای اخیر و جستجوها'),
    ];

    final generalItems = const <_SettingItem>[
      _SettingItem(Icons.language_rounded, 'زبان و واحدها',
          'زبان برنامه، واحدها و قالب زمان'),
      _SettingItem(Icons.lock_rounded, 'حریم خصوصی',
          'مجوزها و مدیریت داده‌ها'),
      _SettingItem(Icons.info_outline_rounded, 'درباره برنامه',
          'نسخه برنامه و اطلاعات بیشتر'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          _profileCard(),
          const SectionHeader('مسیریابی و ناوبری'),
          ...navItems.map((e) => _row(context, e)),
          const SectionHeader('حساب کاربری و داده‌ها'),
          ...accountItems.map((e) => _row(context, e)),
          const SectionHeader('عمومی'),
          ...generalItems.map((e) => _row(context, e)),
          const SizedBox(height: 8),
          _themeSwitcher(ref),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          const GlowIcon(Icons.person_outline_rounded, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(AppStrings.guestUser,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(AppStrings.signInPrompt,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryDark)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _SettingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: item.page == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => item.page!),
                ),
        leading: Icon(item.icon, color: AppColors.primary),
        title: Text(item.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_left_rounded,
            color: AppColors.textMutedDark),
      ),
    );
  }

  Widget _themeSwitcher(WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.dark_mode_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('تم تیره',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: mode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                v ? ThemeMode.dark : ThemeMode.light,
          ),
        ],
      ),
    );
  }
}
