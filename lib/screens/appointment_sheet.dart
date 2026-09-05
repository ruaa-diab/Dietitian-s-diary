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

/// Books an appointment, records one that already happened, moves one,
/// or cancels it — everything that can be done to a single entry in the
/// schedule, in one sheet.
///
/// Pass [visitId] to edit an existing appointment; leave it null to make
/// a new one, in which case [initialDay] and [initialClientId] seed the
/// form from wherever she opened it.
///
/// Nothing has to be bought first. An appointment belongs to the client,
/// not to a package — she books, the client comes, and payment follows.
/// And nothing here is read-only: an appointment already marked حضرت can
/// still have its date, time, client or outcome corrected, because
/// "I wrote that down wrong" is the normal case, not an edge one.
class AppointmentSheet extends StatefulWidget {
  const AppointmentSheet({super.key, this.visitId, this.initialDay, this.initialClientId});

  final String? visitId;
  final DateTime? initialDay;
  final String? initialClientId;

  static Future<void> show(
    BuildContext context, {
    String? visitId,
    DateTime? initialDay,
    String? initialClientId,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => AppointmentSheet(
      visitId: visitId,
      initialDay: initialDay,
      initialClientId: initialClientId,
    ),
  );

  @override
  State<AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<AppointmentSheet> {
  String? _clientId;
  late DateTime _day;
  late TimeOfDay _time;
  late VisitStatus _status;
  String? _error;

  bool get _isEditing => widget.visitId != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final existing = _isEditing ? store.visitOrNull(widget.visitId!) : null;

    if (existing != null) {
      _clientId = existing.clientId;
      _day = DateTime(
        existing.scheduledAt.year,
        existing.scheduledAt.month,
        existing.scheduledAt.day,
      );
      _time = TimeOfDay.fromDateTime(existing.scheduledAt);
      _status = existing.status;
    } else {
      _clientId = widget.initialClientId;
      _seedNewAppointment(widget.initialDay ?? DateTime.now());
      _status = _defaultStatusFor(_at);
    }
  }

  /// Opens a new appointment on a time that is actually still bookable.
  ///
  /// A fixed 10:00 is fine for a day still ahead, but useless for today
  /// once it is past ten. Today starts at the next quarter hour instead,
  /// and if that has run past midnight it starts tomorrow morning.
  void _seedNewAppointment(DateTime day) {
    final now = DateTime.now();
    if (!ArabicDates.isSameDay(day, now)) {
      _day = DateTime(day.year, day.month, day.day);
      _time = const TimeOfDay(hour: 10, minute: 0);
      return;
    }

    final soon = now.add(const Duration(minutes: 15));
    // DateTime normalizes a 60-minute value into the next hour, and the
    // next hour past midnight into the next day.
    final next = DateTime(
      soon.year,
      soon.month,
      soon.day,
      soon.hour,
      ((soon.minute + 14) ~/ 15) * 15,
    );
    if (next.day != now.day) {
      _day = DateTime(now.year, now.month, now.day + 1);
      _time = const TimeOfDay(hour: 10, minute: 0);
    } else {
      _day = DateTime(next.year, next.month, next.day);
      _time = TimeOfDay(hour: next.hour, minute: next.minute);
    }
  }

  /// A date still to come is a booking; one already past is something
  /// she is writing up after the fact, and the overwhelmingly likely
  /// reason to write one up is that the client came.
  static VisitStatus _defaultStatusFor(DateTime at) =>
      at.isBefore(DateTime.now()) ? VisitStatus.attended : VisitStatus.scheduled;

  DateTime get _at => DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _pickClient() async {
    final chosen = await ClientPickerSheet.show(context);
    if (chosen == null || !mounted) return;
    setState(() {
      _clientId = chosen;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      // Backwards as well as forwards: "she came last Tuesday and I
      // never wrote it down" has to be recordable, and so does "she came
      // without an appointment at all".
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      // Only nudge the status on a *new* entry, and only while she has
      // not chosen one herself — never overrule an explicit answer.
      if (!_isEditing && !_statusTouched) _status = _defaultStatusFor(_at);
      _error = null;
    });
  }

  bool _statusTouched = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _error = null;
    });
  }

  void _save() {
    final clientId = _clientId;
    if (clientId == null) {
      setState(() => _error = 'اختاري العميلة أولاً.');
      return;
    }
    if (_status == VisitStatus.scheduled && _at.isBefore(DateTime.now())) {
      setState(
        () =>
            _error = 'هذا الوقت مضى. اختاري وقتاً قادماً، أو سجّلي الزيارة كحضور أو عدم حضور.',
      );
      return;
    }

    final store = StoreScope.read(context);
    if (_isEditing) {
      store.updateVisit(widget.visitId!, at: _at, clientId: clientId, status: _status);
    } else {
      store.scheduleVisit(clientId: clientId, at: _at, status: _status);
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('حذف الموعد؟', style: AppText.navTitle),
        content: Text(
          'سيُحذف الموعد من الجدول. إن كان مسجّلاً كحضور، لن تُحتسب تلك الزيارة بعد الآن.',
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
    store.deleteVisit(widget.visitId!);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = _clientId == null ? null : store.clientOrNull(_clientId!);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'تعديل الموعد' : 'موعد جديد', style: AppText.navTitle),
              const SizedBox(height: 20),
              const FieldLabel('العميلة'),
              _PickerRow(
                value: client?.name ?? 'اختاري العميلة',
                muted: client == null,
                leading: client == null
                    ? null
                    : ClientAvatar(name: client.name, seed: client.id, size: 40),
                onTap: _pickClient,
              ),
              const SizedBox(height: 16),
              const FieldLabel('التاريخ'),
              _PickerRow(
                value: ArabicDates.weekdayDayMonth(_day),
                trailing: LineIcon(AppIcons.calendar, color: AppColors.textMuted, size: 22),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              const FieldLabel('الوقت'),
              _PickerRow(
                value: ArabicDates.time(_at),
                trailing: LineIcon(AppIcons.clock, color: AppColors.textMuted, size: 22),
                onTap: _pickTime,
              ),
              const SizedBox(height: 16),
              const FieldLabel('الحالة'),
              SegmentedRow<VisitStatus>(
                values: VisitStatus.values,
                selected: _status,
                labelOf: _statusLabel,
                onSelect: (status) => setState(() {
                  _status = status;
                  _statusTouched = true;
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              Text(switch (_status) {
                VisitStatus.scheduled => 'موعد قادم، لم يُحسم بعد.',
                VisitStatus.attended => 'تُحتسب من زيارات الباقة.',
                VisitStatus.noShow => 'تبقى في السجل ولا تُحتسب من الباقة.',
              }, style: AppText.metaSmall),
              if (client != null && _status == VisitStatus.attended) ...[
                const SizedBox(height: 10),
                _Notice(
                  text:
                      'هذه ستكون الزيارة'
                      ' ${fmtInt(_projectedNumber(store, client.id))}'
                      ' من ${fmtInt(AppStore.packageRate.visitCount)} لـ${client.name}.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppText.metaSmall.copyWith(color: AppColors.clayDark)),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isEditing ? 'حفظ التعديلات' : 'حفظ الموعد',
                onPressed: _save,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                SecondaryButton(label: 'حذف الموعد', onPressed: _delete),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Which visit of the package this one would be if saved as attended —
  /// counting the one being edited out first, so re-saving an existing
  /// attendance doesn't read as if it were an extra one.
  int _projectedNumber(AppStore store, String clientId) {
    var attended = store.attendedCount(clientId);
    final existing = _isEditing ? store.visitOrNull(widget.visitId!) : null;
    if (existing != null &&
        existing.status == VisitStatus.attended &&
        existing.clientId == clientId) {
      attended -= 1;
    }
    return (attended % AppStore.packageRate.visitCount) + 1;
  }

  static String _statusLabel(VisitStatus status) => switch (status) {
    VisitStatus.scheduled => 'موعد',
    VisitStatus.attended => 'حضرت',
    VisitStatus.noShow => 'لم تحضر',
  };
}

/// A short explanatory panel — why something is locked, or what is
/// missing before it can be saved.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.honeyBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: AppText.metaSmall.copyWith(color: AppColors.honeyText, height: 1.6),
      ),
    );
  }
}

/// A tappable field that opens a picker rather than a keyboard, styled to
/// match [AppTextField] so the form reads as one thing.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.value,
    required this.onTap,
    this.leading,
    this.trailing,
    this.muted = false,
  });

  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.borderSoft, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                value,
                style: muted
                    ? AppText.placeholder.copyWith(fontSize: 16)
                    : AppText.rowTitleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing ?? LineIcon(AppIcons.chevron, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Picks who an appointment is for, by searching her book.
///
/// Twenty-four names is already more than a list worth scrolling, so the
/// field comes first. When the search finds nobody — usually because the
/// person on the phone is new — the same empty result offers to add her,
/// rather than sending her out to العميلات and back.
class ClientPickerSheet extends StatefulWidget {
  const ClientPickerSheet({super.key});

  static Future<String?> show(BuildContext context) => showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const ClientPickerSheet(),
  );

  @override
  State<ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<ClientPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addClient() async {
    final navigator = Navigator.of(context);
    // Whoever she just created is who she meant, so hand her straight
    // back as the picker's answer.
    final created = await NewClientSheet.show(context);
    if (created == null || !mounted) return;
    navigator.pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final query = _search.text.trim();
    final matches = store.searchClients(query, ClientFilter.all)
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('اختاري العميلة', style: AppText.navTitle),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _search,
                      hint: 'ابحثي بالاسم أو رقم الهاتف',
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      suffix: LineIcon(
                        AppIcons.search,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        query.isEmpty ? 'لم تضيفي عميلات بعد.' : 'لا توجد عميلة بهذا الاسم.',
                        style: AppText.bodyLarge,
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(label: 'إضافة عميلة جديدة', onPressed: _addClient),
                    ],
                  ),
                )
              else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) =>
                        const RowDivider(margin: EdgeInsets.symmetric(vertical: 6)),
                    itemBuilder: (context, index) {
                      final client = matches[index];
                      final due = store.balanceDueFor(client.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClientAvatar(name: client.name, seed: client.id, size: 44),
                        title: Text(client.name, style: AppText.rowTitle),
                        subtitle: Text(
                          due > 0
                              ? '${fmtInt(store.remainingVisits(client.id))} متبقية'
                                    ' · ${fmtCurrency(due)} مستحقة'
                              : '${fmtInt(store.remainingVisits(client.id))} متبقية',
                          style: AppText.metaSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(client.id),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SecondaryButton(label: 'إضافة عميلة جديدة', onPressed: _addClient),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One appointment in a list — the shape used by the schedule's day view.
class AppointmentRow extends StatelessWidget {
  const AppointmentRow({super.key, required this.visit, this.onTap});

  final Visit visit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(visit.clientId);
    if (client == null) return const SizedBox.shrink();

    final (String label, Color background, Color foreground) = switch (visit.status) {
      VisitStatus.attended => ('حضرت', AppColors.sageBg, AppColors.sageText),
      VisitStatus.noShow => ('لم تحضر', AppColors.dueBg, AppColors.clayDark),
      VisitStatus.scheduled => ('موعد', AppColors.neutralChipBg, AppColors.neutralChipText),
    };

    return InkWell(
      onTap: onTap,
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
                  Text(ArabicDates.time(visit.scheduledAt), style: AppText.metaSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: label,
              background: background,
              foreground: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: AppText.pillSmall,
            ),
          ],
        ),
      ),
    );
  }
}
