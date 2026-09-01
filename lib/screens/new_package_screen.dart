import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

/// Screen 04 — sell a package.
///
/// Opens on [clientId] when one is given (renewing from the celebration
/// screen or a client file), otherwise on whoever most recently finished
/// a package.
class NewPackageScreen extends StatefulWidget {
  const NewPackageScreen({super.key, this.clientId});

  final String? clientId;

  @override
  State<NewPackageScreen> createState() => _NewPackageScreenState();
}

class _NewPackageScreenState extends State<NewPackageScreen> {
  final _amountController = TextEditingController();

  String? _clientId;
  PackageOption _option = AppStore.packageOptions.first;
  PaymentIntent _intent = PaymentIntent.paidInFull;
  PaymentMethod _method = PaymentMethod.cash;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final store = StoreScope.read(context);
    _clientId = widget.clientId ?? store.renewalCandidate?.id ?? store.clients.firstOrNull?.id;
    _syncAmount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Keeps the received amount in step with the chosen payment status.
  void _syncAmount() {
    _amountController.text = switch (_intent) {
      PaymentIntent.paidInFull => _option.price.toStringAsFixed(0),
      PaymentIntent.later => '0',
      PaymentIntent.partial => _amountController.text,
    };
  }

  double get _received => switch (_intent) {
        PaymentIntent.paidInFull => _option.price,
        PaymentIntent.later => 0,
        PaymentIntent.partial =>
          (double.tryParse(_amountController.text.trim()) ?? 0).clamp(0, _option.price),
      };

  void _save() {
    final store = StoreScope.read(context);
    final clientId = _clientId;
    if (clientId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final name = store.client(clientId).name;
    store.sellPackage(
      clientId: clientId,
      option: _option,
      intent: _intent,
      amountReceived: _received,
      method: _method,
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('تم حفظ باقة $name')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = _clientId == null ? null : store.clientOrNull(_clientId!);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        IconAction(
                          icon: AppIcons.chevron,
                          tooltip: 'رجوع',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 6),
                        Text('باقة جديدة', style: AppText.navTitle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const FieldLabel('العميلة', padding: EdgeInsets.only(top: 14, bottom: 10)),
                  _ClientPicker(
                    client: client,
                    onChange: _pickClient,
                  ),
                  const FieldLabel('الباقة', padding: EdgeInsets.only(top: 22, bottom: 10)),
                  for (final option in AppStore.packageOptions) ...[
                    _PackageOptionCard(
                      option: option,
                      selected: option.visitCount == _option.visitCount,
                      onTap: () => setState(() {
                        _option = option;
                        _syncAmount();
                      }),
                    ),
                    if (option != AppStore.packageOptions.last) const SizedBox(height: 10),
                  ],
                  const FieldLabel('الدفع', padding: EdgeInsets.only(top: 22, bottom: 10)),
                  SegmentedRow<PaymentIntent>(
                    values: PaymentIntent.values,
                    selected: _intent,
                    labelOf: (i) => i.label,
                    onSelect: (intent) => setState(() {
                      _intent = intent;
                      _syncAmount();
                    }),
                  ),
                  const SizedBox(height: 12),
                  _AmountReceivedField(
                    controller: _amountController,
                    editable: _intent == PaymentIntent.partial,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  OptionTabs<PaymentMethod>(
                    values: PaymentMethod.values,
                    selected: _method,
                    labelOf: (m) => m.label,
                    onSelect: (method) => setState(() => _method = method),
                  ),
                ],
              ),
            ),
            _Footer(
              total: _option.price,
              onSave: client == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickClient() async {
    final selected = await _ClientPickerSheet.show(context);
    if (selected != null) setState(() => _clientId = selected);
  }
}

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.client, required this.onChange});

  final Client? client;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    if (client == null) {
      return AppCard(
        shadow: false,
        radius: 20,
        border: Border.all(color: AppColors.borderSoft, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(child: Text('اختاري عميلة', style: AppText.listNameSmall)),
            TextActionButton(label: 'اختيار', onPressed: onChange),
          ],
        ),
      );
    }

    final latest = store.latestPackage(client!.id);
    final subtitle = switch (latest) {
      null => 'عميلة جديدة',
      final ClientPackage pkg when pkg.isActive =>
        '${fmtInt(store.remainingVisits(pkg.id))} زيارة متبقية',
      final ClientPackage pkg when pkg.endDate != null &&
              ArabicDates.daysBetween(pkg.endDate!, DateTime.now()) == 0 =>
        'أكملت باقتها اليوم',
      final ClientPackage pkg => 'انتهت باقتها ${ArabicDates.dayMonth(pkg.endDate!)}',
    };

    return AppCard(
      shadow: false,
      radius: 20,
      border: Border.all(color: AppColors.borderSoft, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClientAvatar(name: client!.name, seed: client!.id, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client!.name,
                  style: AppText.listNameSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.metaSmall),
              ],
            ),
          ),
          TextActionButton(label: 'تغيير', onPressed: onChange),
        ],
      ),
    );
  }
}

class _PackageOptionCard extends StatelessWidget {
  const _PackageOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PackageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.sage : AppColors.borderSoft,
              width: selected ? 2.5 : 2,
            ),
          ),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ArabicDates.visits(option.visitCount), style: AppText.listNameSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtCurrency(option.pricePerVisit)} للزيارة',
                      style: AppText.metaSmall,
                    ),
                  ],
                ),
              ),
              Text(
                fmtCurrency(option.price),
                style: AppText.packagePrice.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.sage : AppColors.radioIdle,
          width: 2.5,
        ),
      ),
      child: selected
          ? Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _AmountReceivedField extends StatelessWidget {
  const _AmountReceivedField({
    required this.controller,
    required this.editable,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool editable;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(controller.text.trim()) ?? 0;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderSoft, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text('المبلغ المستلم', style: AppText.inputValueLabel),
          const Spacer(),
          if (editable)
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppText.amountMedium,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
              ),
            )
          else
            Text(fmtPrice(amount), style: AppText.amountMedium),
          const SizedBox(width: 6),
          Text(
            AppNumerals.shekel,
            style: AppText.buttonMedium.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.total, required this.onSave});

  final double total;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإجمالي', style: AppText.inputValueLabel),
                  Text(fmtCurrency(total), style: AppText.amountMedium),
                ],
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'حفظ الباقة',
                textStyle: AppText.buttonLarge,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks which client the package is for.
class _ClientPickerSheet extends StatelessWidget {
  const _ClientPickerSheet();

  static Future<String?> show(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const _ClientPickerSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final clients = store.searchClients('', ClientFilter.all);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('اختيار العميلة', style: AppText.navTitle),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClientAvatar(name: client.name, seed: client.id, size: 44),
                    title: Text(client.name, style: AppText.rowTitle),
                    subtitle: Text(fmtPhone(client.phone), style: AppText.metaSmall),
                    onTap: () => Navigator.of(context).pop(client.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
