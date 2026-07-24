import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// معادل .page-header در style.css — فقط برای صفحات داخلی (تم آبی-بنفش).
///
/// نکته‌ی مهم (رفع درخواست کاربر «دکمه برگشت رو جایی بزار که بشه دست‌ش
/// داشت، الان زیر ناچ گوشیه»): دکمه‌ی برگشت از اینجا (بالای صفحه، زیر
/// بریدگی دوربین) حذف شد و به [ThumbBackButton] در پایین صفحه منتقل شده —
/// هر صفحه‌ای که از این هدر استفاده می‌کند، آن ویجت را هم در Stack خودش دارد.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String backRoute;

  const PageHeader({super.key, required this.title, this.backRoute = '/'});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple.shade900.withOpacity(.35), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.subGlassBorder),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
