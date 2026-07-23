import 'package:flutter/material.dart';

/// رنگ‌های استخراج‌شده مستقیم از پروژه‌ی HTML اصلی (css/style.css) و تم آبی-بنفش
/// (css/theme-pages.css) تا ظاهر دقیقاً یکسان بماند.
class AppColors {
  AppColors._();

  // پس‌زمینه‌ها
  static const background = Color(0xFF0A0C10);
  static const frameBackground = Color(0xFF05070A);

  // تم "خانه" (صفحه اصلی ناوبری) — سبز، بدون تغییر
  static const homeAccent = Color(0xFF3EE66B);
  static const homeAccentDark = Color(0xFF123A34);
  static const homeDanger = Color(0xFFE5544B);

  // تم صفحات داخلی (جستجو/تنظیمات/مسیرها/صدا) — آبی به بنفش + گلس‌مورفیسم
  static const subAccentA = Color(0xFF5AA4FF); // آبی
  static const subAccentB = Color(0xFF9B6BFF); // بنفش
  static const subGlassBg = Color(0x483C376E); // rgba(60,55,110,.28)
  static const subGlassBgSoft = Color(0x38464682); // rgba(60,70,130,.22)
  static const subGlassBorder = Color(0x47BEB4FF); // rgba(190,180,255,.28)

  static LinearGradient get subAccentGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [subAccentA, subAccentB],
      );

  /// گرادینت سبز→آبی مشترک برای المان‌هایی که باید در همه‌ی صفحات (چه صفحه‌ی
  /// اصلی سبز، چه صفحات داخلی آبی-بنفش) ظاهر یکسان داشته باشند — مثل دکمه‌ی
  /// وسط منوی پایین.
  static LinearGradient get centerButtonGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [homeAccent, subAccentA],
      );

  // متن‌ها
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9AA4B0);
  static const textMuted = Color(0xFF8B929B);
}
