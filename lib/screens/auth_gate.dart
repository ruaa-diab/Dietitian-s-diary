import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/line_icon.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

/// Decides, on every auth-state change, whether to show the login screen
/// or the app itself — and owns the [AppStore] for whichever account is
/// currently signed in, so it can be properly disposed (its Firestore
/// listeners cancelled) the moment that changes.
///
/// This is also what makes "stay logged in" work: [FirebaseAuth] caches
/// the session on-device, so [authStateChanges] reports an existing user
/// almost immediately on a fresh launch, and this widget moves straight
/// past [LoginScreen] rather than asking for credentials again.
class AuthGate extends StatefulWidget {
  AuthGate({super.key, FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  /// Overridable so tests can supply mocks instead of the real
  /// singletons, which have no Firebase project to talk to in a test
  /// environment.
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;
  AppStore? _store;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    final oldStore = _store;
    setState(() {
      _resolved = true;
      _store = user == null
          ? null
          : AppStore.forUser(widget.firestore, user.uid, auth: widget.auth);
    });
    // Safe to dispose straight away: the KeyedSubtree below remounts the
    // whole MaterialApp fresh whenever the store's identity changes, so
    // nothing still-mounted can be holding a reference to the old one.
    oldStore?.dispose();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;

    // Keyed by account identity — including "not resolved yet" as its
    // own distinct value — never by anything that changes on ordinary
    // data updates within a session. Signing in or out is a hard
    // boundary, so the whole Navigator remounts fresh here rather than
    // patching a live route stack whose StoreScope identity just changed
    // underneath it. An earlier version pushed a replacement route
    // instead, which left a window where a screen still transitioning
    // out could rebuild against an ancestor that had already vanished
    // and crash; remounting the subtree outright doesn't have that gap,
    // since the old widgets are unmounted, not rebuilt.
    return KeyedSubtree(
      key: ValueKey(_resolved ? store : 'unresolved'),
      child: buildTaghdiyaMaterialApp(
        home: !_resolved
            ? const _ResolvingSplash()
            : (store == null ? LoginScreen(auth: widget.auth) : const WelcomeScreen()),
        // Wraps the whole Navigator, not just `home` — so every route
        // this account's app pushes (client files, sheets, the
        // new-package flow) can reach the store, the same as it could
        // when StoreScope simply wrapped a stable MaterialApp before an
        // account was even part of the picture.
        wrapNavigator: store == null
            ? null
            : (context, child) => StoreScope(store: store, child: child),
      ),
    );
  }
}

/// Shown only for the brief moment it takes Firebase to report whether a
/// session is already cached on this device.
class _ResolvingSplash extends StatelessWidget {
  const _ResolvingSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.clay,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const BrandLeaf(size: 42),
        ),
      ),
    );
  }
}
