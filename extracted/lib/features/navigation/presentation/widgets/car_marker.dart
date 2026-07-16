import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// نشانگر خودرو روی نقشه: یک **پیکان سه‌بعدیِ واقعی** (نه یک آیکونِ تخت).
///
/// مدل با یک موتور پروجکشنِ پرسپکتیوِ واقعی (نقاطِ ۳بعدیِ x/y/z → صفحه‌ی
/// دو‌بعدی) ساخته شده است؛ یعنی بدنه، شیشه‌ها، سقف و چراغ‌ها همگی از رأس‌های
/// واقعیِ سه‌بعدی رندر می‌شوند و با چرخشِ جهت‌حرکت (heading) واقعاً در فضای
/// سه‌بعدی می‌چرخند (نه فقط چرخشِ یک تصویرِ دوبعدی). بدون هیچ فایلِ خارجیِ
/// مدل بسته‌شده: `assets/models/car.glb`.
/// GLB/OBJ کار می‌کند، پس همیشه و روی هر دستگاهی رندر می‌شود.
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
        size: const Size(96, 96),
        painter: _Peykan3DPainter(
          headingDeg: headingDeg,
          headlights: headlights,
        ),
      ),
    );
  }
}

/// یک رأسِ سه‌بعدی ساده (x: راست، y: بالا، z: جلو/عمق).
class _V3 {
  final double x, y, z;
  const _V3(this.x, this.y, this.z);
}

/// یک وجهِ رنگی از چند رأس (به‌ترتیب برای رسمِ چندضلعیِ محدب).
class _Face {
  final List<int> verts;
  final Color color;
  const _Face(this.verts, this.color);
}

class _Peykan3DPainter extends CustomPainter {
  final double headingDeg;
  final bool headlights;
  _Peykan3DPainter({required this.headingDeg, required this.headlights});

  // ---- هندسه‌ی خودرو در فضای محلیِ سه‌بعدی (واحد: نسبی) ----
  // محورِ z رو به جلو (جهتِ حرکت)، x به راست، y به بالا.
  static const double _len = 46; // طول بدنه
  static const double _hw = 15; // نصفِ عرض
  static const double _hBody = 9; // ارتفاعِ بدنه از خطِ کمر
  static const double _hCabin = 15; // ارتفاعِ سقف از خطِ کمر
  static const double _floor = -4; // کف نسبت به مرکز

  static const List<_V3> _base = [
    // 0..3 کف (مستطیل پایه)
    _V3(-_hw, _floor, _len), // 0 جلو-چپ-پایین
    _V3(_hw, _floor, _len), // 1 جلو-راست-پایین
    _V3(_hw, _floor, -_len), // 2 عقب-راست-پایین
    _V3(-_hw, _floor, -_len), // 3 عقب-چپ-پایین
    // 4..7 خطِ کمر (بدنه)
    _V3(-_hw, _floor + _hBody, _len * 0.92), // 4 جلو-چپ
    _V3(_hw, _floor + _hBody, _len * 0.92), // 5 جلو-راست
    _V3(_hw, _floor + _hBody, -_len), // 6 عقب-راست
    _V3(-_hw, _floor + _hBody, -_len), // 7 عقب-چپ
    // 8..11 پایه‌ی کابین (شیشه‌ها از اینجا شروع می‌شوند)
    _V3(-_hw * 0.86, _floor + _hBody, _len * 0.28), // 8
    _V3(_hw * 0.86, _floor + _hBody, _len * 0.28), // 9
    _V3(_hw * 0.86, _floor + _hBody, -_len * 0.62), // 10
    _V3(-_hw * 0.86, _floor + _hBody, -_len * 0.62), // 11
    // 12..15 سقف
    _V3(-_hw * 0.68, _floor + _hCabin, _len * 0.06), // 12
    _V3(_hw * 0.68, _floor + _hCabin, _len * 0.06), // 13
    _V3(_hw * 0.68, _floor + _hCabin, -_len * 0.5), // 14
    _V3(-_hw * 0.68, _floor + _hCabin, -_len * 0.5), // 15
    // 16..17 نوکِ کاپوت (جلو، پایین‌تر و باریک‌تر — مشخصه‌ی پیکان)
    _V3(-_hw * 0.7, _floor + _hBody * 0.55, _len * 1.06), // 16
    _V3(_hw * 0.7, _floor + _hBody * 0.55, _len * 1.06), // 17
  ];

