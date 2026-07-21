import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

enum NavKey { routes, search, home, voice, settings }

/// ترتیب پیش‌فرض [routes, search, home, voice, settings] با home در وسط.
/// وقتی صفحه‌ی فعال چیزی غیر از home باشد، آن آیتم با آیتم وسط جابه‌جا می‌شود.
///
/// بک‌گراند منو عکس `assets/images/bottom_nav_bg.png` است — یک نوار تیره با
/// یک برآمدگی (بامپ) در وسط برای دکمه‌ی اصلی. طبق درخواست کاربر و عکس مرجع:
/// نوار باید کوتاه‌تر (ارتفاع کمتر) و باریک‌تر (عرض کمتر، با فاصله از لبه‌های
/// گوشی) باشد، آیکون‌ها بزرگ‌تر، و دکمه‌ی وسط دقیقاً داخل برآمدگی بنشیند
/// (نه خیلی بالاتر/پایین‌تر از آن).
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

  // نکته (رفع باگ «منو خیلی بلند/عریض است»): قبلاً ارتفاع کل نوار ۱۰۸ و عکس
  // بک‌گراند تا لبه‌های صفحه (-8/-8) کشیده می‌شد. الان طبق عکس مرجع، نوار
  // هم کوتاه‌تر شده (۷۶ به‌جای ۱۰۸) و هم باریک‌تر (با margin افقی ۱۸ از هر
  // طرف به‌جای کشیده‌شدن تا لبه‌ها).
  static const double _barHeight = 76;
  static const double _imageHeight = 70;
  static const double _horizontalMargin = 18;

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
            // لایه بک‌گراند: عکس نوار با برآمدگی وسط — با margin افقی تا
            // عرضش کمتر از عرض کامل صفحه باشد (باریک‌تر، طبق عکس مرجع)
            Positioned(
              left: _horizontalMargin,
              right: _horizontalMargin,
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
              left: _horizontalMargin + 10,
              right: _horizontalMargin + 10,
              bottom: bottomSafe + 8,
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
                      width: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            // آیکون‌ها بزرگ‌تر شدند (طبق درخواست): غیرفعال
                            // از ۳۸ به ۴۴، فعال (وسط) از ۵۴ به ۶۰.
                            width: isActive ? 60 : 44,
                            height: isActive ? 60 : 44,
                            // نکته (رفع باگ «دکمه‌ی وسط جایش خوب نیست»):
                            // چون بار کوتاه‌تر شده، دکمه‌ی وسط هم دیگر لازم
                            // نیست به‌اندازه‌ی قبل (۳۰px) بالا برود؛ فقط
                            // به‌اندازه‌ای بالا می‌رود که دقیقاً وسط برآمدگی
                            // عکس بنشیند، نه بالاتر از آن.
                            transform: isActive
                                ? (Matrix4.identity()..translate(0.0, -22.0))
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
                              size: isActive ? 28 : 24,
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
                            const SizedBox(height: 3),
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
