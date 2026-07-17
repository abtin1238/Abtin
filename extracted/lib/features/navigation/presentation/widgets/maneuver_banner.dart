import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nav_state.dart';
import '../../domain/entities/route_info.dart';

/// نوار مانور بالای صفحه — بازسازی پیکسل‌به‌پیکسل از تصویر مرجع با
/// شیشه‌ی واقعی (Glassmorphism): بلور پس‌زمینه‌ی نقشه از پشت کارت،
/// گرادیان نیمه‌شفاف تیره، حاشیه‌ی روشنِ ظریف، و درخشش نرم لبه‌ها.
/// تمام مقادیر از [NavigationState] (خروجی موتور مسیریابی + GPS)
/// خوانده می‌شوند؛ هیچ متن ثابتی وجود ندارد.
class ManeuverBanner extends StatelessWidget {
  final NavigationState state;
  final VoidCallback? onClose;

  const ManeuverBanner({super.key, required this.state, this.onClose});

  IconData _iconFor(ManeuverType? t) {
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
        return Icons.rotate_right_rounded;
      case ManeuverType.arrive:
        return Icons.flag_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maneuver = state.nextManeuver;
    final instruction = maneuver?.instruction ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0E1524).withOpacity(0.72),
                const Color(0xFF0A0F1C).withOpacity(0.60),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.40), blurRadius: 26),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- ردیف اصلی: فاصله + دستور (راست) | آیکون سبز (چپ) ----
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          state.distanceToManeuverLabel,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: Colors.white,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instruction,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _maneuverIcon(_iconFor(maneuver?.type)),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.white.withOpacity(0.14), height: 16),
              // ---- ردیف اطلاعات پایین + دکمه‌ی بستن ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _inline('زمان باقی‌مانده', state.remainingTimeLabel),
                        _inline('مسافت مانده', state.remainingDistanceLabel),
                        _inline('زمان رسیدن', state.etaLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white.withOpacity(0.65), size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _maneuverIcon(IconData icon) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.success.withOpacity(0.14),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: AppColors.success.withOpacity(0.55),
              blurRadius: 18,
              spreadRadius: 1),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF35E06A), size: 42),
    );
  }

  Widget _inline(String label, String value) {
    return Flexible(
      child: RichText(
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(fontSize: 12, fontFamily: 'Vazirmatn'),
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(color: Colors.white.withOpacity(0.55))),
            TextSpan(
                text: value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
