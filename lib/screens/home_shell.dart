import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'clients_screen.dart';
import 'new_package_screen.dart';
import 'summary_screen.dart';
import 'today_screen.dart';

/// Holds the three tabbed screens and the bottom navigation.
///
/// "باقة جديدة" is a full-screen flow with its own back chevron rather
/// than a tab, so it is pushed and the current tab stays selected.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.today;

  static const _tabScreens = [AppTab.today, AppTab.clients, AppTab.summary];

  void _onSelect(AppTab tab) {
    if (tab == AppTab.newPackage) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NewPackageScreen()),
      );
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabScreens.indexOf(_tab),
          children: const [
            TodayScreen(),
            ClientsScreen(),
            SummaryScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(current: _tab, onSelect: _onSelect),
    );
  }
}
