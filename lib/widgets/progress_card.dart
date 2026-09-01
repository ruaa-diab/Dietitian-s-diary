import 'package:flutter/material.dart';

import '../data/practice_profile.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import 'line_icon.dart';

/// Screen 09 — the shareable progress card.
///
/// A standalone widget rather than a screen: it is laid out at a fixed
/// [width] so it can be handed to `RepaintBoundary.toImage()` and exported
/// as a picture for the client to post.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.client,
    required this.package,
    required this.packageNumber,
    required this.days,
    required this.attendedVisits,
    this.width = 412,
    this.shadow = true,
  });

  final Client client;
  final ClientPackage package;

  /// 1-based position of this package in the client's history — "الباقة
  /// الأولى", "الثانية", and so on.
  final int packageNumber;
  final int days;
  final int attendedVisits;
  final double width;
  final bool shadow;

  static const _ordinals = [
    'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة',
    'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة',
  ];

  String get _packageLabel => packageNumber >= 1 && packageNumber <= _ordinals.length
      ? 'الباقة ${_ordinals[packageNumber - 1]}'
      : 'الباقة رقم ${fmtInt(packageNumber)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.shareCardBg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: shadow
            ? const [
                BoxShadow(color: Color(0x24362B2C), blurRadius: 50, offset: Offset(0, 20)),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(packageLabel: _packageLabel),
          const SizedBox(height: 26),
          Text('تقدّم', style: AppText.bodyLarge.copyWith(height: 1.2)),
          const SizedBox(height: 4),
          Text(
            client.name,
            style: AppText.shareName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    value: fmtInt(attendedVisits),
                    label: 'زيارات',
                    color: AppColors.sage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: fmtInt(package.visitCount),
                    label: 'الباقة',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(value: fmtInt(days), label: 'يوماً')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _closingLine(),
            textAlign: TextAlign.center,
            style: AppText.rowTitleSmall.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  String _closingLine() {
    final visits = ArabicDates.visits(attendedVisits);
    return '$visits في ${ArabicDates.days(days)}. استمري';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.packageLabel});

  final String packageLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.clay,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const BrandLeaf(size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(PracticeProfile.brandName, style: AppText.brandMark),
              const SizedBox(height: 2),
              Text(
                PracticeProfile.byline,
                style: AppText.metaTiny.copyWith(color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.sageBgAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            packageLabel,
            style: AppText.pillSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.sageText,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.statNumber.copyWith(color: color)),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.metaTiny.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

