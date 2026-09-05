import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'new_client_sheet.dart';
import 'appointment_sheet.dart';
import 'progress_card_screen.dart';
import 'record_payment_sheet.dart';

/// Screen 03 — the client file: who she is, where her package stands,
/// what she owes, and every visit she has had, day by day.
class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(clientId);
    // Briefly the case on the frame between deleting her and this route
    // popping — and permanently the case if another device deleted her
    // while this file was open.
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
            _MoneyCard(client: client),
            const SizedBox(height: 14),
            _VisitHistoryCard(client: client),
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

enum _ClientAction { bookVisit, recordPayment, editClient, shareProgress, deleteClient }

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
          value: _ClientAction.bookVisit,
          child: Text('موعد جديد', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.recordPayment,
          child: Text('تسجيل دفعة', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.editClient,
          child: Text('تعديل البيانات', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.shareProgress,
          child: Text('مشاركة تقدّمها', style: AppText.rowTitleSmall),
        ),
        PopupMenuItem(
          value: _ClientAction.deleteClient,
          child: Text(
            'حذف العميلة',
            style: AppText.rowTitleSmall.copyWith(color: AppColors.clayDark),
          ),
        ),
      ],
    );
  }

  void _run(BuildContext context, _ClientAction action) {
    switch (action) {
      case _ClientAction.recordPayment:
        RecordPaymentSheet.show(context, clientId: client.id);
      case _ClientAction.bookVisit:
        AppointmentSheet.show(context, initialClientId: client.id);
      case _ClientAction.editClient:
        NewClientSheet.show(context, client: client);
      case _ClientAction.shareProgress:
        Navigator.of(context).push(ProgressCardScreen.route(clientId: client.id));
      case _ClientAction.deleteClient:
        _confirmDelete(context);
    }
  }

  /// Deleting takes her packages, payments and visits with her, so it
  /// asks first and says exactly that — there is no undo for it.
  Future<void> _confirmDelete(BuildContext context) async {
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حذف ${client.name}؟', style: AppText.navTitle),
        content: Text(
          'سيُحذف ملفها بالكامل: باقاتها ودفعاتها وكل زياراتها. لا يمكن التراجع عن هذا.',
          style: AppText.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AppText.textButton.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('حذف', style: AppText.textButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Leave the file before the client it is showing stops existing.
    if (navigator.canPop()) navigator.pop();
    store.deleteClient(client.id);
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
    final attended = store.attendedCount(client.id);
    final perPackage = AppStore.packageRate.visitCount;
    final remaining = store.remainingVisits(client.id);

    final progressLabel = attended == 0
        ? 'لم تبدأ بعد'
        : remaining == 0
        ? 'أكملت باقتها'
        : 'الزيارة ${fmtInt(store.visitInPackage(client.id))} من ${fmtInt(perPackage)}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          label: 'بدأت ${ArabicDates.dayMonth(client.startDate)}',
          background: AppColors.card,
          foreground: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: AppText.pillMuted,
        ),
        StatusPill.due(
          progressLabel,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        // The number she is really asking about: how many visits are left
        // before the next ١٠٠ ₪ is due.
        StatusPill.success(
          remaining == 0 ? 'الباقة التالية' : '${fmtInt(remaining)} متبقية',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        if (client.priorVisits > 0)
          StatusPill.neutral(
            '${fmtInt(client.priorVisits)} زيارة سابقة',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
      ],
    );
  }
}

/// What she owes, what she has paid, and when she last paid it.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final due = store.balanceDueFor(client.id);
    final settled = due <= 0;
    final lastPayment = store.lastPaymentFor(client.id);
    final owed = store.packagesOwedBy(client.id);
    final payments = store.paymentsFor(client.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settled ? 'الحساب' : 'رصيد مستحق', style: AppText.meta),
                    const SizedBox(height: 4),
                    Text(
                      settled ? 'لا يوجد مستحق' : fmtCurrency(due),
                      style: settled
                          ? AppText.amountLarge.copyWith(color: AppColors.sageText)
                          : AppText.amountLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconTile(
                icon: AppIcons.card,
                color: settled ? AppColors.sage : AppColors.clay,
                background: settled ? AppColors.sageBgAlt : AppColors.dueBg,
                size: 52,
                radius: 18,
                iconSize: 26,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // "متى دفعت آخر مرة" — the question the balance alone doesn't
          // answer, and the one that says whether she is simply behind or
          // has been deferring for a while.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('آخر دفعة', style: AppText.metaSmall),
              Flexible(
                child: Text(
                  lastPayment == null
                      ? 'لم تدفع بعد'
                      : '${ArabicDates.dayMonth(lastPayment.date)}'
                            ' · ${fmtCurrency(lastPayment.amount)}',
                  style: AppText.rowTitleSmall,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!settled) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill.due(
                owed > 1
                    ? 'متأخرة بـ${ArabicDates.packages(owed)}'
                    : (lastPayment == null && client.priorPaid == 0
                          ? 'لم تدفع بعد'
                          : 'دفعة مؤجَّلة'),
                textStyle: AppText.pillSmall,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Where the balance comes from, spelled out — four visits to a
          // package, so the number is never a mystery.
          Text(
            '${ArabicDates.visits(store.attendedCount(client.id))}'
            ' · ${ArabicDates.packages(store.packagesUsed(client.id))}'
            ' × ${fmtCurrency(AppStore.packageRate.price)}'
            ' = ${fmtCurrency(store.amountChargedFor(client.id))}'
            ' · دُفع ${fmtCurrency(store.amountPaidFor(client.id))}',
            style: AppText.metaSmall,
          ),
          if (payments.isNotEmpty) ...[
            const RowDivider(),
            Text('الدفعات', style: AppText.sectionTitle),
            const SizedBox(height: 8),
            for (final payment in payments) _PaymentRow(client: client, payment: payment),
            if (client.priorPaid > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'دفعات سابقة (قبل التسجيل هنا) · ${fmtCurrency(client.priorPaid)}',
                  style: AppText.metaSmall,
                ),
              ),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'تسجيل دفعة',
            height: 54,
            radius: 16,
            textStyle: AppText.buttonMedium.copyWith(color: AppColors.card),
            onPressed: () => RecordPaymentSheet.show(context, clientId: client.id),
          ),
        ],
      ),
    );
  }
}

