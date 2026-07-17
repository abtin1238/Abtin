import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_strings.dart';

/// مقصدهای منطقی برنامه (هم‌راستا با IndexedStack در AppShell).
class NavDest {
  static const home = 0; // خانه (نمای ناوبری)
  static const routes = 1; // مسیرها
  static const favorites = 2; // علاقه‌مندی‌ها
  static const search = 3; // جستجو
  static const voice = 4; // صدا
  static const settings = 5; // تنظیمات
}

class _Slot {
  final IconData icon;
  final String label;
  final int dest;
  final bool center;
  const _Slot(this.icon, this.label, this.dest, {this.center = false});
}

/// نوار ناوبری پایین — بازسازی پیکسل‌به‌پیکسل از تصویر مرجع:
/// یک کپسول شیشه‌ای (Glassmorphism) شناور با گوشه‌های کاملاً گرد،
/// حاشیه‌ی نیمه‌شفاف روشن، بلور پس‌زمینه، و آیتم مرکزی که به شکل
/// یک دایره‌ی برجسته با حلقه‌ی نورانی فیروزه‌ای از بدنه‌ی کپسول
/// "بیرون می‌زند" (بدون شکاف/notch در بدنه — خود دایره برجسته‌تر و
/// بزرگ‌تر از سطح کپسول است و روی آن سوار می‌شود).
///
/// دو حالت مطابق تصاویر مرجع:
///  • حالت «خانه» (نمای ناوبری): مسیرها · علاقه‌مندی‌ها · [جستجو] · صدا · تنظیمات
///  • حالت «صفحات داخلی»: جستجو · علاقه‌مندی‌ها · [خانه] · صدا · تنظیمات
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  bool get _homeVariant => currentIndex == NavDest.home;

  /// آیتم‌ها به ترتیب دیداریِ راست‌به‌چپ (RTL) مطابق عکس‌ها.
  List<_Slot> get _slots => _homeVariant
      ? const [
          _Slot(Icons.route_rounded, AppStrings.navRoutes, NavDest.routes),
          _Slot(Icons.star_rounded, AppStrings.navFavorites, NavDest.favorites),
          _Slot(Icons.search_rounded, AppStrings.navSearch, NavDest.search,
              center: true),
          _Slot(Icons.volume_up_rounded, AppStrings.navVoice, NavDest.voice),
          _Slot(Icons.settings_rounded, AppStrings.navSettings,
              NavDest.settings),
        ]
      : const [
          _Slot(Icons.search_rounded, AppStrings.navSearch, NavDest.search),
          _Slot(Icons.star_rounded, AppStrings.navFavorites, NavDest.favorites),
          _Slot(Icons.home_rounded, AppStrings.navHome, NavDest.home,
              center: true),
          _Slot(Icons.volume_up_rounded, AppStrings.navVoice, NavDest.voice),
          _Slot(Icons.settings_rounded, AppStrings.navSettings,
              NavDest.settings),
        ];

  static const double _barHeight = 64;
  static const double _hMargin = 14;
  static const double _bMargin = 10;
  static const double _radius = 32;
  static const double _centerSize = 58;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          _hMargin, 0, _hMargin, _bMargin + bottomInset * 0.4),
      child: SizedBox(
        height: _barHeight + 14, // فضای اضافه برای بیرون‌زدگی دایره مرکزی
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ---- بدنه‌ی شیشه‌ای کپسول ----
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: _slots.map((s) {
                        final active = s.dest == currentIndex;
                        return Expanded(
                          child: s.center
                              ? const SizedBox.shrink()
                              : InkWell(
                                  borderRadius:
                                      BorderRadius.circular(_radius),
                                  onTap: () => onTap(s.dest),
                                  child: _normalItem(s, active),
                                ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            // ---- دایره‌ی مرکزی برجسته با حلقه‌ی نورانی ----
            Positioned(
              bottom: (_barHeight - _centerSize) / 2 + 7,
              child: _CenterOrb(
                slot: _slots.firstWhere((s) => s.center),
                onTap: () =>
                    onTap(_slots.firstWhere((s) => s.center).dest),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _normalItem(_Slot s, bool active) {
    // فقط آیتم انتخاب‌شده سبز می‌شود؛ بقیه رنگ اولیه (سفیدِ کم‌رنگ) می‌مانند.
    final color =
        active ? AppColors.navSelected : Colors.white.withOpacity(0.72);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          s.icon,
          size: 23,
          color: color,
          // هاله‌ی نئونیِ ملایم فقط روی آیتم فعال (بسیار کم‌رنگ‌تر از قبل).
          shadows: active
              ? [
                  Shadow(
                    color: AppColors.navSelected.withOpacity(0.45),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          s.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}

/// دایره‌ی مرکزی شناور — دقیقاً مطابق عکس مرجع: پس‌زمینه‌ی تیره‌ی شیشه‌ای،
/// حلقه‌ی بیرونی سبز/فیروزه‌ای درخشان، آیکون بزرگ در وسط، لیبل زیر آن
/// خارج از دایره (روی بدنه‌ی نوار).
class _CenterOrb extends StatelessWidget {
  final _Slot slot;
  final VoidCallback onTap;
  const _CenterOrb({
    required this.slot,
    required this.onTap,
  });

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
    // دکمه‌ی مرکزی، دکمه‌ی اصلی (CTA) است و مطابق عکس مرجع همیشه سبز است،
    // اما با هاله‌ی نئونیِ ملایم (کم‌رنگ‌تر از نسخه‌ی قبل).
    const Color accent = AppColors.navSelected;
    const Color ringColor = AppColors.navSelected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B1E1A),
              border: Border.all(color: ringColor, width: 2.0),
              // هاله‌ی نئونیِ ملایم (کم‌رنگ‌تر از نسخه‌ی قبل).
              boxShadow: [
                BoxShadow(
                  color: AppColors.navSelected.withOpacity(0.30),
                  blurRadius: 14,
                ),
                BoxShadow(
                  color: AppColors.navSelected.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.navSelected.withOpacity(0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(slot.icon, color: accent, size: 26),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            slot.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}
