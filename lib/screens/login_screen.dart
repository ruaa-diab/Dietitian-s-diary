import 'package:flutter/material.dart';

import '../data/practice_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import 'welcome_screen.dart';

/// The very first screen: identifies who is opening the app before any of
/// her data is shown.
///
/// Not wired to a real account system yet — "تسجيل الدخول" only checks
/// that both fields look filled in, then continues. Firebase
/// Authentication replaces the body of [_LoginScreenState._login] once
/// the backend project exists; nothing else about this screen changes
/// when that happens, and sessions persist from then on, so this screen
/// is only seen once per install, not every time the app opens.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

    // TODO(auth): replace with a real Firebase Auth sign-in once the
    // project exists. This only proves the form and its validation work
    // — it does not check the password against anything yet.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _submitting = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
    );
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