/// One recorded payment, with a way to take it back — a wrong amount
/// typed in a hurry is otherwise stuck in her balance for good.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.client, required this.payment});

  final Client client;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => RecordPaymentSheet.show(context, clientId: client.id, paymentId: payment.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${ArabicDates.dayMonth(payment.date)} · ${payment.method.label}',
                style: AppText.metaSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtCurrency(payment.amount), style: AppText.rowTitleSmall),
            IconAction(
              icon: AppIcons.trash,
              size: 20,
              color: AppColors.textTertiary,
              tooltip: 'حذف الدفعة',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final store = StoreScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حذف الدفعة؟', style: AppText.navTitle),
        content: Text(
          'ستعود ${fmtCurrency(payment.amount)} إلى الرصيد المستحق على ${client.name}.',
          style: AppText.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AppText.textButton.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('حذف', style: AppText.textButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.deletePayment(payment.id);
  }
}

/// Every visit she has had — the day, the date, and what happened —
/// newest first, and each one correctable if it was recorded wrong.
class _VisitHistoryCard extends StatelessWidget {
  const _VisitHistoryCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visits = store.visitsForClient(client.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('سجل الزيارات', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          if (visits.isEmpty)
            Text('لا زيارات بعد.', style: AppText.metaSmall)
          else
            for (final visit in visits) ...[
              _VisitRow(visit: visit),
              if (visit != visits.last) const RowDivider(),
            ],
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final perPackage = AppStore.packageRate.visitCount;
    final number = store.visitNumber(visit);

    final (
      Color background,
      Color foreground,
      String badge,
      String note,
    ) = switch (visit.status) {
      VisitStatus.attended => (
        AppColors.sageBgAlt,
        AppColors.sageText,
        fmtInt(number!),
        'حضرت · الزيارة ${fmtInt(number)} من ${fmtInt(perPackage)}',
      ),
      // A dash, not a number: a missed appointment took no slot in the
      // package, so there is no "visit N" for it to be.
      VisitStatus.noShow => (
        AppColors.dueBg,
        AppColors.clayDark,
        '—',
        'لم تحضر · لم تُحتسب من الباقة',
      ),
      VisitStatus.scheduled => (
        AppColors.divider,
        AppColors.textMuted,
        fmtInt(number ?? 1),
        'موعد لم يُسجَّل بعد',
      ),
    };

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
          child: Text(badge, style: AppText.packageIndex.copyWith(color: foreground)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ArabicDates.weekdayDayMonth(visit.scheduledAt)}'
                ' · ${ArabicDates.time(visit.scheduledAt)}',
                style: AppText.rowTitleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: AppText.metaSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        TextActionButton(
          // Keyed by the visit so a caller — a test, or a deep link into
          // one row — can reach a specific row's action rather than
          // counting identical "تعديل" buttons down the list.
          key: ValueKey('edit-visit-${visit.id}'),
          label: 'تعديل',
          onPressed: () => VisitStatusSheet.show(context, visitId: visit.id),
        ),
      ],
    );
  }
}

/// Corrects what was recorded for a visit — "قلت إنها حضرت وتبيّن أنها
/// لم تحضر". Changing an attendance back gives the visit to the package
/// again, and reopens it if it had been closed by that visit.
class VisitStatusSheet extends StatelessWidget {
  const VisitStatusSheet({super.key, required this.visitId});

  final String visitId;

