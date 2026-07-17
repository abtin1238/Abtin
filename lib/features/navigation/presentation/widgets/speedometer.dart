import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nav_state.dart';

/// سرعت‌سنج دایره‌ای — دقیقاً مطابق تصویر مرجع (رینگ فلزی با درجه‌بندی فیروزه‌ای→قرمز).
///
/// تصویر واقعی `assets/gauges/speedometer.png` به‌عنوان چهره‌ی گِیج استفاده می‌شود و
/// عددِ سرعتِ لحظه‌ای (خوانده‌شده از GPS + شتاب‌سنج) روی آن نمایش داده می‌شود.
/// یک نشانگرِ نورانی متناسب با سرعت روی کمانِ درجه‌بندی حرکت می‌کند.
class Speedometer extends StatelessWidget {
  /// سرعت لحظه‌ای (km/h).
  final double speed;

  /// بیشینه‌ی مقیاس گِیج (برای موقعیت نشانگر).
  final double maxSpeed;

  /// آیا از محدودیت مجاز عبور شده است؟ (تغییر رنگ به قرمز)
  final bool overLimit;

  final double size;

  const Speedometer({
    super.key,
    required this.speed,
    this.maxSpeed = 120,
    this.overLimit = false,
    this.size = 82,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = overLimit ? AppColors.danger : Colors.white;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // چهره‌ی واقعی گِیج (تصویر مرجع)
            Image.asset('assets/gauges/speedometer.png',
                width: size, height: size, fit: BoxFit.contain),
            // نشانگرِ نورانی متناسب با سرعت
            CustomPaint(
              size: Size(size, size),
              painter: _SpeedPointerPainter(
                fraction: (speed / maxSpeed).clamp(0.0, 1.0),
                color: overLimit ? AppColors.danger : AppColors.primary,
              ),
            ),
            // عدد سرعت داینامیک
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toFa(speed.round()),
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: valueColor,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
                Text('km/h',
                    style: TextStyle(
                        fontSize: size * 0.12,
                        color: AppColors.textSecondaryDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// نشانگرِ نورانی که روی کمانِ گِیج (۲۲۵° شروع تا ۴۹۵°) متناسب با سرعت حرکت می‌کند.
class _SpeedPointerPainter extends CustomPainter {
  final double fraction;
  final Color color;
  _SpeedPointerPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    // کمانِ گِیج از پایین‌چپ (۱۳۵°) در جهت عقربه تا پایین‌راست (۴۰۵°) = ۲۷۰°.
    const startDeg = 135.0;
    const sweepDeg = 270.0;
    final angle = (startDeg + sweepDeg * fraction) * math.pi / 180.0;
    final dot = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final glow = Paint()
      ..color = color.withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(dot, 4.5, glow);
    canvas.drawCircle(dot, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpeedPointerPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// نشانگر محدودیت سرعت (رینگ قرمز) — دقیقاً مطابق تصویر مرجع.
///
/// تصویر واقعی `assets/gauges/speed_limit.png` استفاده می‌شود و عددِ محدودیتِ
/// خوانده‌شده از نقشه روی آن نمایش داده می‌شود. این ویجت فقط هنگام نزدیک‌شدن به
/// محدوده‌ی سرعت نمایش داده می‌شود (کنترل در صفحه‌ی ناوبری).
class SpeedLimitSign extends StatelessWidget {
  final int limit;
  final double size;
  const SpeedLimitSign({super.key, required this.limit, this.size = 82});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset('assets/gauges/speed_limit.png',
                width: size, height: size, fit: BoxFit.contain),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toFa(limit),
                  style: TextStyle(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
                Text('km/h',
                    style: TextStyle(
                        fontSize: size * 0.12,
                        color: Colors.white.withOpacity(0.75))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
