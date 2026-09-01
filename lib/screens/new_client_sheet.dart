import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';

/// Adds a client. Name and phone are enough to start, as the empty-state
/// copy promises; age is optional.
class NewClientSheet extends StatefulWidget {
  const NewClientSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const NewClientSheet(),
      );

  @override
  State<NewClientSheet> createState() => _NewClientSheetState();
}

class _NewClientSheetState extends State<NewClientSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _phone, _age]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  void _save() {
    StoreScope.read(context).addClient(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      age: int.tryParse(_age.text.trim()) ?? 0,
    );
    Navigator.of(context).pop();
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
              Text('عميلة جديدة', style: AppText.navTitle),
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
                label: 'حفظ',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
