import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'clients_screen.dart';
import 'new_package_screen.dart';
import 'profile_screen.dart';
import 'summary_screen.dart';
import 'today_screen.dart';

/// Holds the five tabbed screens and the bottom navigation.
///
/// باقة جديدة is a tab of its own, and also opens pushed with a client
/// already chosen — from a client's file, a "تجديد" button in the
/// summary, or the celebration. As a tab it starts with no client and
/// asks for one first.
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
            const ClientsScreen(),
            // Saving from the tab has nowhere to pop to, so it hands the
            // shell back to today's list instead.
            NewPackageScreen(onSaved: () => setState(() => _tab = AppTab.today)),
            const SummaryScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(current: _tab, onSelect: _onSelect),
    );
  }
}
