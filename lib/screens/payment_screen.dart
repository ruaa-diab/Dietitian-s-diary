import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'appointment_sheet.dart';
import 'record_payment_sheet.dart';

/// الدفعات — who owes what, and the way to take money in.
///
/// This replaced a "sell a package" screen. Nothing is sold in advance
/// any more: the client comes, and pays for the package her visits are
/// using. So the useful screen is not a form for creating a package, it
/// is the list of people whose visits have run past what they have paid.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, this.clientId});

  /// Opens straight onto one client's payment sheet — from her file, or
  /// from the celebration when she finishes her four.
  final String? clientId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final owing = store.outstandingClients;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (canPop)
              SizedBox(
                height: 52,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconAction(
                    icon: AppIcons.chevron,
                    tooltip: 'رجوع',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            Text('الدفعات', style: AppText.screenTitle),
            const SizedBox(height: 6),
            Text(
              'الباقة ${ArabicDates.visits(AppStore.packageRate.visitCount)}'
              ' بـ ${fmtCurrency(AppStore.packageRate.price)}.'
              ' كل أربع زيارات تحضرها العميلة تُحتسب باقة.',
              style: AppText.bodyLarge,
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي المستحق', style: AppText.meta),
                      const SizedBox(height: 4),
                      Text(fmtCurrency(store.totalOutstanding), style: AppText.amountLarge),
                    ],
                  ),
                  IconTile(
                    icon: AppIcons.card,
                    color: AppColors.clay,
                    background: AppColors.dueBg,
                    size: 52,
                    radius: 18,
                    iconSize: 26,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('عليهنّ مستحقات', style: AppText.sectionTitle),
            const SizedBox(height: 12),
            AppCard(
              child: owing.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('لا مستحقات على أحد. كل الحسابات مسدّدة.',
                          style: AppText.bodyLarge),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final client in owing) ...[
                          _OwingRow(client: client),
                          if (client != owing.last) const RowDivider(),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            SecondaryButton(
              label: 'تسجيل دفعة لعميلة أخرى',
              onPressed: () => _pickAndPay(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndPay(BuildContext context) async {
    final chosen = await ClientPickerSheet.show(context);
    if (chosen == null || !context.mounted) return;
    await RecordPaymentSheet.show(context, clientId: chosen);
  }
}

class _OwingRow extends StatelessWidget {
  const _OwingRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final due = store.balanceDueFor(client.id);
    final packages = store.packagesOwedBy(client.id);

    return InkWell(
      onTap: () => RecordPaymentSheet.show(context, clientId: client.id),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClientAvatar(name: client.name, seed: client.id, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: AppText.rowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    packages > 1
                        ? '${ArabicDates.visits(store.attendedCount(client.id))}'
                            ' · متأخرة بـ${ArabicDates.packages(packages)}'
                        : ArabicDates.visits(store.attendedCount(client.id)),
                    style: AppText.metaSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtCurrency(due), style: AppText.amountSmall),
          ],
        ),
      ),
    );
  }
}
