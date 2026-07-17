import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// قطب‌نمای دایره‌ای مطابق تصویر مرجع (حروف N/E/S/W + عقربه‌ی قرمز/سفید).
/// با تغییر جهت حرکت (heading) عقربه می‌چرخد.
class NavCompass extends StatelessWidget {
  final double headingDeg;
  final double size;
  const NavCompass({super.key, required this.headingDeg, this.size = 70});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF1B2436), Color(0xFF0C1220)],
          ),
          border: Border.all(color: AppColors.borderDark, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12),
          ],
        ),
        child: CustomPaint(
          painter: _CompassPainter(headingDeg: headingDeg),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double headingDeg;
  _CompassPainter({required this.headingDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final angle = -headingDeg * math.pi / 180.0;

    // حروف جهت
    const labels = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    labels.forEach((deg, label) {
      final a = angle + deg * math.pi / 180.0 - math.pi / 2;
      final pos = Offset(
        center.dx + (r - 11) * math.cos(a),
        center.dy + (r - 11) * math.sin(a),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: label == 'N' ? AppColors.danger : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // عقربه: نیمه‌ی قرمز (شمال) و نیمه‌ی سفید (جنوب)
    final north = angle - math.pi / 2;
    final tip = Offset(
        center.dx + (r - 22) * math.cos(north),
        center.dy + (r - 22) * math.sin(north));
    final tail = Offset(
        center.dx - (r - 22) * math.cos(north),
        center.dy - (r - 22) * math.sin(north));
    final perp = north + math.pi / 2;
    final base1 = Offset(
        center.dx + 5 * math.cos(perp), center.dy + 5 * math.sin(perp));
    final base2 = Offset(
        center.dx - 5 * math.cos(perp), center.dy - 5 * math.sin(perp));

    final redNeedle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base1.dx, base1.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();
    canvas.drawPath(redNeedle, Paint()..color = AppColors.danger);

    final whiteNeedle = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(base1.dx, base1.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();
    canvas.drawPath(whiteNeedle, Paint()..color = Colors.white70);

    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.headingDeg != headingDeg;
}
