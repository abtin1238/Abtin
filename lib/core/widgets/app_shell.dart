import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'app_bottom_nav.dart';
import '../../features/navigation/presentation/screens/navigation_screen.dart';
import '../../features/routing/presentation/screens/routes_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/voice/presentation/screens/voice_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// پوسته‌ی اصلی برنامه با IndexedStack برای حفظ وضعیت هر تب.
/// ترتیب فرزندان دقیقاً با ثابت‌های [NavDest] هم‌راستاست.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomNavIndexProvider);
    // نوار پایین به‌صورت شناور (Positioned) روی بدنه قرار می‌گیرد نه به‌عنوان
    // bottomNavigationBar مجزا — این‌طور BackdropFilter می‌تواند محتوای
    // پشت خودش (نقشه/صفحه) را واقعاً بلور کند و افکت شیشه‌ای واقعی شود.
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: index,
            children: const [
              NavigationScreen(), // 0 خانه
              RoutesScreen(), // 1 مسیرها
              FavoritesScreen(), // 2 علاقه‌مندی‌ها
              SearchScreen(), // 3 جستجو
              VoiceScreen(), // 4 صدا
              SettingsScreen(), // 5 تنظیمات
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              currentIndex: index,
              onTap: (i) =>
                  ref.read(bottomNavIndexProvider.notifier).state = i,
            ),
          ),
        ],
      ),
    );
  }
}
