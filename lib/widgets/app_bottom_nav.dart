import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'line_icon.dart';

/// The four destinations of the app.
enum AppTab {
  today('اليوم'),
  clients('العميلات'),
  summary('الملخص'),
  newPackage('باقة جديدة');

  const AppTab(this.label);
  final String label;
}

/// White bar with a hairline top border and four stacked icon/label items.
/// The active item is clay-dark and bold; the rest are muted.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  static final _icons = {
    AppTab.today: AppIcons.calendar,
    AppTab.clients: AppIcons.person,
    AppTab.summary: AppIcons.bars,
    AppTab.newPackage: AppIcons.plus,
  };

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
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(
                  child: _NavItem(
                    label: tab.label,
                    icon: _icons[tab]!,
                    selected: tab == current,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final LineIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.clayDark : AppColors.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineIcon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: selected ? AppText.navLabelActive : AppText.navLabelIdle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
