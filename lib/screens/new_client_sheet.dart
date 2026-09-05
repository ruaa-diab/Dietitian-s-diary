import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import 'appointment_sheet.dart';

/// Adds a client, or edits one. Name and phone are enough to start, as
/// the empty-state copy promises; everything else is optional.
///
/// Adding and editing are the same fields against the same validation,
/// so they are the same sheet: pass a [client] to edit her, leave it
/// null to create someone new.
///
/// The two history fields are what make this usable on someone who is
/// not starting today. A client may have been coming for months before
/// any of this was being written down — so "how many visits has she
/// already had" and "how much has she already paid" are asked up front,
/// and everything downstream (which visit of four she is on, what she
/// owes) counts from there. Both are editable afterwards, because the
/// answer is often "actually, three, not two".
class NewClientSheet extends StatefulWidget {
  const NewClientSheet({super.key, this.client});

  /// The client being edited, or null when adding a new one.
  final Client? client;

  /// Resolves to the id of the client added or edited, or null if she
  /// closed the sheet without saving — so a caller that opened it to
  /// choose someone (the appointment picker) can carry straight on with
  /// whoever was just created.
  static Future<String?> show(BuildContext context, {Client? client}) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => NewClientSheet(client: client),
      );

  @override
  State<NewClientSheet> createState() => _NewClientSheetState();
}

class _NewClientSheetState extends State<NewClientSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _age;
  late final TextEditingController _priorVisits;
  late final TextEditingController _priorPaid;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    // A zero age means "not recorded", so it shows as an empty field
    // rather than a literal ٠ she would have to clear first.
    _age = TextEditingController(
      text: (client?.age ?? 0) > 0 ? '${client!.age}' : '',
    );
    _priorVisits = TextEditingController(
      text: (client?.priorVisits ?? 0) > 0 ? '${client!.priorVisits}' : '',
    );
    _priorPaid = TextEditingController(
      text: (client?.priorPaid ?? 0) > 0 ? _asText(client!.priorPaid) : '',
    );
  }

  static String _asText(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  void dispose() {
    for (final controller in [_name, _phone, _age, _priorVisits, _priorPaid]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  /// Spells out what the two history fields will mean once saved, so a
  /// wrong number is obvious before it becomes a wrong balance.
  String? get _summary {
    final visits = int.tryParse(_priorVisits.text.trim()) ?? 0;
    final paid = double.tryParse(_priorPaid.text.trim()) ?? 0;
    if (visits == 0 && paid == 0) return null;

    final perPackage = AppStore.packageRate.visitCount;
    final charged = (visits / perPackage).ceil() * AppStore.packageRate.price;
    final due = charged - paid;
    final inPackage = visits == 0 ? 0 : ((visits - 1) % perPackage) + 1;

    final position = visits == 0
        ? 'لم تبدأ باقة بعد'
        : 'هي عند الزيارة ${fmtInt(inPackage)} من ${fmtInt(perPackage)}';
    final money = due > 0
        ? 'وعليها ${fmtCurrency(due)}'
        : due < 0
            ? 'ودفعت ${fmtCurrency(-due)} زيادة'
            : 'وحسابها مسدّد';
    return '$position، $money.';
  }

  void _save() {
    final store = StoreScope.read(context);
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final priorVisits = int.tryParse(_priorVisits.text.trim()) ?? 0;
    final priorPaid = double.tryParse(_priorPaid.text.trim()) ?? 0;
    final client = widget.client;

    final id = client == null
        ? store.addClient(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            age: age,
            priorVisits: priorVisits,
            priorPaid: priorPaid,
          ).id
        : client.id;
    if (client != null) {
      store.updateClient(
        client.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        age: age,
        priorVisits: priorVisits,
        priorPaid: priorPaid,
      );
    }
    Navigator.of(context).pop(id);
  }

  /// Saves, then goes straight to booking her first appointment — the
  /// next thing that happens after writing someone down.
  void _saveAndBook() {
    final navigator = Navigator.of(context);
    final store = StoreScope.read(context);
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final created = store.addClient(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      age: age,
      priorVisits: int.tryParse(_priorVisits.text.trim()) ?? 0,
      priorPaid: double.tryParse(_priorPaid.text.trim()) ?? 0,
    );
    navigator.pop(created.id);
    AppointmentSheet.show(context, initialClientId: created.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'تعديل بيانات العميلة' : 'عميلة جديدة',
                style: AppText.navTitle,
              ),
              const SizedBox(height: 20),
              const FieldLabel('الاسم'),
              AppTextField(
                controller: _name,
                hint: 'الاسم الكامل',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const FieldLabel('رقم الهاتف'),
              AppTextField(
                controller: _phone,
                hint: '٠٥٠ ٠٠٠ ٠٠٠٠',
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const FieldLabel('العمر'),
              AppTextField(
                controller: _age,
                hint: 'سنة',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 22),
              const RowDivider(margin: EdgeInsets.zero),
              const SizedBox(height: 16),
              Text('قبل التسجيل هنا', style: AppText.sectionTitle),
              const SizedBox(height: 4),
              Text(
                'إن كانت تتابع معك من قبل. اتركيهما فارغين إن كانت جديدة.',
                style: AppText.metaSmall,
              ),
              const SizedBox(height: 14),
              const FieldLabel('عدد الزيارات السابقة'),
              AppTextField(
                controller: _priorVisits,
                hint: '٠',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const FieldLabel('المبلغ المدفوع سابقاً'),
              AppTextField(
                controller: _priorPaid,
                hint: '٠',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                suffix: Text(AppNumerals.shekel, style: AppText.inputValueLabel),
                onChanged: (_) => setState(() {}),
              ),
              if (_summary != null) ...[
                const SizedBox(height: 12),
                Text(_summary!, style: AppText.metaSmall.copyWith(color: AppColors.honeyText)),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isEditing ? 'حفظ التعديلات' : 'حفظ',
                onPressed: _canSave ? _save : null,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'حفظ وحجز موعد',
                  onPressed: _canSave ? _saveAndBook : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
