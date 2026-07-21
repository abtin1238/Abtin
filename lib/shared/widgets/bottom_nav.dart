import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

enum NavKey { routes, search, home, voice, settings }

/// ترتیب پیش‌فرض [routes, search, home, voice, settings] با home در وسط.
/// وقتی صفحه‌ی فعال چیزی غیر از home باشد، آن آیتم با آیتم وسط جابه‌جا می‌شود.
///
/// بک‌گراند منو عکس `assets/images/bottom_nav_bg.png` است — یک نوار تیره با
/// یک برآمدگی (بامپ) در وسط برای دکمه‌ی اصلی. طبق نسبت واقعی عکس (۱۷۷۵×۲۷۷)
/// لبه‌ی صاف نوار (جایی که آیکون‌های کناری باید بنشینند) تقریباً از ۲۳٪
/// ارتفاع عکس به پایین شروع می‌شود؛ آیکون‌های کناری + برچسب متن روی همان
/// ناحیه‌ی صاف قرار می‌گیرند و فقط دکمه‌ی وسط داخل برآمدگی بالا می‌رود.
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

  static const double _barHeight = 108;
  static const double _imageHeight = 100;

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

  String _labelFor(NavKey key) {
    switch (key) {
      case NavKey.routes:
        return 'مسیرها';
      case NavKey.search:
        return 'جستجو';
      case NavKey.home:
        return '';
      case NavKey.voice:
        return 'صدا';
      case NavKey.settings:
        return 'تنظیمات';
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: _barHeight + bottomSafe,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // لایه بک‌گراند: عکس نوار با برآمدگی وسط
            Positioned(
              left: -8,
              right: -8,
              bottom: bottomSafe,
              child: Image.asset(
                'assets/images/bottom_nav_bg.png',
                fit: BoxFit.fill,
                height: _imageHeight,
              ),
            ),
            // لایه آیکون‌ها + برچسب — روی ناحیه‌ی صاف نوار می‌نشیند، فقط
            // آیتم وسط به داخل برآمدگی بالا می‌رود
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomSafe + 14,
              // نکته مهم (رفع باگ «ترتیب آیکون‌ها برعکس شده»): چون کل اپ با
              // Directionality.rtl کار می‌کند، یک Row معمولی این ردیف را
              // به‌صورت خودکار آینه می‌کند (اولین آیتم لیست سمت راست ظاهر
              // می‌شود، نه چپ) که ترتیب را برخلاف طرح مرجع می‌کرد. اینجا با
              // یک Directionality.ltr مستقل، ترتیب همیشه دقیقاً برابر با
              // ترتیب _defaultOrder (مسیرها → جستجو → خانه → صدا → تنظیمات
              // از چپ به راست) می‌ماند.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: order.map((key) {
                  final isActive = order.indexOf(key) == _centerSlot;
                  final isMuted = key == NavKey.voice && voiceMuted;
                  return GestureDetector(
                    onTap: () => _onTap(key),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 54 : 38,
                            height: isActive ? 54 : 38,
                            transform: isActive
                                ? (Matrix4.identity()..translate(0.0, -30.0))
                                : Matrix4.identity(),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? (widget.isHomePage ? activeColor : null)
                                  : Colors.transparent,
                              gradient:
                                  isActive && !widget.isHomePage ? activeGradient : null,
                              border: isActive
                                  ? Border.all(color: const Color(0xFF0E1219), width: 4)
                                  : null,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: (widget.isHomePage
                                                ? AppColors.homeAccent
                                                : AppColors.subAccentB)
                                            .withOpacity(.55),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _iconFor(key),
                              size: isActive ? 24 : 20,
                              color: isMuted
                                  ? AppColors.homeDanger
                                  : (isActive
                                      ? (widget.isHomePage
                                          ? const Color(0xFF0D1A12)
                                          : Colors.white)
                                      : const Color(0xFFC7CCD1)),
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(height: 4),
                            Text(
                              _labelFor(key),
                              style: const TextStyle(
                                color: Color(0xFFC7CCD1),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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
