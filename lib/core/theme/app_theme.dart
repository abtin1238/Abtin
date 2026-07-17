import 'package:flutter/material.dart';
import 'app_colors.dart';

/// تم‌بندی سراسری برنامه (روشن/تیره) مطابق زبان طراحی تصاویر مرجع.
/// Global theming for Aabtin with full RTL + Persian typography support.
/// فونت Vazirmatn به‌صورت محلی bundle شده تا برنامه کاملاً آفلاین باشد.
class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Vazirmatn';

  static TextTheme _textTheme(Color primary, Color secondary) {
    return ThemeData(brightness: Brightness.dark)
        .textTheme
        .apply(
          fontFamily: _fontFamily,
          bodyColor: primary,
          displayColor: primary,
        );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primary,
      surface: AppColors.surfaceDark,
      onPrimary: Color(0xFF04201D),
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: scheme,
      textTheme:
          _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),
      cardColor: AppColors.cardDark,
      dividerColor: AppColors.borderDark,
      iconTheme: const IconThemeData(color: AppColors.textSecondaryDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: _switchTheme(),
      sliderTheme: _sliderTheme(),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primaryDark,
      secondary: AppColors.primary,
      surface: AppColors.surfaceLight,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
      error: AppColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: scheme,
      textTheme:
          _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
      cardColor: AppColors.cardLight,
      dividerColor: AppColors.borderLight,
      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: _switchTheme(),
      sliderTheme: _sliderTheme(),
    );
  }

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.borderDark,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  static SliderThemeData _sliderTheme() {
    return const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.borderDark,
      thumbColor: Colors.white,
      trackHeight: 4,
      overlayColor: AppColors.primaryGlow,
    );
  }
}
