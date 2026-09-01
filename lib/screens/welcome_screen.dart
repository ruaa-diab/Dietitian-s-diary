import 'package:flutter/material.dart';

import '../data/practice_profile.dart';
import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'home_shell.dart';

/// The landing screen: greets the dietitian by name and tells her what is
/// waiting before she goes anywhere.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = DateTime.now();
    final pending = store.todayVisits.where((v) => !v.isResolved).length;
    final renewals = store.needsRenewal.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ArabicDates.weekdayDayMonth(today), style: AppText.dateHeader),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.clay,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const BrandLeaf(size: 42),
                    ),
                    const SizedBox(height: 28),
                    Text('أهلاً بعودتك', style: AppText.bodyLarge),
                    const SizedBox(height: 4),
                    Text(PracticeProfile.firstName, style: AppText.screenTitle.copyWith(fontSize: 44)),
                    const SizedBox(height: 20),
                    _TodayLine(pending: pending, renewals: renewals),
                  ],
                ),
              ),
              PrimaryButton(
                label: 'ابدئي اليوم',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const HomeShell()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line brief of what needs attention, so the greeting earns its place.
class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.pending, required this.renewals});

  final int pending;
  final int renewals;

  @override
  Widget build(BuildContext context) {
    if (pending == 0 && renewals == 0) {
      return Text('لا شيء عاجل اليوم. يوم هادئ.', style: AppText.bodyLarge);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (pending > 0)
          StatusPill.success(
            '${ArabicDates.visits(pending)} بانتظارك',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: AppText.chip,
          ),
        if (renewals > 0)
          StatusPill.due(
            '${fmtInt(renewals)} تحتاج تجديد',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: AppText.chip,
          ),
      ],
    );
  }
}
