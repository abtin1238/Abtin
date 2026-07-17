import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nav_state.dart';

/// تابلوی هشدارِ زیرِ نوارِ بالا — **فقط** دو نوعِ هشدار را نمایش می‌دهد:
/// دوربینِ کنترلِ سرعت و سرعت‌گیر. سایرِ هشدارهای محلی (مدرسه، تونل و ...)
/// هرگز روی این تابلو ظاهر نمی‌شوند و فقط با صدا اعلام می‌شوند.
class HazardBanner extends StatelessWidget {
  final HazardBannerInfo info;
  const HazardBanner({super.key, required this.info});

  IconData get _icon {
    switch (info.type) {
      case HazardBannerType.speedCamera:
        return Icons.camera_alt_rounded;
      case HazardBannerType.speedBump:
        return Icons.speed_rounded;
    }
  }

  String get _label {
    switch (info.type) {
      case HazardBannerType.speedCamera:
        return 'دوربین کنترل سرعت';
      case HazardBannerType.speedBump:
        return 'سرعت‌گیر';
    }
  }

  String get _distanceLabel {
    final d = info.distanceMeters;
    if (d >= 1000) return '${toFa((d / 1000).toStringAsFixed(1))} کیلومتر';
    return '${toFa((d / 10).round() * 10)} متر';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2B1B0E).withOpacity(0.88),
                const Color(0xFF221407).withOpacity(0.82),
              ],
            ),
            border: Border.all(color: AppColors.warning.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20),
              BoxShadow(color: AppColors.warning.withOpacity(0.18), blurRadius: 14),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withOpacity(0.16),
                  border: Border.all(color: AppColors.warning.withOpacity(0.55)),
                ),
                child: Icon(_icon, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    Text(
                      _distanceLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
