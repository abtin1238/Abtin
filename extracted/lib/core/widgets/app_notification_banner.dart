import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

/// نوعِ نوتیفیکیشنِ نمایش داده‌شده در نوارِ بالای اپ.
enum AppNotifyType { info, success, error, loading }

class AppNotifyData {
  final String message;
  final AppNotifyType type;
  const AppNotifyData(this.message, this.type);
}

/// کنترلرِ سراسریِ نوتیفیکیشنِ بالای اپ.
class AppNotificationController extends StateNotifier<AppNotifyData?> {
  AppNotificationController() : super(null);
  Timer? _timer;

  void show(
    String message, {
    AppNotifyType type = AppNotifyType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _timer?.cancel();
    state = AppNotifyData(message, type);
    // نوتیفیکیشن‌های «در حالِ بارگذاری» تا فراخوانیِ صریحِ hide باقی می‌مانند.
    if (type != AppNotifyType.loading) {
      _timer = Timer(duration, hide);
    }
  }

  void hide() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final appNotificationProvider =
    StateNotifierProvider<AppNotificationController, AppNotifyData?>(
        (ref) => AppNotificationController());

/// پوششِ سراسریِ نمایشِ نوتیفیکیشن — در ریشه‌ی برنامه (main.dart) دورِ
/// AppShell قرار می‌گیرد تا روی همه‌ی صفحه‌ها، با همان استایلِ شیشه‌ایِ
/// نوارِ پایین، در بالای صفحه ظاهر شود.
class AppNotificationOverlay extends ConsumerWidget {
  final Widget child;
  const AppNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appNotificationProvider);
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      textDirection: TextDirection.rtl,
      children: [
        child,
        Positioned(
          top: topInset + 8,
          left: 14,
          right: 14,
          child: IgnorePointer(
            ignoring: data == null,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: data == null ? const Offset(0, -1.4) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: data == null ? 0 : 1,
                child: data == null
                    ? const SizedBox(height: 0)
                    : _BannerCard(data: data),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final AppNotifyData data;
  const _BannerCard({required this.data});

  Color get _accent {
    switch (data.type) {
      case AppNotifyType.success:
        return AppColors.navSelected;
      case AppNotifyType.error:
        return AppColors.danger;
      case AppNotifyType.loading:
        return AppColors.primary;
      case AppNotifyType.info:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (data.type) {
      case AppNotifyType.success:
        return Icons.check_circle_rounded;
      case AppNotifyType.error:
        return Icons.error_rounded;
      case AppNotifyType.loading:
        return Icons.autorenew_rounded;
      case AppNotifyType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0E1524).withOpacity(0.92),
                const Color(0xFF0E1524).withOpacity(0.86),
              ],
            ),
            border: Border.all(color: _accent.withOpacity(0.45), width: 1.1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 22),
              BoxShadow(color: _accent.withOpacity(0.16), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              if (data.type == AppNotifyType.loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(_accent),
                  ),
                )
              else
                Icon(_icon, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
