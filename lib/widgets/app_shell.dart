import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../theme/app_colors.dart';
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
/// The layout is drawn for a phone. Left to fill a laptop window it
/// stretches a 412pt design across 1300px — rows a metre wide with the
/// name at one end and the status at the other, which is unreadable in a
/// way no amount of styling fixes.
///
/// So it is held to a phone-ish column and centred, with the darker
/// canvas tone either side. On a phone the constraint never binds and
/// nothing changes; on a laptop the app looks deliberate rather than
/// stretched. Only the width is limited — height still fills the window,
/// so sheets and dialogs sized as a fraction of it are unaffected.
const _maxContentWidth = 480.0;

Widget _phoneWidthFrame(Widget child) {
  return ColoredBox(
    color: AppColors.canvas,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        // SizedBox.expand, not the child alone: Center hands down *loose*
        // constraints, and the Navigator's overlay sizes to its children
        // under those — which is nothing, so the whole app renders blank.
        // Expanding inside the width cap turns them tight again: the cap
        // for width, the full window for height.
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}

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
      final framed = _phoneWidthFrame(directional);
      return wrapNavigator == null ? framed : wrapNavigator(context, framed);
    },
    home: home,
  );
}
