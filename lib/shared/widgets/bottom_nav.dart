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
  static const double _barHeight = 96;
  static const double _imageHeight = 90;
  static const double _horizontalMargin = 10;

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
        return Icons.home_rounded;
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
    // نکته‌ی مهم (رفع باگ «دکمه‌ی برگشت گوشی کلاً از اپ خارج می‌شود»):
    // قبلاً همه‌جا از context.go() استفاده می‌شد. go() کل پشته‌ی ناوبری را پاک
    // کرده و فقط مسیر جدید را جایگزین می‌کند، پس همیشه فقط یک صفحه در پشته
    // باقی می‌ماند. در نتیجه وقتی کاربر دکمه‌ی فیزیکی/سیستمی برگشت گوشی را
    // می‌زد، چیزی برای pop کردن وجود نداشت و کل اپ بسته می‌شد. الان فقط رفتن
    // به «خانه» با go() به ریشه‌ی پشته برمی‌گردد (چون خانه نقطه‌ی شروع منطقی
    // است)، و بقیه‌ی صفحات با push() روی پشته اضافه می‌شوند تا دکمه‌ی برگشت
    // گوشی بتواند یک مرحله واقعی به عقب برگردد، نه این‌که اپ را ببندد.
    switch (key) {
      case NavKey.home:
        context.go('/');
        break;
      case NavKey.routes:
        context.push('/routes');
        break;
      case NavKey.search:
        context.push('/search');
        break;
      case NavKey.settings:
        context.push('/settings');
        break;
      case NavKey.voice:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _buildOrder(widget.currentPage);
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
            // لایه آیکون‌ها — روی ناحیه‌ی صاف نوار می‌نشیند، فقط آیتم وسط به
            // داخل برآمدگی بالا می‌رود. نکته (رفع باگ «نوشته‌های زیر
            // آیکون‌ها اضافه‌اند»): طبق درخواست، برچسب متنی زیر آیکون‌ها
            // کاملاً حذف شد؛ در نتیجه دیگر لازم نیست ارتفاعی برای متن رزرو
            // شود، پس همه‌ی آیکون‌ها (نه فقط متن) روی یک خط وسط‌چین می‌شوند.
            Positioned(
              left: _horizontalMargin + 10,
              right: _horizontalMargin + 10,
              // نکته (رفع باگ «آیکون‌ها بالاتر از جای استاندارد»): طبق
              // بازخورد کاربر، کل ردیف آیکون‌ها حداقل ۵px پایین‌تر آمد
              // (از bottomSafe+8 به bottomSafe+2).
              bottom: bottomSafe + 2,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: order.map((key) {
                    final isActive = order.indexOf(key) == _centerSlot;
                    final isMuted = key == NavKey.voice && voiceMuted;
                    return GestureDetector(
                      onTap: () => _onTap(key),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            // نوار بزرگ‌تر شد (طبق درخواست، مورد ۴): آیکون‌ها
                            // هم متناسب با آن بزرگ‌تر شدند — غیرفعال از ۴۴ به
                            // ۵۰. دکمه‌ی وسط (فعال) طبق بازخورد بعدی کاربر
                            // دوباره کوچک‌تر شد (از ۶۸ به ۵۸) تا کمتر از حد
                            // چشمگیر بزرگ به‌نظر برسد.
                            width: isActive ? 58 : 50,
                            height: isActive ? 58 : 50,
                            // نکته (رفع باگ «دکمه‌ی وسط خیلی بالاست»): قبلاً
                            // با حذف برچسب متنی زیر آیکون‌ها، دیگر لازم
                            // نیست دکمه‌ی وسط به‌اندازه‌ی قبل (۲۲px) بالا
                            // برود؛ الان کمتر بالا می‌رود تا دقیقاً داخل
                            // برآمدگی عکس بنشیند، نه بالاتر از آن. عدد کمی
                            // کمتر شد (-۱۰ به‌جای -۱۲) چون خودِ دکمه هم
                            // کوچک‌تر شده.
                            transform: isActive
                                ? (Matrix4.identity()..translate(0.0, -10.0))
                                : Matrix4.identity(),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // نکته (رفع باگ «رنگ دکمه‌ی وسط بین صفحات فرق
                              // می‌کند» + بازخورد بعدی کاربر برای گرادینت
                              // آبی-بنفش): دکمه‌ی وسط حالا از همان گرادینت
                              // آبی→بنفش استاندارد صفحات داخلی
                              // (subAccentGradient) استفاده می‌کند، به‌جای
                              // گرادینت سبز→آبی قبلی.
                              gradient: isActive ? AppColors.subAccentGradient : null,
                              color: isActive ? null : Colors.transparent,
                              border: isActive
                                  ? Border.all(color: const Color(0xFF0E1219), width: 4)
                                  : null,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.subAccentB,
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _iconFor(key),
                              size: isActive ? 28 : 26,
                              color: isMuted
                                  ? AppColors.homeDanger
                                  : (isActive ? Colors.white : const Color(0xFFC7CCD1)),
                            ),
                          ),
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
