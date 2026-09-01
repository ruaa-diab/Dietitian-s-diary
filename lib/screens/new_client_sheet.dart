import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';

/// Adds a client. Name and phone are enough to start, as the empty-state
/// copy promises; age, goal and starting weight are optional.
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
  final _goal = TextEditingController();
  final _weight = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _phone, _age, _goal, _weight]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  void _save() {
    final store = StoreScope.read(context);
    final goal = double.tryParse(_goal.text.trim());
    store.addClient(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      age: int.tryParse(_age.text.trim()) ?? 0,
      // A loss goal is entered as a plain number and stored as negative.
      goalKg: goal == null ? null : -goal.abs(),
      startWeightKg: double.tryParse(_weight.text.trim()),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('العمر'),
                        AppTextField(
                          controller: _age,
                          hint: 'سنة',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('الوزن الحالي'),
                        AppTextField(
                          controller: _weight,
                          hint: 'كجم',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const FieldLabel('هدف النزول (كجم)'),
              AppTextField(
                controller: _goal,
                hint: 'مثلاً ٦',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
