import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/gps/presentation/gps_providers.dart';

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

class AbtinApp extends ConsumerStatefulWidget {
  const AbtinApp({super.key});

  @override
  ConsumerState<AbtinApp> createState() => _AbtinAppState();
}

/// نکته‌ی مهم (بخشی از رفع باگ «نوتیفیکیشن GPS هیچ‌وقت به‌روزرسانی نمی‌شود»):
/// وقتی کاربر برای روشن‌کردن GPS/دادن مجوز به صفحه‌ی تنظیمات اندروید می‌رود
/// و به اپ برمی‌گردد، هیچ استریمی در پکیج geolocator برای «تغییر مجوز» وجود
/// ندارد (فقط برای روشن/خاموش شدن خودِ GPS استریم هست). پس با
/// WidgetsBindingObserver لحظه‌ی resume شدن اپ را می‌گیریم و
/// [locationLifecycleTickProvider] را افزایش می‌دهیم تا gps_providers.dart
/// دوباره وضعیت را (بدون باز کردن دوباره‌ی دیالوگ) چک کند.
class _AbtinAppState extends ConsumerState<AbtinApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationLifecycleTickProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مسیریاب آبتین',
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
