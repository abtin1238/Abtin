import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// معادل .page-header در style.css — فقط برای صفحات داخلی (تم آبی-بنفش).
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Positioned(
            left: 0,
            child: IconButton(
              onPressed: () => context.go(backRoute),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppColors.subAccentA,
            ),
          ),
        ],
      ),
    );
  }
}
