import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';

/// "تسجيل دفعة" — records money received against an unpaid package.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key, required this.packageId});

  final String packageId;

  static Future<void> show(BuildContext context, {required String packageId}) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => RecordPaymentSheet(packageId: packageId),
      );

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Default to settling the balance in full — the common case.
    final due = StoreScope.read(context).package(widget.packageId).balanceDue;
    _amount.text =
        due == due.roundToDouble() ? due.toStringAsFixed(0) : due.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pkg = store.package(widget.packageId);
    final client = store.client(pkg.clientId);
    final entered = double.tryParse(_amount.text.trim()) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تسجيل دفعة', style: AppText.navTitle),
              const SizedBox(height: 6),
              Text(
                '${client.name} · باقة ${ArabicDates.visits(pkg.visitCount)}',
                style: AppText.metaSmall,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المتبقي', style: AppText.inputValueLabel),
                  Text(
                    fmtCurrency(pkg.balanceDue),
                    style: AppText.amountMedium.copyWith(color: AppColors.clay),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const FieldLabel('المبلغ المستلم'),
              AppTextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                suffix: Text(AppNumerals.shekel, style: AppText.inputValueLabel),
              ),
              const SizedBox(height: 16),
              const FieldLabel('طريقة الدفع'),
              OptionTabs<PaymentMethod>(
                values: PaymentMethod.values,
                selected: _method,
                labelOf: (m) => m.label,
                onSelect: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'حفظ الدفعة',
                onPressed: entered <= 0
                    ? null
                    : () {
                        store.recordPayment(
                          packageId: widget.packageId,
                          amount: entered,
                          method: _method,
                        );
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
