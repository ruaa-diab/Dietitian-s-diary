import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/app_shell.dart';

/// Runs without Firebase, on the sample roster, opening straight on the
/// welcome screen — for trying the app out before a Firebase project
/// exists, and for showing it to someone without handing over an account.
///
/// Turned on per-run, never in the committed source:
/// `flutter run --dart-define=DEMO=true`. Off, [main] is unchanged and
/// production knows nothing about it.
///
/// Nothing entered in demo mode is saved anywhere: the store is in
/// memory, so a restart brings the sample roster back exactly as it was.
const _demoMode = bool.fromEnvironment('DEMO');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.card,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  if (_demoMode) {
    // Firebase is deliberately not initialized: with placeholder options
    // it would either fail here or fail later at sign-in, and demo mode
    // never reaches either.
    runApp(TaghdiyaApp(store: AppStore(), home: const WelcomeScreen()));
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaghdiyaApp());
}

class TaghdiyaApp extends StatelessWidget {
  const TaghdiyaApp({super.key, this.store, this.home});

  /// Set together with [home] to skip real authentication and mount a
  /// screen directly inside a [StoreScope] built from [store] — the
  /// widget tests, and demo mode. Neither is set in a normal run, which
  /// shows [AuthGate] instead: it owns the store itself, since which
  /// account's data to load isn't known until sign-in resolves.
  final AppStore? store;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final testStore = store;
    if (testStore == null) return AuthGate();

    // StoreScope wraps the whole MaterialApp here, not just `home`'s
    // content — every route a test pushes needs it too, not only the
    // first one. AuthGate achieves the same thing production-side via
    // buildTaghdiyaMaterialApp's wrapNavigator, since its store isn't
    // known this early.
    return StoreScope(
      store: testStore,
      child: buildTaghdiyaMaterialApp(home: home ?? const SizedBox.shrink()),
    );
  }
}
