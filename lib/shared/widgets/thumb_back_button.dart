import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// دکمه‌ی برگشت شناور که پایین صفحه (کنار BottomNav، در محدوده‌ی راحت شست
/// دست) قرار می‌گیرد.
///
/// نکته‌ی مهم (رفع درخواست کاربر «دکمه برگشت رو جایی بزار که بشه دست‌ش
/// داشت، الان زیر ناچ گوشیه»): قبلاً این دکمه بالای صفحه، زیر بریدگی
/// دوربین/نوار وضعیت (notch) بود — جایی که با یک دست نگه‌داشتن گوشی، شست
/// عملاً به آن نمی‌رسد. الان همان دکمه پایین صفحه، بالای نوار ناوبری پایین
/// (BottomNav) و در گوشه‌ای که با شست راحت لمس می‌شود، شناور است.
class ThumbBackButton extends StatelessWidget {
  final String backRoute;

  const ThumbBackButton({super.key, this.backRoute = '/'});

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Positioned(
      // گوشه‌ی پایین-چپ: خارج از محدوده‌ی نوار ناوبری وسط و آیتم‌های آن،
      // و در دسترس شست دست هنگام نگه‌داشتن گوشی با یک دست.
      left: 16,
      bottom: bottomSafe + 104,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(backRoute);
            }
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1B42).withOpacity(.9),
              border: Border.all(color: AppColors.subGlassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.subAccentA,
            ),
          ),
        ),
      ),
    );
  }
}
