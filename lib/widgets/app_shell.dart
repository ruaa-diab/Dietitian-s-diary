import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../theme/app_theme.dart';

/// The MaterialApp configuration every entry point shares: theme, the
/// Arabic locale and its real (non-English) localizations delegates, and
/// mirroring the whole layout to RTL.
///
/// [wrapNavigator], if given, wraps the Navigator itself — every route
/// ever pushed on it, not just [home]'s initial content. That distinction
/// matters: a widget passed as `home`'s *child* is only an ancestor of
/// that first route; routes pushed later land as siblings in the
/// Navigator's overlay, outside it. AuthGate uses this to keep a
/// StoreScope in scope for every screen the signed-in app pushes, not
/// only the one it opened on.
MaterialApp buildTaghdiyaMaterialApp({
  required Widget home,
  Widget Function(BuildContext context, Widget child)? wrapNavigator,
}) {
  return MaterialApp(
    title: 'تَغذية',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    // The Global* delegates carry real Arabic strings for Material's own
    // widgets. The Default* ones are English-only, so declaring an
    // Arabic locale against them resolves to nothing and every widget
    // needing MaterialLocalizations throws.
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final directional = Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      );
      return wrapNavigator == null ? directional : wrapNavigator(context, directional);
    },
    home: home,
  );
}
