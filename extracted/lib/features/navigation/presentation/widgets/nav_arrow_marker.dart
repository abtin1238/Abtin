import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// نشانگرِ موقعیتِ کاربر روی نقشه: **پیکانِ سه‌بعدیِ شیشه‌ای نارنجی**
/// دقیقاً مطابق تصویرِ مرجع — بدنه‌ی گلاسی با لبه‌ی روشنِ شیشه‌ای، خط‌تیزِ
/// میانی (که دو وجه را با روشناییِ متفاوت از هم جدا می‌کند و حسِ برجستگیِ
/// سه‌بعدی می‌دهد)، هایلایتِ نرمِ بالا-چپ و هاله‌ی نارنجیِ محوشونده در پایه.
///
/// جهتِ حرکت (heading) با چرخشِ واقعیِ شکل روی صفحه اعمال می‌شود؛ هنگامِ
/// ناوبریِ فعال، نقشه خودش حولِ خودرو می‌چرخد و این پیکان همیشه رو به بالا
/// (جلو) باقی می‌ماند.
class NavArrowMarker extends StatelessWidget {
  final double headingDeg;
  final bool headlights;
  const NavArrowMarker({
    super.key,
    required this.headingDeg,
    this.headlights = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(76, 84),
        painter: _NavArrowPainter(
          headingDeg: headingDeg,
          glow: headlights,
        ),
      ),
    );
  }
}

class _NavArrowPainter extends CustomPainter {
  final double headingDeg;
  final bool glow;
  _NavArrowPainter({required this.headingDeg, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);

    // ---- هاله‌ی نارنجیِ نرم زیرِ پیکان (تماسِ بصری با نقشه) ----
    canvas.drawOval(
      Rect.fromCenter(center: center + const Offset(0, 26), width: 46, height: 16),
      Paint()
        ..color = AppColors.arrowGlow.withOpacity(glow ? 0.45 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(headingDeg * math.pi / 180.0);
    canvas.translate(-center.dx, -center.dy);

    // ---- هندسه‌ی پیکان (نوکِ جلو، دو بالِ عقب، بریدگیِ مقعرِ میانی) ----
    final tip = center + const Offset(0, -32);
    final wingL = center + const Offset(-24, 22);
    final wingR = center + const Offset(24, 22);
    final notch = center + const Offset(0, 6);

    final outline = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wingR.dx, wingR.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(wingL.dx, wingL.dy)
      ..close();

    // ---- هاله‌ی نورانیِ بیرونیِ لبه‌ی شیشه‌ای ----
    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.arrowGlow.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ---- بدنه‌ی اصلی: گرادیانِ نارنجیِ گلاسی ----
    canvas.drawPath(
      outline,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.arrowOrangeLight,
            AppColors.arrowOrange,
            AppColors.arrowOrangeDeep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(outline.getBounds()),
    );

    // ---- خطِ تیزِ میانی: وجهِ چپ روشن‌تر / وجهِ راست تیره‌تر (حسِ برجستگی) ----
    final leftFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(wingL.dx, wingL.dy)
      ..close();
    canvas.drawPath(leftFacet, Paint()..color = Colors.white.withOpacity(0.14));

    final rightFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(wingR.dx, wingR.dy)
      ..close();
    canvas.drawPath(
        rightFacet, Paint()..color = AppColors.arrowOrangeShadow.withOpacity(0.28));

    // ---- لبه‌ی شیشه‌ایِ داخلی (استروکِ روشن، ظریف) ----
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    // ---- هایلایتِ گلاسیِ بالا-چپ (انعکاسِ نور) ----
    final highlight = Path()
      ..moveTo(tip.dx - 3, tip.dy + 6)
      ..lineTo(tip.dx - 10, tip.dy + 20)
      ..lineTo(wingL.dx + 12, wingL.dy - 6)
      ..lineTo(wingL.dx + 5, wingL.dy - 12)
      ..close();
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NavArrowPainter old) =>
      old.headingDeg != headingDeg || old.glow != glow;
}
