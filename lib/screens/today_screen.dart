import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import '../widgets/line_icon.dart';
import 'client_detail_screen.dart';
import 'package_complete_screen.dart';

/// Screen 01 — today's visits, with the empty state of screen 07.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visits = store.todayVisits;

    if (visits.isEmpty) return const _TodayEmpty();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        _TodayHeading(visitCount: visits.length),
        const SizedBox(height: 22),
        for (final visit in visits) ...[
          _VisitCard(visit: visit),
          if (visit != visits.last) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _TodayHeading extends StatelessWidget {
  const _TodayHeading({this.visitCount});

  final int? visitCount;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ArabicDates.weekdayDayMonth(today), style: AppText.dateHeader),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('اليوم', style: AppText.screenTitle),
            if (visitCount != null)
              StatusPill.success(
                ArabicDates.visits(visitCount!),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: AppText.chip,
              ),
          ],
        ),
      ],
    );
  }
}

/// An upcoming visit expands to the full card with حضرت / لم تحضر;
/// a resolved one collapses to a single line with تراجع.
class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.client(visit.clientId);

    void openClient() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ClientDetailScreen(clientId: client.id),
          ),
        );

    if (visit.isResolved) {
      return _ResolvedVisitRow(
        visit: visit,
        client: client,
        onUndo: () => store.undoVisit(visit.id),
        onTap: openClient,
      );
    }

    final pkg = store.package(visit.packageId);
    final attended = store.attendedCount(pkg.id);
    final isFinalVisit = visit.index == pkg.visitCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: openClient,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                ClientAvatar(
                  name: client.name,
                  seed: client.id,
                  size: 52,
                  radius: 18,
                  textStyle: AppText.listName.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: AppText.listName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(ArabicDates.time(visit.scheduledAt), style: AppText.meta),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الزيارة ${fmtInt(visit.index)} من ${fmtInt(pkg.visitCount)}',
                      style: AppText.pill.copyWith(
                        // The closing visit of a package is called out in sage.
                        color: isFinalVisit ? AppColors.sage : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ProgressDots(total: pkg.visitCount, done: attended),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'حضرت',
                  color: AppColors.sage,
                  height: 52,
                  radius: 16,
                  textStyle: AppText.buttonMedium.copyWith(color: AppColors.card),
                  onPressed: () => _resolve(context, VisitStatus.attended),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'لم تحضر',
                  onPressed: () => _resolve(context, VisitStatus.noShow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Marks the visit and, if that closed the package, raises the
  /// celebration screen.
  void _resolve(BuildContext context, VisitStatus status) {
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    store.markVisit(visit.id, status);

    final completed = store.pendingCelebration;
    if (completed == null) return;
    store.consumeCelebration();
    navigator.push(
      PackageCompleteScreen.route(packageId: completed.id),
    );
  }
}

class _ResolvedVisitRow extends StatelessWidget {
  const _ResolvedVisitRow({
    required this.visit,
    required this.client,
    required this.onUndo,
    required this.onTap,
  });

  final Visit visit;
  final Client client;
  final VoidCallback onUndo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final attended = visit.status == VisitStatus.attended;
    final label = attended ? 'حضرت' : 'لم تحضر';

    return Material(
      color: attended ? AppColors.sageBgAlt : AppColors.dueBg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: attended ? AppColors.sage : AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: LineIcon(
                  attended ? AppIcons.check : AppIcons.close,
                  color: attended ? AppColors.card : AppColors.clay,
                  size: attended ? 26 : 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: AppText.listName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$label · ${ArabicDates.time(visit.scheduledAt)}',
                      style: AppText.meta.copyWith(
                        fontWeight: FontWeight.w500,
                        color: attended ? AppColors.sageText : AppColors.clayDark,
                      ),
                    ),
                  ],
                ),
              ),
              TextActionButton(label: 'تراجع', onPressed: onUndo),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 07 — a quiet day.
class _TodayEmpty extends StatelessWidget {
  const _TodayEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TodayHeading(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 14, right: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NoVisitsIllustration(),
                  const SizedBox(height: 26),
                  Text(
                    'لا زيارات اليوم',
                    style: AppText.pageHeadline.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Text(
                      'يوم هادئ. خذي راحتك، أو أضيفي موعداً إن اتصلت إحدى العميلات.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    label: 'إضافة موعد',
                    height: 58,
                    expand: false,
                    onPressed: () => AddAppointmentSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Books an extra visit against a client's running package.
class AddAppointmentSheet extends StatelessWidget {
  const AddAppointmentSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const AddAppointmentSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final candidates = store.clients
        .where((c) => store.remainingForClient(c.id) > 0)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('إضافة موعد اليوم', style: AppText.navTitle),
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'لا توجد عميلة لديها زيارات متبقية. ابدئي بباقة جديدة أولاً.',
                  style: AppText.bodyLarge,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const RowDivider(
                    margin: EdgeInsets.symmetric(vertical: 6),
                  ),
                  itemBuilder: (context, index) {
                    final client = candidates[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClientAvatar(name: client.name, seed: client.id, size: 44),
                      title: Text(client.name, style: AppText.rowTitle),
                      subtitle: Text(
                        '${fmtInt(store.remainingForClient(client.id))} متبقية',
                        style: AppText.metaSmall,
                      ),
                      onTap: () => _pickTime(context, client),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, Client client) async {
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    final now = DateTime.now();
    store.scheduleVisit(
      clientId: client.id,
      at: DateTime(now.year, now.month, now.day, time.hour, time.minute),
    );
    navigator.pop();
  }
}
