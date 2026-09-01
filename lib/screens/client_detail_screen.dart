import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/weight_chart.dart';
import 'new_package_screen.dart';
import 'progress_card_screen.dart';
import 'record_payment_sheet.dart';

/// Screen 03 — the client file.
class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(clientId);
    if (client == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _TopBar(client: client),
            const SizedBox(height: 8),
            _Identity(client: client),
            const SizedBox(height: 22),
            _SummaryChips(client: client),
            const SizedBox(height: 18),
            if (store.balanceDueFor(client.id) > 0) ...[
              _BalanceCard(client: client),
              const SizedBox(height: 14),
            ],
            _WeightCard(client: client),
            const SizedBox(height: 14),
            _PackageHistoryCard(client: client),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconAction(
            icon: AppIcons.chevron,
            tooltip: 'رجوع',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          _OverflowMenu(client: client),
        ],
      ),
    );
  }
}

enum _ClientAction { logWeight, newPackage, shareProgress }

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ClientAction>(
      tooltip: 'خيارات',
      color: AppColors.card,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: LineIcon(AppIcons.more, color: AppColors.textPrimary, size: 26),
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ClientAction.logWeight,
          child: Text('تسجيل وزن', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.newPackage,
          child: Text('باقة جديدة', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.shareProgress,
          child: Text('مشاركة تقدّمها', style: AppText.rowTitleSmall),
        ),
      ],
    );
  }

  void _run(BuildContext context, _ClientAction action) {
    switch (action) {
      case _ClientAction.logWeight:
        _LogWeightSheet.show(context, client);
      case _ClientAction.newPackage:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => NewPackageScreen(clientId: client.id),
        ));
      case _ClientAction.shareProgress:
        Navigator.of(context).push(ProgressCardScreen.route(clientId: client.id));
    }
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClientAvatar(
          name: client.name,
          seed: client.id,
          size: 76,
          radius: 26,
          textStyle: AppText.avatarInitialLarge,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: AppText.pageHeadline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${fmtPhone(client.phone)}'
                '${client.age > 0 ? ' · ${fmtInt(client.age)} سنة' : ''}',
                style: AppText.rowTitleSmall.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final active = store.activePackage(client.id);
    final latest = store.latestPackage(client.id);

    String? progressLabel;
    if (active != null) {
      final next = store
          .visitsForPackage(active.id)
          .where((v) => !v.isResolved)
          .firstOrNull;
      progressLabel = next == null
          ? 'اكتملت الباقة'
          : 'الزيارة ${fmtInt(next.index)} من ${fmtInt(active.visitCount)}';
    } else if (latest != null) {
      progressLabel = 'تحتاج تجديد';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (client.goalKg != null)
          StatusPill.success(
            'الهدف ${fmtSigned(client.goalKg!)} كجم',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        StatusPill(
          label: 'بدأت ${ArabicDates.dayMonth(latest?.startDate ?? client.startDate)}',
          background: AppColors.card,
          foreground: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: AppText.pillMuted,
        ),
        if (progressLabel != null)
          StatusPill.due(
            progressLabel,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final due = store.balanceDueFor(client.id);
    final unpaid = store
        .packagesFor(client.id)
        .where((p) => !p.isPaid)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رصيد مستحق', style: AppText.meta),
                  const SizedBox(height: 4),
                  Text(fmtCurrency(due), style: AppText.amountLarge),
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
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'تسجيل دفعة',
            height: 54,
            radius: 16,
            textStyle: AppText.buttonMedium.copyWith(color: AppColors.card),
            onPressed: unpaid.isEmpty
                ? null
                : () => RecordPaymentSheet.show(context, packageId: unpaid.first.id),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final logs = store.weightsFor(client.id);
    final current = store.currentWeight(client.id);
    final start = store.startWeight(client.id);
    final delta = store.weightDelta(client.id);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الوزن', style: AppText.sectionTitle),
              if (delta != null) _DeltaPill(delta: delta),
            ],
          ),
          const SizedBox(height: 6),
          if (current == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('لم تُسجَّل قياسات بعد.', style: AppText.metaSmall),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(fmtDecimal(current), style: AppText.bigWeight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    start == null
                        ? 'كجم اليوم'
                        : 'كجم اليوم · من ${fmtDecimal(start)}',
                    style: AppText.rowTitleSmall.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeightChart(logs: logs),
          ],
        ],
      ),
    );
  }
}

/// The sage delta badge; the arrow flips when weight goes up.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final lost = delta <= 0;
    return StatusPill(
      label: '${fmtSigned(delta)} كجم',
      background: lost ? AppColors.sageBg : AppColors.dueBg,
      foreground: lost ? AppColors.sageText : AppColors.clayDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      textStyle: AppText.pill.copyWith(fontWeight: FontWeight.w700),
      leading: Transform.rotate(
        angle: lost ? 3.14159 : 0,
        child: LineIcon(
          AppIcons.arrowUp,
          color: lost ? AppColors.sageText : AppColors.clayDark,
          size: 14,
        ),
      ),
    );
  }
}

class _PackageHistoryCard extends StatelessWidget {
  const _PackageHistoryCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final history = store.packagesFor(client.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('سجل الباقات', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          if (history.isEmpty)
            Text('لا توجد باقات بعد.', style: AppText.metaSmall)
          else
            for (final pkg in history) ...[
              _PackageRow(
                package: pkg,
                // Numbered oldest-first, so the first package sold is ١.
                index: history.length - history.indexOf(pkg),
              ),
              if (pkg != history.last) const RowDivider(),
            ],
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package, required this.index});

  final ClientPackage package;
  final int index;

  @override
  Widget build(BuildContext context) {
    final active = package.isActive;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.sageBgAlt : AppColors.divider,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            fmtInt(index),
            style: AppText.packageIndex.copyWith(
              color: active ? AppColors.sageText : AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ArabicDates.visits(package.visitCount)} · ${fmtCurrency(package.price)}',
                style: AppText.rowTitleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                ArabicDates.range(package.startDate, package.endDate),
                style: AppText.metaSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        package.isPaid
            ? StatusPill.success(
                'مدفوعة',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: AppText.pillSmall,
              )
            : StatusPill.due(
                'غير مدفوعة',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: AppText.pillSmall,
              ),
      ],
    );
  }
}

/// Records a new weight reading for a client.
class _LogWeightSheet extends StatefulWidget {
  const _LogWeightSheet({required this.client});

  final Client client;

  static Future<void> show(BuildContext context, Client client) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _LogWeightSheet(client: client),
      );

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  final _weight = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(_weight.text.trim());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تسجيل وزن — ${widget.client.name}', style: AppText.navTitle),
              const SizedBox(height: 20),
              AppTextField(
                controller: _weight,
                hint: 'الوزن بالكيلوغرام',
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                suffix: Text('كجم', style: AppText.metaSmall),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'حفظ',
                onPressed: value == null || value <= 0
                    ? null
                    : () {
                        StoreScope.read(context)
                            .logWeight(clientId: widget.client.id, weightKg: value);
                        Navigator.of(context).pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
