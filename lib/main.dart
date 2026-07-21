import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // نکته‌ی مهم (رفع مشکل «اپ می‌رود زیر ناچ/نوار وضعیت»):
  // از اندروید ۱۵ (targetSdk 35) به بعد، edge-to-edge پیش‌فرض سیستم است و
  // بدون تنظیم صریح ممکن است المان‌های UI پشت بریدگی دوربین/نوار وضعیت
  // مخفی بمانند یا رنگ آیکون‌های نوار وضعیت با پس‌زمینه‌ی اپ هم‌خوان نباشد.
  // اینجا صریحاً edge-to-edge را با آیکون‌های روشن (چون تم اپ تیره است)
  // فعال می‌کنیم؛ خود صفحات با MediaQuery.padding از این حاشیه‌ها آگاه‌اند.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const ProviderScope(child: AbtinApp()));
}

class AbtinApp extends StatelessWidget {
  const AbtinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'آبتین',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      locale: const Locale('fa'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
