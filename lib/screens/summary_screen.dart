import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/revenue_bars.dart';
import 'client_detail_screen.dart';
import 'record_payment_sheet.dart';

/// Screen 05 — the month at a glance.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final renewals = store.needsRenewal;
    final outstanding = store.outstandingClients;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Text('الملخص', style: AppText.screenTitle),
        const SizedBox(height: 4),
        Text(ArabicDates.monthYear(DateTime.now()), style: AppText.rowTitleSmall.copyWith(
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        )),
        const SizedBox(height: 20),
        const _RevenueHero(),
        const SizedBox(height: 14),
        _StatTiles(
          outstanding: store.totalOutstanding,
          renewalCount: renewals.length,
        ),
        const SizedBox(height: 14),
        if (renewals.isNotEmpty) ...[
          _RenewalsCard(renewals: renewals),
          const SizedBox(height: 14),
        ],
        if (outstanding.isNotEmpty) _BalancesCard(clients: outstanding),
      ],
    );
  }
}

class _RevenueHero extends StatelessWidget {
  const _RevenueHero();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final revenue = store.revenueForMonth(DateTime.now());
    final change = store.revenueChangePercent;
    final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إيرادات هذا الشهر',
            style: AppText.rowTitleSmall.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.card.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fmtPrice(revenue), style: AppText.heroAmount),
              const SizedBox(width: 8),
              Text(
                AppNumerals.shekel,
                style: AppText.pageHeadline.copyWith(
                  fontSize: 22,
                  color: AppColors.card.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (change != null)
            Row(
              children: [
                Transform.rotate(
                  angle: change < 0 ? 3.14159 : 0,
                  child: LineIcon(AppIcons.arrowUp, color: AppColors.clayPale, size: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  '${fmtSignedPercent(change.round())} عن ${ArabicDates.monthName(lastMonth.month)}',
                  style: AppText.meta.copyWith(color: AppColors.clayPale),
                ),
              ],
            ),
          const SizedBox(height: 20),
          RevenueBars(months: store.revenueTrend),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.outstanding, required this.renewalCount});

  final double outstanding;
  final int renewalCount;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so both tiles match the taller of the two, which an
    // unbounded stretch inside a ListView cannot do on its own.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: AppIcons.card,
              iconColor: AppColors.clay,
              iconBackground: AppColors.dueBg,
              value: fmtCurrency(outstanding),
              label: 'رصيد غير مدفوع',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: AppIcons.refresh,
              iconColor: AppColors.sage,
              iconBackground: AppColors.sageBgAlt,
              value: fmtInt(renewalCount),
              label: 'تحتاج تجديد',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
  });

  final LineIconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: iconColor, background: iconBackground),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.amountMedium),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.metaSmall),
        ],
      ),
    );
  }
}

class _RenewalsCard extends StatelessWidget {
  const _RenewalsCard({required this.renewals});

  final List<Client> renewals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('تحتاج تجديد', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          for (final client in renewals) ...[
            _RenewalRow(client: client),
            if (client != renewals.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget {
  const _RenewalRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final due = store.balanceDueFor(client.id);
    final lastVisit = store
        .visitsForClient(client.id)
        .where((v) => v.status == VisitStatus.attended)
        .firstOrNull
        ?.scheduledAt;
    final daysSince =
        lastVisit == null ? null : ArabicDates.daysBetween(lastVisit, DateTime.now());

    final subtitle = due > 0
        ? 'أكملت باقتها · ${fmtCurrency(due)} مستحقة'
        : switch (daysSince) {
            null => 'أكملت باقتها',
            0 => 'أكملت باقتها اليوم',
            final int days => 'آخر زيارة منذ ${ArabicDates.days(days)}',
          };

    return Row(
      children: [
        ClientAvatar(
          name: client.name,
          seed: client.id,
          size: 44,
          radius: 14,
          muted: daysSince != null && daysSince > 0,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClientDetailScreen(clientId: client.id),
              ),
            ),
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
                Text(subtitle, style: AppText.metaSmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () => RecordPaymentSheet.show(context, clientId: client.id),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('دفعة', style: AppText.buttonSmall),
          ),
        ),
      ],
    );
  }
}

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.clients});

  final List<Client> clients;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أرصدة مستحقة', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          for (final client in clients) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => RecordPaymentSheet.show(context, clientId: client.id),
              child: Row(
                children: [
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
                          '${ArabicDates.visits(store.attendedCount(client.id))}'
                          ' · ${ArabicDates.packages(store.packagesOwedBy(client.id))} مستحقة',
                          style: AppText.metaSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(fmtCurrency(store.balanceDueFor(client.id)), style: AppText.amountSmall),
                ],
              ),
            ),
            if (client != clients.last) const RowDivider(),
          ],
        ],
      ),
    );
  }
}
