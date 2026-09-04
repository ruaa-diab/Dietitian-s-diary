import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_colors.dart';
import 'widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.card,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaghdiyaApp());
}

class TaghdiyaApp extends StatelessWidget {
  const TaghdiyaApp({super.key, this.store, this.home});

  /// Set together with [home] by the widget tests to skip real
  /// authentication and mount a single screen directly inside a
  /// [StoreScope] built from [store]. Neither is set in production,
  /// which shows [AuthGate] instead — it owns the store itself, since
  /// which account's data to load isn't known until sign-in resolves.
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
