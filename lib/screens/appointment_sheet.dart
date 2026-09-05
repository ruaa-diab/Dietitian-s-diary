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
import 'new_package_screen.dart';

/// Books an appointment, moves one, or cancels it — everything that can
/// be done to a single entry in the schedule, in one sheet.
///
/// Pass [visitId] to edit an existing appointment; leave it null to book
/// a new one, in which case [initialDay] and [initialClientId] seed the
/// form from wherever she opened it (a day on the calendar, a client's
/// file).
///
/// An appointment always belongs to a package the client has already
/// bought, so a client with no running package cannot be booked for one;
/// the picker says so on her row rather than silently leaving her out.
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
  String? _error;

  bool get _isEditing => widget.visitId != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final existing = _isEditing
        ? store.visits.where((v) => v.id == widget.visitId).firstOrNull
        : null;

    if (existing != null) {
      _clientId = existing.clientId;
      _day = DateTime(
        existing.scheduledAt.year,
        existing.scheduledAt.month,
        existing.scheduledAt.day,
      );
      _time = TimeOfDay.fromDateTime(existing.scheduledAt);
    } else {
      _clientId = widget.initialClientId;
      _seedNewAppointment(widget.initialDay ?? DateTime.now());
    }
  }

  /// Opens a new appointment on a time that is actually still bookable.
  ///
  /// A fixed 10:00 is fine for a day still ahead, but useless for today
  /// once it is past ten — she would open the sheet already holding an
  /// invalid time and have to fix it before saving. Today starts at the
  /// next quarter hour instead, and if that has run past midnight the
  /// appointment starts on tomorrow morning.
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
    final today = _startOfToday;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      // Nothing before today: an appointment is something still to
      // happen, and one already recorded is corrected from the client's
      // file rather than backdated here.
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _error = null;
    });
  }

  /// Any time she likes, to the minute — a visit is a point in the day,
  /// not a slot out of a fixed grid, so nothing here rounds it.
  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _error = null;
    });
  }

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _save() {
    final clientId = _clientId;
    if (clientId == null) {
      setState(() => _error = 'اختاري العميلة أولاً.');
      return;
    }
    if (_at.isBefore(DateTime.now())) {
      setState(() => _error = 'اختاري وقتاً لم يمضِ بعد.');
      return;
    }

    final store = StoreScope.read(context);
    final saved = _isEditing
        ? store.rescheduleVisit(widget.visitId!, at: _at, clientId: clientId)
        : store.scheduleVisit(clientId: clientId, at: _at) != null;

    if (!saved) {
      // The only way either call refuses: she has no package to hang the
      // appointment on.
      setState(() => _error = 'لا توجد باقة جارية لهذه العميلة. ابدئي بباقة جديدة أولاً.');
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _sellPackage(String clientId) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => NewPackageScreen(clientId: clientId)),
    );
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
          'سيُحذف الموعد من الجدول. إن كانت الزيارة مسجّلة كحضور، تعود إلى رصيد الباقة.',
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
    final visit = _isEditing
        ? store.visits.where((v) => v.id == widget.visitId).firstOrNull
        : null;
    // Once حضرت or لم تحضر has been recorded, the appointment has
    // happened: moving it would rewrite history. It can still be
    // cancelled here, and the attendance itself is corrected from the
    // client's file, which is where that decision was made.
    final recorded = visit != null && visit.isResolved;
    final needsPackage = client != null && !store.canSchedule(client.id);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'تعديل الموعد' : 'موعد جديد', style: AppText.navTitle),
              if (recorded) ...[
                const SizedBox(height: 10),
                _Notice(
                  text: visit.status == VisitStatus.attended
                      ? 'هذا الموعد مسجّل كحضور، فلا يمكن نقله. لتصحيح الحضور افتحي ملف العميلة.'
                      : 'هذا الموعد مسجّل كعدم حضور، فلا يمكن نقله. لتصحيحه افتحي ملف العميلة.',
                ),
              ],
              const SizedBox(height: 20),
              const FieldLabel('العميلة'),
              _PickerRow(
                value: client?.name ?? 'اختاري العميلة',
                muted: client == null,
                enabled: !recorded,
                leading: client == null
                    ? null
                    : ClientAvatar(name: client.name, seed: client.id, size: 40),
                onTap: _pickClient,
              ),
              if (needsPackage) ...[
                const SizedBox(height: 10),
                _Notice(
                  text:
                      'لا توجد باقة جارية لـ${client.name}. بيعي لها باقة أولاً '
                      'حتى تُحتسب زياراتها.',
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'بيع باقة لـ${client.name}',
                  onPressed: () => _sellPackage(client.id),
                ),
              ],
              const SizedBox(height: 16),
              const FieldLabel('التاريخ'),
              _PickerRow(
                value: ArabicDates.weekdayDayMonth(_day),
                enabled: !recorded,
                trailing: LineIcon(AppIcons.calendar, color: AppColors.textMuted, size: 22),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              const FieldLabel('الوقت'),
              _PickerRow(
                value: ArabicDates.time(_at),
                enabled: !recorded,
                trailing: LineIcon(AppIcons.clock, color: AppColors.textMuted, size: 22),
                onTap: _pickTime,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppText.metaSmall.copyWith(color: AppColors.clayDark)),
              ],
              const SizedBox(height: 24),
              if (!recorded)
                PrimaryButton(
                  label: _isEditing ? 'حفظ التعديلات' : 'حفظ الموعد',
                  onPressed: needsPackage ? null : _save,
                ),
              if (_isEditing) ...[
                if (!recorded) const SizedBox(height: 10),
                SecondaryButton(label: 'حذف الموعد', onPressed: _delete),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
    this.enabled = true,
  });

  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool muted;

  /// False for a field that cannot be changed — an appointment already
  /// recorded as حضرت or لم تحضر.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
                      final bookable = store.canSchedule(client.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClientAvatar(name: client.name, seed: client.id, size: 44),
                        title: Text(client.name, style: AppText.rowTitle),
                        subtitle: Text(
                          bookable
                              ? '${fmtInt(store.remainingForClient(client.id))} متبقية'
                              : 'لا توجد باقة جارية',
                          style: AppText.metaSmall,
                        ),
                        // Selectable either way: the sheet behind explains
                        // what a client with no running package needs, and
                        // offers to sell her one, which is more use than a
                        // row that simply refuses to be tapped.
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
