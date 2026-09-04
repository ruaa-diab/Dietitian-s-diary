import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/practice_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

/// The very first screen: identifies who is opening the app before any of
/// her data is shown.
///
/// Only reached via [AuthGate] when there is no signed-in session, and
/// only shown once per install from then on — Firebase caches the
/// session on-device, so a later launch skips straight past this screen.
/// On a successful sign-in, this screen does nothing further itself:
/// [AuthGate]'s own listener notices the new session and swaps the whole
/// tree over, the same mechanism a sign-out on another screen uses too.
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key, FirebaseAuth? auth}) : auth = auth ?? FirebaseAuth.instance;

  /// Overridable so tests can supply a [FirebaseAuth] mock instead of the
  /// real singleton, which has no Firebase project to talk to in a test
  /// environment.
  final FirebaseAuth auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخلي البريد الإلكتروني وكلمة المرور.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'تحققي من صيغة البريد الإلكتروني.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      await widget.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Success needs no further action here — AuthGate's own listener
      // picks up the new session and replaces this screen.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error.code);
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تسجيل الدخول. تحققي من اتصالك وحاولي مرة أخرى.';
        _submitting = false;
      });
    }
  }

  String _messageFor(String code) {
    return switch (code) {
      'invalid-email' => 'صيغة البريد الإلكتروني غير صحيحة.',
      'user-disabled' => 'هذا الحساب معطّل.',
      // Firebase reports a wrong email and a wrong password the same way
      // on newer SDK versions ("invalid-credential"), and separately on
      // older ones — covering both keeps the message right either way.
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'too-many-requests' => 'محاولات كثيرة متتالية. حاولي بعد قليل.',
      'network-request-failed' => 'تحققي من اتصال الإنترنت وحاولي مرة أخرى.',
      _ => 'تعذّر تسجيل الدخول. حاولي مرة أخرى.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
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
                const SizedBox(height: 24),
                Text('أهلاً بعودتك', textAlign: TextAlign.center, style: AppText.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  PracticeProfile.firstName,
                  textAlign: TextAlign.center,
                  style: AppText.screenTitle.copyWith(fontSize: 40),
                ),
                const SizedBox(height: 32),
                const FieldLabel('البريد الإلكتروني'),
                AppTextField(
                  controller: _email,
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 16),
                const FieldLabel('كلمة المرور'),
                AppTextField(
                  controller: _password,
                  hint: '••••••••',
                  obscureText: true,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppText.metaSmall.copyWith(color: AppColors.clayDark)),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'تسجيل الدخول',
                  onPressed: _submitting ? null : _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
