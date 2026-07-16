import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../navigation/data/navigation_controller.dart';
import '../../../navigation/domain/entities/nav_state.dart';
import '../../../navigation/domain/entities/route_info.dart';

/// نمای AR ناوبری: همپوشانی مسیر/فلش روی فید دوربین.
///
/// بدون پلاگین دوربین سخت‌افزاری، پس‌زمینه شبیه‌سازی می‌شود تا
/// UX و منطق فلش/مانور کامل قابل تست باشد. روی دستگاه واقعی می‌توان
/// `camera` plugin را پشت همین API قرار داد.
class ArNavigationScreen extends ConsumerWidget {
  const ArNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _CameraBackdrop(),
          CustomPaint(
            painter: _ArHudPainter(nav),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'حالت AR',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (nav.isNavigating && nav.nextManeuver != null)
                    AppCard(
                      child: Row(
                        children: [
                          Icon(_iconFor(nav.nextManeuver!.type),
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nav.nextManeuver!.instruction,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16),
                                ),
                                Text(
                                  '${toFa(nav.distanceToManeuverMeters.round())} متر',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${toFa(nav.currentSpeedKmh.round())}\nkm/h',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      child: Text(
                        'برای شروع AR، ابتدا یک مسیر را از نقشه آغاز کنید.',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ManeuverType t) {
    switch (t) {
      case ManeuverType.turnRight:
      case ManeuverType.slightRight:
        return Icons.turn_right_rounded;
      case ManeuverType.turnLeft:
      case ManeuverType.slightLeft:
        return Icons.turn_left_rounded;
      case ManeuverType.uTurn:
        return Icons.u_turn_left_rounded;
      case ManeuverType.roundabout:
        return Icons.roundabout_right_rounded;
      case ManeuverType.arrive:
        return Icons.flag_rounded;
      default:
        return Icons.straight_rounded;
    }
  }
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B2735),
            const Color(0xFF090A0F),
            AppColors.primary.withOpacity(0.15),
          ],
        ),
      ),
      child: CustomPaint(painter: _RoadPerspectivePainter()),
    );
  }
}

class _RoadPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Path()
      ..moveTo(size.width * 0.2, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.45)
      ..lineTo(size.width * 0.55, size.height * 0.45)
      ..lineTo(size.width * 0.8, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = const Color(0xFF2A2F3A).withOpacity(0.85),
    );
    final dash = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 3;
    for (var i = 0; i < 8; i++) {
      final t0 = i / 8;
      final t1 = (i + 0.4) / 8;
      final y0 = size.height - (size.height * 0.55) * t0;
      final y1 = size.height - (size.height * 0.55) * t1;
      canvas.drawLine(
        Offset(size.width / 2, y0),
        Offset(size.width / 2, y1),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArHudPainter extends CustomPainter {
  final NavigationState nav;
  _ArHudPainter(this.nav);

  @override
  void paint(Canvas canvas, Size size) {
    if (!nav.isNavigating) return;
    final cx = size.width / 2;
    final cy = size.height * 0.58;
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(cx, cy + 80);
    final bend = switch (nav.nextManeuver?.type) {
      ManeuverType.turnRight || ManeuverType.slightRight => 70.0,
      ManeuverType.turnLeft || ManeuverType.slightLeft => -70.0,
      _ => 0.0,
    };
    path.quadraticBezierTo(cx + bend, cy, cx + bend * 0.2, cy - 90);
    canvas.drawPath(path, paint);

    // فلش نوک
    final tip = Offset(cx + bend * 0.2, cy - 90);
    final ang = math.atan2(-90, bend * 0.2);
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 14 * math.cos(ang - 0.5), tip.dy - 14 * math.sin(ang - 0.5))
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 14 * math.cos(ang + 0.5), tip.dy - 14 * math.sin(ang + 0.5));
    canvas.drawPath(arrow, paint);

    // نقاط مسیر AR
    final dot = Paint()..color = AppColors.gold.withOpacity(0.9);
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final x = cx + bend * t * t;
      final y = cy + 80 - 170 * t;
      canvas.drawCircle(Offset(x, y), 4 + i.toDouble(), dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ArHudPainter oldDelegate) =>
      oldDelegate.nav != nav;
}
