import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'home_shell.dart';

/// Shown right after logging in: greets her, then offers a direct jump
/// into each part of the app — a menu, not a single generic "start"
/// button that always dumps her into today's visits.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = DateTime.now();
    final pending = store.todayVisits.where((v) => !v.isResolved).length;
    final upcoming = store.upcomingVisits.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ArabicDates.weekdayDayMonth(today), style: AppText.dateHeader),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.clay,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const BrandLeaf(size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أهلاً بعودتك', style: AppText.bodyLarge),
                        Text(store.dietitianFirstName, style: AppText.pageHeadline),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _NavOption(
                      icon: AppIcons.calendar,
                      color: AppColors.clayDark,
                      background: AppColors.clayTint,
                      title: 'اليوم',
                      subtitle: pending > 0
                          ? '${ArabicDates.visits(pending)} بانتظارك'
                          : 'لا زيارات اليوم',
                      onTap: () => _open(context, AppTab.today),
                    ),
                    const SizedBox(height: 12),
                    _NavOption(
                      icon: AppIcons.clock,
                      color: AppColors.honeyText,
                      background: AppColors.honeyBg,
                      title: 'المواعيد',
                      subtitle: upcoming > 0
                          ? '${ArabicDates.visits(upcoming)} قادمة'
                          : 'لا مواعيد قادمة',
                      onTap: () => _open(context, AppTab.schedule),
                    ),
                    const SizedBox(height: 12),
                    _NavOption(
                      icon: AppIcons.person,
                      color: AppColors.sageText,
                      background: AppColors.sageBgAlt,
                      title: 'العميلات',
                      subtitle: '${fmtInt(store.clients.length)} عميلة',
                      onTap: () => _open(context, AppTab.clients),
                    ),
                    const SizedBox(height: 12),
                    _NavOption(
                      icon: AppIcons.card,
                      color: AppColors.sageDark,
                      background: AppColors.sageBg,
                      title: 'الدفعات',
                      subtitle: store.totalOutstanding > 0
                          ? '${fmtCurrency(store.totalOutstanding)} مستحقة'
                          : 'كل الحسابات مسدّدة',
                      onTap: () => _open(context, AppTab.payments),
                    ),
                    const SizedBox(height: 12),
                    _NavOption(
                      icon: AppIcons.bars,
                      color: AppColors.clayDark,
                      background: AppColors.dueBg,
                      title: 'الملخص',
                      subtitle: 'الإيرادات والأرصدة المستحقة',
                      onTap: () => _open(context, AppTab.summary),
                    ),
                    const SizedBox(height: 12),
                    _NavOption(
                      icon: AppIcons.profile,
                      color: AppColors.textSecondary,
                      background: AppColors.divider,
                      title: 'حسابي',
                      subtitle: 'معلوماتك وإحصاءات الشهر',
                      onTap: () => _open(context, AppTab.profile),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, AppTab tab) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => HomeShell(initialTab: tab)),
    );
  }
}

class _NavOption extends StatelessWidget {
  const _NavOption({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final LineIconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x0D362B2C), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconTile(
                  icon: icon,
                  color: color,
                  background: background,
                  size: 52,
                  radius: 18,
                  iconSize: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.listName),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppText.metaSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
