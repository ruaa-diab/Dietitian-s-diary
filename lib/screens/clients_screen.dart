import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import '../widgets/line_icon.dart';
import 'client_detail_screen.dart';
import 'new_client_sheet.dart';

/// Screen 02 — the client list, with the empty state of screen 08.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();
  ClientFilter _filter = ClientFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hasAnyClient = store.clients.isNotEmpty;
    final results = store.searchClients(_searchController.text, _filter);

    if (!hasAnyClient) return const _ClientsEmpty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text('العميلات', style: AppText.screenTitle),
              const SizedBox(height: 18),
              _SearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _FilterChips(
                selected: _filter,
                countFor: store.countFor,
                onSelect: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 20),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'لا نتائج مطابقة.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyLarge,
                  ),
                )
              else
                for (final client in results) ...[
                  _ClientRow(client: client),
                  if (client != results.last) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: 'عميلة جديدة',
            icon: AppIcons.plus,
            onPressed: () => NewClientSheet.show(context),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderSoft, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          LineIcon(AppIcons.search, color: AppColors.textTertiary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppText.placeholder.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'ابحثي عن عميلة بالاسم',
                hintStyle: AppText.placeholder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  final ClientFilter selected;
  final int Function(ClientFilter) countFor;
  final ValueChanged<ClientFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in ClientFilter.values)
          _Chip(
            label: '${filter.label} ${fmtInt(countFor(filter))}',
            selected: filter == selected,
            onTap: () => onSelect(filter),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: selected
                ? AppText.chip.copyWith(color: AppColors.card)
                : AppText.chipIdle,
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final active = store.activePackage(client.id);
    final latest = store.latestPackage(client.id);
    final remaining = store.remainingForClient(client.id);

    final subtitle = switch ((active, latest)) {
      (final ClientPackage pkg, _) =>
        'باقة ${ArabicDates.visits(pkg.visitCount)} · بدأت ${ArabicDates.dayMonth(pkg.startDate)}',
      (null, final ClientPackage pkg) =>
        'انتهت الباقة · ${ArabicDates.dayMonth(pkg.endDate ?? pkg.startDate)}',
      _ => 'لا توجد باقة بعد',
    };

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ClientDetailScreen(clientId: client.id),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x0D362B2C), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                ClientAvatar(
                  name: client.name,
                  seed: client.id,
                  size: 48,
                  muted: active == null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: AppText.listNameSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppText.metaSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RemainingBadge(remaining: remaining),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Remaining-visit badge, coloured by urgency: none left is neutral, the
/// last visit is flagged in clay, anything else is on-track green.
class RemainingBadge extends StatelessWidget {
  const RemainingBadge({super.key, required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final label = '${fmtInt(remaining)} متبقية';
    if (remaining == 0) return StatusPill.neutral(label);
    if (remaining == 1) return StatusPill.due(label);
    return StatusPill.success(label);
  }
}

/// Screen 08 — nothing on the books yet.
class _ClientsEmpty extends StatelessWidget {
  const _ClientsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('العميلات', style: AppText.screenTitle),
          Expanded(
            child: ScrollableCenter(
              padding: const EdgeInsets.only(top: 20, bottom: 60, left: 14, right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NoClientsIllustration(),
                  const SizedBox(height: 26),
                  Text(
                    'لم تضيفي عميلات بعد',
                    style: AppText.pageHeadline.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 290),
                    child: Text(
                      'ابدئي بأول عميلة: الاسم ورقم الهاتف يكفيان الآن.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    label: 'إضافة أول عميلة',
                    height: 58,
                    expand: false,
                    onPressed: () => NewClientSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
