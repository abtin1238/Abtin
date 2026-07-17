import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// نمایش گرافیکی Lane Guidance / خروجی بزرگراه.
class LaneGuidanceBar extends StatelessWidget {
  /// تعداد خطوط؛ -1 یعنی خط پیشنهادی.
  final List<int> lanes;
  final String? exitLabel;

  const LaneGuidanceBar({
    super.key,
    required this.lanes,
    this.exitLabel,
  });

  /// نمونه پیش‌فرض برای مانور راست.
  factory LaneGuidanceBar.suggestRight({int total = 3}) {
    final lanes = List<int>.generate(total, (i) => i == total - 1 ? 1 : 0);
    return LaneGuidanceBar(lanes: lanes, exitLabel: 'خروجی');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (exitLabel != null) ...[
            Text(
              exitLabel!,
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 10),
          ],
          ...lanes.map((active) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 22,
                color: active == 1
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.28),
              ),
            );
          }),
        ],
      ),
    );
  }
}
