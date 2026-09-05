import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'clients_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';
import 'summary_screen.dart';
import 'today_screen.dart';

/// Holds the tabbed screens and the bottom navigation.
///
/// الدفعات is a tab of its own — the list of who owes what — and also
/// opens pushed for one client, from her file or from the celebration
/// when she finishes her four visits.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = AppTab.today});

  /// Which tab opens first — set when arriving from the welcome screen's
  /// "go straight to X" options, so choosing العميلات there actually
  /// lands on العميلات instead of always opening on اليوم first.
  final AppTab initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late AppTab _tab = widget.initialTab;

  void _onSelect(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: AppTab.values.indexOf(_tab),
          children: [
            const TodayScreen(),
            const ScheduleScreen(),
            const ClientsScreen(),
            const PaymentScreen(),
            const SummaryScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(current: _tab, onSelect: _onSelect),
    );
  }
}