  static Future<void> show(BuildContext context, {required String visitId}) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => VisitStatusSheet(visitId: visitId),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visit = store.visits.where((v) => v.id == visitId).firstOrNull;
    if (visit == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تعديل الزيارة', style: AppText.navTitle),
            const SizedBox(height: 4),
            Text(ArabicDates.weekdayDayMonth(visit.scheduledAt), style: AppText.metaSmall),
            const SizedBox(height: 18),
            _StatusChoice(
              label: 'حضرت',
              detail: 'تُحتسب من زيارات الباقة',
              selected: visit.status == VisitStatus.attended,
              onTap: () => _apply(context, VisitStatus.attended),
            ),
            const SizedBox(height: 10),
            _StatusChoice(
              label: 'لم تحضر',
              detail: 'تبقى في السجل ولا تُحتسب من الباقة',
              selected: visit.status == VisitStatus.noShow,
              onTap: () => _apply(context, VisitStatus.noShow),
            ),
            const SizedBox(height: 10),
            _StatusChoice(
              label: 'لم يُسجَّل بعد',
              detail: 'إعادة الموعد كما لو لم يُحسم',
              selected: visit.status == VisitStatus.scheduled,
              onTap: () => _apply(context, VisitStatus.scheduled),
            ),
          ],
        ),
      ),
    );
  }

  void _apply(BuildContext context, VisitStatus status) {
    // celebrate: false — this is bookkeeping, not the moment she finishes
    // a package, even when the correction happens to complete one.
    StoreScope.read(context).markVisit(visitId, status, celebrate: false);
    Navigator.of(context).pop();
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.sageBgAlt : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.sage : AppColors.borderSoft,
              width: selected ? 2.5 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.listNameSmall),
                    const SizedBox(height: 2),
                    Text(detail, style: AppText.metaSmall),
                  ],
                ),
              ),
              if (selected) LineIcon(AppIcons.check, color: AppColors.sage, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The packages her visits have added up to.
///
/// There are no package records to list any more, so this is worked out:
/// her attended visits in date order, cut into fours. Each block shows
/// the span it covered and whether her payments have reached it yet —
/// money is a running total, so the first ١٠٠ ₪ settles the first
/// package whatever she was thinking of when she handed it over.
class _PackageHistoryCard extends StatelessWidget {
  const _PackageHistoryCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final perPackage = AppStore.packageRate.visitCount;
    final price = AppStore.packageRate.price;
    final paid = store.amountPaidFor(client.id);

    // Oldest first, so the first four are the first package.
    final attended = store
        .visitsForClient(client.id)
        .where((v) => v.status == VisitStatus.attended)
        .toList()
        .reversed
        .toList();
    final total = store.packagesUsed(client.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الباقات', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          if (total == 0)
            Text('لم تبدأ أي باقة بعد.', style: AppText.metaSmall)
          else
            for (var block = total; block >= 1; block--) ...[
              _PackageBlockRow(
                number: block,
                // Visits in this block that have dates here. A client
                // carried in with prior visits has fewer dated ones than
                // her count implies, and the earliest blocks may have
                // none at all — which the row says rather than inventing.
                dates: _datesForBlock(attended, client.priorVisits, block, perPackage),
                size: perPackage,
                isPaid: paid >= block * price,
                isCurrent: block == total && store.remainingVisits(client.id) > 0,
              ),
              if (block > 1) const RowDivider(),
            ],
        ],
      ),
    );
  }

  /// The dated visits falling in package [block], accounting for any
  /// undated ones carried in with the client.
  static List<DateTime> _datesForBlock(
    List<Visit> attended,
    int priorVisits,
    int block,
    int perPackage,
  ) {
    final from = (block - 1) * perPackage;
    final to = block * perPackage;
    final dates = <DateTime>[];
    for (var i = 0; i < attended.length; i++) {
      final position = priorVisits + i;
      if (position >= from && position < to) dates.add(attended[i].scheduledAt);
    }
    return dates;
  }
}

class _PackageBlockRow extends StatelessWidget {
  const _PackageBlockRow({
    required this.number,
    required this.dates,
    required this.size,
    required this.isPaid,
    required this.isCurrent,
  });

  final int number;
  final List<DateTime> dates;
  final int size;
  final bool isPaid;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final span = dates.isEmpty
        ? 'زيارات سابقة'
        : dates.length == 1
        ? ArabicDates.dayMonth(dates.first)
        : '${ArabicDates.dayMonth(dates.first)} — ${ArabicDates.dayMonth(dates.last)}';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.sageBgAlt : AppColors.divider,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            fmtInt(number),
            style: AppText.packageIndex.copyWith(
              color: isCurrent ? AppColors.sageText : AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrent
                    ? '${ArabicDates.visits(dates.length)} من ${fmtInt(size)} · جارية'
                    : '${ArabicDates.visits(size)} · ${fmtCurrency(AppStore.packageRate.price)}',
                style: AppText.rowTitleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(span, style: AppText.metaSmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        isPaid
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
