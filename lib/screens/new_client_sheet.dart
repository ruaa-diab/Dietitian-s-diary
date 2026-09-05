import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';

/// Adds a client, or edits one. Name and phone are enough to start, as
/// the empty-state copy promises; age is optional.
///
/// Adding and editing are the same three fields against the same
/// validation, so they are the same sheet: pass a [client] to edit her,
/// leave it null to create someone new.
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
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _age]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  void _save() {
    final store = StoreScope.read(context);
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final client = widget.client;
    final id = client == null
        ? store.addClient(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            age: age,
          ).id
        : client.id;
    if (client != null) {
      store.updateClient(
        client.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        age: age,
      );
    }
    Navigator.of(context).pop(id);
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
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isEditing ? 'حفظ التعديلات' : 'حفظ',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
