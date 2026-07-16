import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap.dart';
import 'core/constants/app_strings.dart';
import 'core/deeplink/deeplink_parser.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_notification_banner.dart';
import 'core/widgets/app_shell.dart';
import 'features/navigation/data/navigation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final bootstrap = await AppBootstrap.init();

  runApp(
    ProviderScope(
      overrides: [
        appBootstrapProvider.overrideWithValue(bootstrap),
        routingServiceProvider.overrideWithValue(bootstrap.routingService),
      ],
      child: const AabtinApp(),
    ),
  );
}

/// ریشهٔ برنامهٔ «آبتین» با پشتیبانی کامل RTL و تم داینامیک.
class AabtinApp extends ConsumerStatefulWidget {
  const AabtinApp({super.key});

  @override
  ConsumerState<AabtinApp> createState() => _AabtinAppState();
}

class _AabtinAppState extends ConsumerState<AabtinApp> {
  static const _links = MethodChannel('ir.abtin.navigator/deeplink');
  final _parser = const DeeplinkParser();

  @override
  void initState() {
    super.initState();
    _links.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final uri = call.arguments as String?;
        if (uri != null) await _handleLink(uri);
      }
    });
  }

  Future<void> _handleLink(String uri) async {
    final dest = _parser.parse(uri);
    if (dest == null) return;
    final notifier = ref.read(appNotificationProvider.notifier);
    notifier.show('مقصد از لینک خارجی دریافت شد', type: AppNotifyType.info);
    try {
      final nav = ref.read(navigationControllerProvider);
      final origin = nav.position ?? defaultMapCenter;
      final route = await ref.read(routingServiceProvider).route(
            origin,
            dest.location,
          );
      ref.read(navigationControllerProvider.notifier).startRoute(route);
      ref.read(bottomNavIndexProvider.notifier).state = 0;
      notifier.show(
        dest.title == null
            ? 'مسیریابی آغاز شد'
            : 'مسیریابی به ${dest.title}',
        type: AppNotifyType.success,
      );
    } catch (e) {
      notifier.show('خطا در مسیر از لینک: $e', type: AppNotifyType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: AppNotificationOverlay(child: child!),
      ),
      home: const AppShell(),
    );
  }
}
