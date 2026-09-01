import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'clients_screen.dart';
import 'profile_screen.dart';
import 'summary_screen.dart';
import 'today_screen.dart';

/// Holds the four tabbed screens and the bottom navigation.
///
/// Selling a package is not a tab: it always belongs to a specific
/// client, so it is reached from that client's file or from the
/// "تجديد" buttons in the summary.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.today;

  void _onSelect(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: AppTab.values.indexOf(_tab),
          children: const [
            TodayScreen(),
            ClientsScreen(),
            SummaryScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(current: _tab, onSelect: _onSelect),
    );
  }
}
