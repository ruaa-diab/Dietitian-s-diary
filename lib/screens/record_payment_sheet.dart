import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';

/// "تسجيل دفعة" — money received from a client, or a correction to money
/// already recorded.
///
/// The amount is set against her running balance rather than any one
/// package, so paying for two at once, or handing over part of one, is
/// just a number: nothing has to decide which block of visits it belongs
/// to.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key, required this.clientId, this.paymentId});

  final String clientId;

  /// The payment being corrected, or null when recording a new one.
  final String? paymentId;

  static Future<void> show(
    BuildContext context, {
    required String clientId,
    String? paymentId,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => RecordPaymentSheet(clientId: clientId, paymentId: paymentId),
      );

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _amount = TextEditingController();
  late PaymentMethod _method;
  late DateTime _date;

  bool get _isEditing => widget.paymentId != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final existing = widget.paymentId == null
        ? null
        : store.payments.where((p) => p.id == widget.paymentId).firstOrNull;

    if (existing != null) {
      _amount.text = _asText(existing.amount);
      _method = existing.method;
      _date = existing.date;
    } else {
      // Default to the price of a package: what she is nearly always
      // handing over. A balance two packages deep still gets ١٠٠ here,
      // because she is paying off one of them, not both.
      final due = store.balanceDueFor(widget.clientId);
      _amount.text = _asText(
        due <= 0 || due > AppStore.packageRate.price ? AppStore.packageRate.price : due,
      );
      _method = PaymentMethod.cash;
      _date = DateTime.now();
    }
  }

  static String _asText(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A payment can be backdated — she is often writing up yesterday.
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
  }

  void _save(double entered) {
    final store = StoreScope.read(context);
    if (_isEditing) {
      store.updatePayment(
        widget.paymentId!,
        amount: entered,
        method: _method,
        date: _date,
      );
    } else {
      store.recordPayment(
        clientId: widget.clientId,
        amount: entered,
        method: _method,
        date: _date,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(widget.clientId);
    if (client == null) return const SizedBox.shrink();

    final due = store.balanceDueFor(client.id);
    final entered = double.tryParse(_amount.text.trim()) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'تعديل الدفعة' : 'تسجيل دفعة', style: AppText.navTitle),
              const SizedBox(height: 6),
              Text(client.name, style: AppText.metaSmall),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المستحق عليها', style: AppText.inputValueLabel),
                  Text(
                    fmtCurrency(due),
                    style: AppText.amountMedium.copyWith(
                      color: due > 0 ? AppColors.clay : AppColors.sageText,
                    ),
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
              const FieldLabel('التاريخ'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSoft, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(ArabicDates.weekdayDayMonth(_date), style: AppText.rowTitleSmall),
                ),
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
                label: _isEditing ? 'حفظ التعديلات' : 'حفظ الدفعة',
                onPressed: entered <= 0 ? null : () => _save(entered),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
