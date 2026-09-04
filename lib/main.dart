import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'screens/login_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.card,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // Opens the on-device database (seeding it on the very first launch)
  // before the first frame, so the app never shows a store that is about
  // to be replaced once loading finishes.
  final store = await AppStore.load();
  runApp(TaghdiyaApp(store: store));
}

class TaghdiyaApp extends StatelessWidget {
  const TaghdiyaApp({super.key, required this.store, this.home});

  final AppStore store;

  /// Overridden by the widget tests to mount a single screen inside the
  /// real app configuration. Production always starts at [LoginScreen].
  ///
  /// Tests share this widget rather than assembling their own MaterialApp
  /// so the two can never drift: an earlier version of the harness built
  /// its own, defaulted to English, and hid a missing Arabic
  /// localizations delegate that broke every sheet and menu on device.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'تَغذية',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        // The Global* delegates carry real Arabic strings for Material's
        // own widgets. The Default* ones are English-only, so declaring
        // an Arabic locale against them resolves to nothing and every
        // widget needing MaterialLocalizations throws.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // The whole app is Arabic: mirror layout, not just text alignment.
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: home ?? const LoginScreen(),
      ),
    );
  }
}
