import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';

/// The six-month mini bar chart inside the revenue hero card.
///
/// Sits in an RTL row, so the oldest month is on the right and the
/// current month — highlighted in honey — on the left, matching the design.
class RevenueBars extends StatelessWidget {
  const RevenueBars({
    super.key,
    required this.months,
    this.barHeight = 44,
  });

  /// Oldest first.
  final List<({DateTime month, double revenue})> months;

  /// Height of the tallest bar. The chart itself is as tall as that plus
  /// its labels, so a larger text scale grows it rather than clipping it.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return SizedBox(height: barHeight);

    final peak = months.map((m) => m.revenue).reduce((a, b) => a > b ? a : b);
    final currentIndex = months.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < months.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: _Bar(
              label: ArabicDates.monthName(months[i].month.month),
              // A month with no revenue still shows a stub so the axis
              // stays readable.
              fraction: peak <= 0 ? 0 : months[i].revenue / peak,
              barHeight: barHeight,
              isCurrent: i == currentIndex,
            ),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.fraction,
    required this.barHeight,
    required this.isCurrent,
  });

  final String label;
  final double fraction;
  final double barHeight;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: (barHeight * fraction).clamp(4.0, barHeight),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.honey : AppColors.card.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
            color: AppColors.card.withValues(alpha: isCurrent ? 1 : 0.75),
          ),
        ),
      ],
    );
  }
}
