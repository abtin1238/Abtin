import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

enum NavKey { routes, search, home, voice, settings }

/// معادل دقیق js/bottom-nav.js + css (.bottom-semicircle + .bottom-cylinder):
/// ترتیب پیش‌فرض [routes, search, home, voice, settings] با home در وسط.
/// وقتی صفحه‌ی فعال چیزی غیر از home باشد، آن آیتم با آیتم وسط جابه‌جا می‌شود.
///
/// ظاهر دو لایه است:
/// 1) bottom-semicircle: یک نیم‌بیضی پهن که کمی از پایین صفحه بالا آمده (دکِ گرد)
/// 2) bottom-cylinder: نوار قرصی‌شکل باریک‌تر که روی نیم‌بیضی سوار است و آیکون‌ها داخل آن‌اند
class BottomNav extends StatefulWidget {
  final NavKey currentPage;
  final bool isHomePage; // برای تعیین رنگ تم (سبز صفحه اصلی / آبی‌بنفش بقیه)

  const BottomNav({
    super.key,
    required this.currentPage,
    this.isHomePage = false,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  bool voiceMuted = false;

  static const List<NavKey> _defaultOrder = [
    NavKey.routes,
    NavKey.search,
    NavKey.home,
    NavKey.voice,
    NavKey.settings,
  ];
  static const int _centerSlot = 2;

  List<NavKey> _buildOrder(NavKey current) {
    final order = List<NavKey>.from(_defaultOrder);
    if (current != NavKey.home) {
      final idx = order.indexOf(current);
      if (idx != -1) {
        final tmp = order[idx];
        order[idx] = order[_centerSlot];
        order[_centerSlot] = tmp;
      }
    }
    return order;
  }

  IconData _iconFor(NavKey key) {
    switch (key) {
      case NavKey.routes:
        return Icons.alt_route_rounded;
      case NavKey.search:
        return Icons.search_rounded;
      case NavKey.home:
        return Icons.navigation_rounded;
      case NavKey.voice:
        return voiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded;
      case NavKey.settings:
        return Icons.settings_rounded;
    }
  }

  void _onTap(NavKey key) {
    if (key == NavKey.voice) {
      setState(() => voiceMuted = !voiceMuted);
      return;
    }
    switch (key) {
      case NavKey.home:
        context.go('/');
        break;
      case NavKey.routes:
        context.go('/routes');
        break;
      case NavKey.search:
        context.go('/search');
        break;
      case NavKey.settings:
        context.go('/settings');
        break;
      case NavKey.voice:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _buildOrder(widget.currentPage);
    final activeGradient =
        widget.isHomePage ? null : AppColors.subAccentGradient;
    final activeColor = widget.isHomePage ? AppColors.homeAccent : null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // لایه ۱: نیم‌بیضی پهن (دک) که کمی از پایین صفحه بالا آمده
            Positioned(
              bottom: 5,
              left: -60,
              right: -60,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.elliptical(600, 60),
                    topRight: Radius.elliptical(600, 60),
                  ),
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.4,
                    colors: widget.isHomePage
                        ? [const Color(0xF2282F38), const Color(0xF80A0D12)]
                        : [const Color(0xE6322C5F), const Color(0xF7181432)],
                    stops: const [0.0, 0.85],
                  ),
                  border: const Border(
                    top: BorderSide(color: Colors.white12),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, -8)),
                  ],
                ),
              ),
            ),
            // لایه ۲: نوار قرصی‌شکل باریک‌تر با آیکون‌ها، روی نیم‌بیضی سوار است
            Positioned(
              left: 20,
              right: 20,
              bottom: 25,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isHomePage
                        ? [const Color(0xF2262C34), const Color(0xF2101418)]
                        : [const Color(0xA6322C5F), const Color(0xBF181432)],
                  ),
                  border: Border.all(
                    color: widget.isHomePage
                        ? Colors.white.withOpacity(.08)
                        : AppColors.subGlassBorder,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: order.map((key) {
                    final isActive = order.indexOf(key) == _centerSlot;
                    final isMuted = key == NavKey.voice && voiceMuted;
                    return GestureDetector(
                      onTap: () => _onTap(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 48 : 40,
                        height: isActive ? 48 : 40,
                        transform: isActive
                            ? (Matrix4.identity()..translate(0.0, -14.0))
                            : Matrix4.identity(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? (widget.isHomePage ? activeColor : null)
                              : Colors.transparent,
                          gradient: isActive && !widget.isHomePage ? activeGradient : null,
                          border: isActive
                              ? Border.all(color: const Color(0xFF0E1219), width: 4)
                              : null,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: (widget.isHomePage
                                            ? AppColors.homeAccent
                                            : AppColors.subAccentB)
                                        .withOpacity(.5),
                                    blurRadius: 14,
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          _iconFor(key),
                          size: isActive ? 22 : 20,
                          color: isMuted
                              ? AppColors.homeDanger
                              : (isActive
                                  ? (widget.isHomePage ? const Color(0xFF0D1A12) : Colors.white)
                                  : const Color(0xFFC7CCD1)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
