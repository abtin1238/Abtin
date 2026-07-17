import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// نشانگر موقعیت روی نقشه: یک **پیکانِ سه‌بعدیِ نارنجیِ براق** (Navigation Arrow)
/// دقیقاً مطابق تصویر مرجع — نه ماشینِ تخت/خراب.
///
/// طراحی: یک پیکانِ ناوبری با گرادیانِ نارنجی، برجستگیِ مرکزی (تیغه) برای حسِ
/// سه‌بعدی، لبه‌ی شیشه‌ایِ روشن، و هاله‌ی نرمِ زیرین برای تماسِ بصری با نقشه.
/// با تغییرِ [headingDeg] در فضا می‌چرخد.
class CarMarker extends StatelessWidget {
  final double headingDeg;
  final bool headlights;
  const CarMarker({
    super.key,
    required this.headingDeg,
    this.headlights = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(84, 84),
        painter: _NavArrow3DPainter(
          headingDeg: headingDeg,
          beam: headlights,
        ),
      ),
    );
  }
}

/// پیکانِ ناوبریِ سه‌بعدیِ نارنجی — با تیغه‌ی مرکزی و لبه‌ی شیشه‌ای.
class _NavArrow3DPainter extends CustomPainter {
  final double headingDeg;
  final bool beam;
  _NavArrow3DPainter({required this.headingDeg, required this.beam});

  // رنگ‌های نارنجیِ مطابق تصویر مرجع.
  static const _orangeLight = Color(0xFFFFB74D);
  static const _orange = Color(0xFFFF8A1E);
  static const _orangeDeep = Color(0xFFEF6C00);
  static const _rim = Color(0xFFFFE0B2);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(headingDeg * math.pi / 180.0);

    // نقاطِ پیکان (رو به بالا) در فضای محلی.
    const double h = 30; // نصفِ ارتفاع
    const double w = 24; // نصفِ عرضِ بال‌ها
    final tip = const Offset(0, -h);
    final rightWing = const Offset(w, h * 0.9);
    final notch = const Offset(0, h * 0.35); // فرورفتگیِ پایین
    final leftWing = const Offset(-w, h * 0.9);

    // ---- هاله‌ی نرمِ زیرین (تماس با نقشه) ----
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 20), width: 46, height: 16),
      Paint()
        ..color = _orange.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ---- مخروطِ نورِ جهت‌دهنده (اختیاری) ----
    if (beam) {
      final beamPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(-16, -h - 26)
        ..lineTo(16, -h - 26)
        ..close();
      canvas.drawPath(
        beamPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0x66FFB74D), Color(0x00FFB74D)],
          ).createShader(Rect.fromLTWH(-16, -h - 26, 32, 26)),
      );
    }

    // ---- نیمه‌ی چپِ پیکان (روشن‌تر) ----
    final leftFace = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..lineTo(notch.dx, notch.dy)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_orangeLight, _orange],
        ).createShader(Rect.fromLTWH(-w, -h, w, h * 2)),
    );

    // ---- نیمه‌ی راستِ پیکان (تیره‌تر برای حسِ سه‌بعدی) ----
    final rightFace = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..lineTo(notch.dx, notch.dy)
      ..close();
    canvas.drawPath(
      rightFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_orange, _orangeDeep],
        ).createShader(Rect.fromLTWH(0, -h, w, h * 2)),
    );

    // ---- تیغه‌ی مرکزی (خطِ برجسته‌ی روشن) ----
    canvas.drawLine(
      tip,
      notch,
      Paint()
        ..color = _rim.withOpacity(0.9)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // ---- درخششِ نوکِ پیکان ----
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 6, tip.dy + 12)
        ..lineTo(tip.dx + 6, tip.dy + 12)
        ..close(),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // ---- لبه‌ی شیشه‌ایِ روشن دورِ کلِ پیکان ----
    final outline = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = _rim
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.6),
    );
    // هاله‌ی بیرونیِ نارنجی روی لبه.
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.primary.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NavArrow3DPainter old) =>
      old.headingDeg != headingDeg || old.beam != beam;
}
