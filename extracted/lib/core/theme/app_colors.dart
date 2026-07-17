import 'package:flutter/material.dart';

/// پالت رنگی آبتین بر اساس تصاویر مرجع (تم تیره فیروزه‌ای + لهجه طلایی برند).
/// AabtinColors — the exact palette extracted from the reference screenshots.
class AppColors {
  AppColors._();

  // ---- Brand ----
  /// فیروزه‌ای اصلی برنامه (دکمه‌ها، آیکون فعال، مسیر پیش‌فرض).
  static const Color primary = Color(0xFF00E5D0);
  static const Color primaryDark = Color(0xFF00B5A5);
  static const Color primaryGlow = Color(0x3300E5D0);

  /// سبزِ آیتم انتخاب‌شده‌ی نوار پایین (مطابق عکس مرجع و دکمه‌ی «شروع مسیریابی»).
  /// فقط آیتم انتخاب‌شده این رنگ را می‌گیرد؛ بقیه با رنگ اولیه‌ی خنثی می‌مانند.
  static const Color navSelected = Color(0xFF22C55E);

  /// طلایی برند «آبتین» (لوگو / لهجه‌های ویژه).
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0xFFE8C96A);

  // ---- Dark theme (default) ----
  static const Color bgDark = Color(0xFF0A0E1A);
  static const Color surfaceDark = Color(0xFF121826);
  static const Color surfaceElevatedDark = Color(0xFF1A2233);
  static const Color cardDark = Color(0xFF141B2B);
  static const Color borderDark = Color(0xFF232C40);

  static const Color textPrimaryDark = Color(0xFFF2F5FA);
  static const Color textSecondaryDark = Color(0xFF97A2B8);
  static const Color textMutedDark = Color(0xFF5C6883);

  // ---- Light theme ----
  static const Color bgLight = Color(0xFFF4F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE3E9F2);

  static const Color textPrimaryLight = Color(0xFF0A0E1A);
  static const Color textSecondaryLight = Color(0xFF4A5568);
  static const Color textMutedLight = Color(0xFF94A0B4);

  // ---- Route palette (from routing settings screen) ----
  static const List<Color> routeColors = [
    Color(0xFF00E5D0), // فیروزه‌ای
    Color(0xFF2563EB), // آبی
    Color(0xFF22C55E), // سبز
    Color(0xFFF97316), // نارنجی
    Color(0xFF8B5CF6), // بنفش
    Color(0xFFEC4899), // صورتی
    Color(0xFFFFFFFF), // سفید
  ];

  // ---- Semantic ----
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color speedLimit = Color(0xFFEF4444);

  // ---- POI category colors ----
  static const Color poiRestaurant = Color(0xFFF59E0B);
  static const Color poiCafe = Color(0xFF10B981);
  static const Color poiShopping = Color(0xFFF97316);
  static const Color poiHotel = Color(0xFF06B6D4);
  static const Color poiPark = Color(0xFF22C55E);
  static const Color poiFuel = Color(0xFF3B82F6);
  static const Color poiParking = Color(0xFF2563EB);
  static const Color poiFamily = Color(0xFF8B5CF6);
}
