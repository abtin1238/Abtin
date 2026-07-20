import 'package:flutter/material.dart';

/// پیکان ناوبری سه‌بعدی و براق — بازسازی‌شده بر اساس عکس مرجع طراحی.
///
/// شکل: یک مثلث با یک بریدگی (notch) در وسط قاعده که آن را به دو "بال"
/// تقسیم می‌کند — دقیقاً مثل پیکان نارنجی شیشه‌ای در عکس. برای حس سه‌بعدی:
/// - نیمه‌ی چپ روشن‌تر و نیمه‌ی راست عمیق‌تر رنگ می‌شود (نور از چپ‌بالا)
/// - یک خط تیره‌ی نازک روی محور مرکزی (crease) حس تا‌خوردگی می‌سازد
/// - یک قاب شیشه‌ای نیمه‌شفاف دور پیکان و یک هاله‌ی نرم پشت آن کشیده می‌شود
/// - یک نوار درخشان (specular highlight) روی بال چپ حس جلا/براقی می‌دهد
class NavArrowPainter extends CustomPainter {
  /// رنگ پایه‌ی پیکان. نیمه‌ی روشن و تیره از همین رنگ مشتق می‌شوند مگر این‌که
  /// [lightColor]/[darkColor] جداگانه داده شوند.
  final Color baseColor;
  final Color? lightColor;
  final Color? darkColor;
  final Color rimColor;
  final bool glow;

  const NavArrowPainter({
    this.baseColor = const Color(0xFFFF7A00),
    this.lightColor,
    this.darkColor,
    this.rimColor = const Color(0xFFFFE0B2),
    this.glow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final apex = Offset(w * 0.5, h * 0.05);
    final right = Offset(w * 0.92, h * 0.90);
    final notch = Offset(w * 0.5, h * 0.62);
    final left = Offset(w * 0.08, h * 0.90);

    final outer = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    final light = lightColor ?? Color.lerp(baseColor, Colors.white, 0.55)!;
    final mid = baseColor;
    final dark = darkColor ?? Color.lerp(baseColor, Colors.black, 0.35)!;

    // ۱) هاله‌ی نرم پشت پیکان (glow) — حس نور نئون شیشه‌ای عکس مرجع
    if (glow) {
      final glowPaint = Paint()
        ..color = mid.withOpacity(0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.14);
      canvas.drawPath(outer, glowPaint);
    }

    // ۲) نیمه‌ی چپ (روشن‌تر — رو به نور)
    final leftHalf = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(notch.dx, notch.dy)
      ..close();
    canvas.drawPath(
      leftHalf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [light, mid],
        ).createShader(outer.getBounds()),
    );

    // ۳) نیمه‌ی راست (تیره‌تر — سایه)
    final rightHalf = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(notch.dx, notch.dy)
      ..close();
    canvas.drawPath(
      rightHalf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mid, dark],
        ).createShader(outer.getBounds()),
    );

    // ۴) خط تا‌خوردگی مرکزی (حس سه‌بعدی/بدنه‌ی فلزی-شیشه‌ای)
    canvas.drawLine(
      apex,
      notch,
      Paint()
        ..strokeWidth = w * 0.022
        ..color = Colors.black.withOpacity(0.22)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      apex,
      notch,
      Paint()
        ..strokeWidth = w * 0.008
        ..color = Colors.white.withOpacity(0.5)
        ..strokeCap = StrokeCap.round,
    );

    // ۵) نوار درخشان (جلا) روی بال چپ
    final highlight = Path()
      ..moveTo(apex.dx - w * 0.02, apex.dy + h * 0.08)
      ..lineTo(left.dx + w * 0.14, notch.dy - h * 0.07)
      ..lineTo(left.dx + w * 0.24, notch.dy - h * 0.02)
      ..lineTo(apex.dx + w * 0.03, apex.dy + h * 0.16)
      ..close();
    canvas.drawPath(
      highlight,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.65), Colors.white.withOpacity(0.0)],
        ).createShader(highlight.getBounds()),
    );

    // ۶) قاب شیشه‌ای بیرونی (rim)
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = rimColor.withOpacity(0.55),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withOpacity(0.85),
    );
  }

  @override
  bool shouldRepaint(covariant NavArrowPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.rimColor != rimColor ||
        oldDelegate.glow != glow;
  }
}

/// ویجت آماده برای استفاده مستقیم — پیکان را در یک [CustomPaint] با اندازه‌ی
/// دلخواه رسم می‌کند.
class NavArrow extends StatelessWidget {
  final double size;
  final Color color;
  final bool glow;

  const NavArrow({
    super.key,
    this.size = 56,
    this.color = const Color(0xFFFF7A00),
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: NavArrowPainter(baseColor: color, glow: glow),
      ),
    );
  }
}
