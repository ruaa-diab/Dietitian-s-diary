import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'appointment_sheet.dart';

/// المواعيد — the calendar. A month at a glance, the chosen day's
/// appointments underneath, and everything that can be done to one:
/// booking a new appointment, moving it, and cancelling it.
///
/// اليوم answers "who is in front of me now"; this answers "what does the
/// week look like", which is why it is a screen of its own rather than a
/// mode of that one.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selected;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final day = widget.initialDay ?? DateTime.now();
    _selected = DateTime(day.year, day.month, day.day);
    _month = DateTime(day.year, day.month);
  }

  void _stepMonth(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
      });

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selected = DateTime(now.year, now.month, now.day);
      _month = DateTime(now.year, now.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visits = store.visitsOn(_selected);
    final now = DateTime.now();
    final isToday = ArabicDates.isSameDay(_selected, now);
    // Appointments are things still to happen, so a day already gone
    // can be read but not booked into.
    final isPast = _selected.isBefore(DateTime(now.year, now.month, now.day));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المواعيد', style: AppText.screenTitle),
            if (!isToday) TextActionButton(label: 'اليوم', onPressed: _jumpToToday),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          child: Column(
            children: [
              _MonthHeader(
                month: _month,
                onPrevious: () => _stepMonth(-1),
                onNext: () => _stepMonth(1),
              ),
              const SizedBox(height: 12),
              _MonthGrid(
                month: _month,
                selected: _selected,
                busyDays: store.scheduledDaysIn(_month),
                onSelect: (day) => setState(() => _selected = day),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                ArabicDates.weekdayDayMonth(_selected),
                style: AppText.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            StatusPill.neutral(
              visits.isEmpty ? 'لا مواعيد' : ArabicDates.visits(visits.length),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: AppText.pillSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: visits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('لا مواعيد في هذا اليوم.', style: AppText.bodyLarge),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final visit in visits) ...[
                      AppointmentRow(
                        visit: visit,
                        onTap: () => AppointmentSheet.show(context, visitId: visit.id),
                      ),
                      if (visit != visits.last) const RowDivider(margin: EdgeInsets.zero),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'إضافة موعد',
          onPressed: isPast
              ? null
              : () => AppointmentSheet.show(context, initialDay: _selected),
        ),
        const SizedBox(height: 10),
        Text(
          isPast
              ? 'لا يمكن حجز موعد في يوم مضى. اختاري اليوم أو يوماً قادماً.'
              : 'اضغطي على أي موعد لتغيير وقته أو تاريخه أو العميلة، أو لحذفه.',
          style: AppText.metaSmall,
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // In RTL the row starts on the right, so the first child is the one
    // that steps backwards — and it is the chevron pointing that way.
    return Row(
      children: [
        IconAction(
          icon: AppIcons.chevron,
          size: 22,
          color: AppColors.textSecondary,
          tooltip: 'الشهر السابق',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            ArabicDates.monthYear(month),
            textAlign: TextAlign.center,
            style: AppText.rowTitle,
          ),
        ),
        IconAction(
          icon: AppIcons.chevronBack,
          size: 22,
          color: AppColors.textSecondary,
          tooltip: 'الشهر التالي',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.busyDays,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;

  /// Days of [month] that have at least one appointment.
  final Set<int> busyDays;
  final ValueChanged<DateTime> onSelect;

  /// The week starts on Sunday, as it does here.
  static const _weekdayInitials = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is Monday-based (1–7); % 7 turns it into a
    // Sunday-first column index.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;

    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      for (var day = 1; day <= daysInMonth; day++) DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(initial, style: AppText.metaTiny),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < cells.length ~/ 7; week++)
          Row(
            children: [
              for (final day in cells.sublist(week * 7, week * 7 + 7))
                Expanded(
                  child: day == null
                      ? const SizedBox(height: 44)
                      : _DayCell(
                          day: day,
                          selected: ArabicDates.isSameDay(day, selected),
                          isToday: ArabicDates.isSameDay(day, today),
                          busy: busyDays.contains(day.day),
                          onTap: () => onSelect(day),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.busy,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.clay
        : (isToday ? AppColors.clayTint : Colors.transparent);
    final foreground = selected
        ? AppColors.card
        : (isToday ? AppColors.clayDark : AppColors.textPrimary);

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fmtInt(day.day),
                  style: AppText.pill.copyWith(color: foreground),
                ),
              ),
              const SizedBox(height: 3),
              // The dot is the whole point of the month view: which days
              // already have someone on them.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy
                      ? (selected ? AppColors.clay : AppColors.sage)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
