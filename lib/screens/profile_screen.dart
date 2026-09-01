import 'package:flutter/material.dart';

import '../data/practice_profile.dart';
import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

/// حسابي — the dietitian's own page: who she is, and how the practice is
/// doing at a glance.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final activePackages =
        store.packages.where((p) => p.isActive).length;
    final visitsThisMonth = store.visits.where((v) {
      final now = DateTime.now();
      return v.scheduledAt.year == now.year && v.scheduledAt.month == now.month;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Text('حسابي', style: AppText.screenTitle),
        const SizedBox(height: 20),
        const _IdentityCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: fmtInt(store.clients.length),
                label: 'عميلة',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                value: fmtInt(activePackages),
                label: 'باقة جارية',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                value: fmtInt(visitsThisMonth),
                label: 'زيارة هذا الشهر',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('هذا الشهر', style: AppText.sectionTitle),
              const SizedBox(height: 14),
              _MoneyRow(
                label: 'الإيرادات',
                amount: fmtCurrency(store.revenueForMonth(DateTime.now())),
              ),
              const RowDivider(),
              _MoneyRow(
                label: 'رصيد مستحق',
                amount: fmtCurrency(store.totalOutstanding),
                emphasis: true,
              ),
              const RowDivider(),
              _MoneyRow(
                label: 'تحتاج تجديد',
                amount: fmtInt(store.needsRenewal.length),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الباقات', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(
                'تُباع الباقة من ملف العميلة، أو من زر «تجديد» في الملخص.',
                style: AppText.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const BrandLeaf(size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PracticeProfile.dietitianName,
                  style: AppText.pageHeadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(PracticeProfile.title, style: AppText.meta),
                const SizedBox(height: 8),
                StatusPill.success(
                  PracticeProfile.brandName,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: AppText.pillSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.amountMedium),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.metaSmall, maxLines: 2),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.emphasis = false,
  });

  final String label;
  final String amount;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.rowTitle),
        Text(
          amount,
          style: emphasis
              ? AppText.amountSmall
              : AppText.amountSmall.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