  static const List<_Face> _faces = [
    // کفِ زیرِ ماشین (سایه)
    _Face([0, 1, 2, 3], Color(0xFF05070C)),
    // پوسته‌ی جلو (سپر/کاپوت)
    _Face([0, 1, 5, 4], Color(0xFFD7DEE8)),
    _Face([1, 17, 16, 0], Color(0xFFC7D0DC)), // نوکِ کاپوت
    // خطِ کمرِ بالایی
    _Face([4, 5, 6, 7], Color(0xFFBFC8D6)),
    // بدنه‌ی چپ/راست
    _Face([0, 4, 7, 3], Color(0xFFAAB4C4)),
    _Face([1, 2, 6, 5], Color(0xFFAAB4C4)),
    // عقب (صندوق)
    _Face([2, 3, 7, 6], Color(0xFFB6BFCE)),
    // شیشه‌ی جلو
    _Face([8, 9, 13, 12], Color(0xFF1E2634)),
    // شیشه‌های کناری
    _Face([8, 12, 15, 11], Color(0xFF232C3D)),
    _Face([9, 10, 14, 13], Color(0xFF232C3D)),
    // شیشه‌ی عقب
    _Face([10, 11, 15, 14], Color(0xFF1E2634)),
    // سقف
    _Face([12, 13, 14, 15], Color(0xFFE4E9F0)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // چرخشِ واقعیِ سه‌بعدی حولِ محورِ y بر اساسِ جهتِ حرکت.
    final yaw = headingDeg * math.pi / 180.0;
    final cy = math.cos(yaw), sy = math.sin(yaw);

    // خمِ دیدِ ایزومتریک/پرسپکتیو: کمی از بالا به پایین نگاه می‌کنیم.
    const pitch = 0.62; // رادیان (~۳۵ درجه)
    final cp = math.cos(pitch), sp = math.sin(pitch);

    const scale = 1.0;
    const focal = 520.0; // فاصله‌ی کانونی (پرسپکتیو)
    const camZ = 260.0; // فاصله‌ی دوربین از مبدا

    Offset project(_V3 v) {
      // ۱) چرخش حولِ y (جهتِ حرکت)
      final rx = v.x * cy + v.z * sy;
      final rz = -v.x * sy + v.z * cy;
      final ry = v.y;

      // ۲) خمِ دید حولِ x (نگاهِ از بالا)
      final ry2 = ry * cp - rz * sp;
      final rz2 = ry * sp + rz * cp;

      // ۳) پروجکشنِ پرسپکتیو
      final denom = camZ - rz2;
      final f = focal / (denom == 0 ? 0.001 : denom);
      return Offset(center.dx + rx * f * scale, center.dy - ry2 * f * scale);
    }

    final projected = _base.map(project).toList();

    // عمقِ هر وجه برای مرتب‌سازیِ نقاشیِ دورترین → نزدیک‌ترین (painter's algorithm).
    double depthOf(_Face face) {
      var sum = 0.0;
      for (final i in face.verts) {
        final v = _base[i];
        final rz = -v.x * sy + v.z * cy;
        final rz2 = v.y * sp + rz * cp;
        sum += rz2;
      }
      return sum / face.verts.length;
    }

    final ordered = List<_Face>.from(_faces)
      ..sort((a, b) => depthOf(a).compareTo(depthOf(b)));

    // ---- هاله‌ی نرم زیرِ خودرو (تماسِ بصری با نقشه) ----
    canvas.drawOval(
      Rect.fromCenter(
          center: center + const Offset(0, 30), width: 58, height: 20),
      Paint()
        ..color = Colors.black.withOpacity(0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ---- مخروطِ نورِ چراغ‌جلو ----
    if (headlights) {
      final tip = project(const _V3(0, _floor + 2, _len * 1.05));
      final l = project(const _V3(-34, _floor + 2, _len * 2.4));
      final r = project(const _V3(34, _floor + 2, _len * 2.4));
      final cone = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(l.dx, l.dy)
        ..lineTo(r.dx, r.dy)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x00FFF3C0),
              AppColors.goldSoft.withOpacity(0.35),
            ],
          ).createShader(Rect.fromPoints(tip, Offset(r.dx, r.dy))),
      );
    }

    // ---- رسمِ وجه‌های سه‌بعدی به ترتیبِ عمق ----
    for (final face in ordered) {
      final path = Path()
        ..moveTo(projected[face.verts[0]].dx, projected[face.verts[0]].dy);
      for (var i = 1; i < face.verts.length; i++) {
        path.lineTo(projected[face.verts[i]].dx, projected[face.verts[i]].dy);
      }
      path.close();

      // سایه‌روشنِ ساده بر اساسِ موقعیتِ x وجه (سمتِ دورتر کمی تیره‌تر).
      final avgX =
          face.verts.map((i) => _base[i].x).reduce((a, b) => a + b) /
              face.verts.length;
      final shade = (avgX / _hw).clamp(-1.0, 1.0) * 0.06;
      final c = _shiftLightness(face.color, -shade);

      canvas.drawPath(path, Paint()..color = c);
    }

    // ---- هاله‌ی برندِ فیروزه‌ای دورِ بدنه ----
    final beltA = projected[4], beltB = projected[5];
    final beltC = projected[6], beltD = projected[7];
    canvas.drawLine(
      beltA,
      beltB,
      Paint()
        ..color = AppColors.primary.withOpacity(0.55)
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      beltB,
      beltC,
      Paint()
        ..color = AppColors.primary.withOpacity(0.4)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      beltD,
      beltA,
      Paint()
        ..color = AppColors.primary.withOpacity(0.4)
        ..strokeWidth = 1.2,
    );

    // ---- چراغ‌های عقب (قرمز) ----
    final tailL = project(const _V3(-_hw * 0.85, _floor + 5, -_len * 0.98));
    final tailR = project(const _V3(_hw * 0.85, _floor + 5, -_len * 0.98));
    final tailPaint = Paint()..color = AppColors.danger;
    canvas.drawCircle(tailL, 2.6, tailPaint);
    canvas.drawCircle(tailR, 2.6, tailPaint);
  }

  Color _shiftLightness(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  @override
  bool shouldRepaint(_Peykan3DPainter old) =>
      old.headingDeg != headingDeg || old.headlights != headlights;
}
