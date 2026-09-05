import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/practice_profile.dart';
import '../data/store_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

/// حسابي — the dietitian's own page: who she is, how the practice is
/// doing at a glance, and the two things about her account she can
/// change — her name and her password.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final activePackages =
        store.packages.where((p) => p.isActive).length;
    final visitsThisMonth = store.visits.where((v) {
      final now = DateTime.now();
      return v.scheduledAt.year == now.year && v.scheduledAt.month == now.month;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Text('حسابي', style: AppText.screenTitle),
        const SizedBox(height: 20),
        const _IdentityCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: fmtInt(store.clients.length),
                label: 'عميلة',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                value: fmtInt(activePackages),
                label: 'باقة جارية',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                value: fmtInt(visitsThisMonth),
                label: 'زيارة هذا الشهر',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('هذا الشهر', style: AppText.sectionTitle),
              const SizedBox(height: 14),
              _MoneyRow(
                label: 'الإيرادات',
                amount: fmtCurrency(store.revenueForMonth(DateTime.now())),
              ),
              const RowDivider(),
              _MoneyRow(
                label: 'رصيد مستحق',
                amount: fmtCurrency(store.totalOutstanding),
                emphasis: true,
              ),
              const RowDivider(),
              _MoneyRow(
                label: 'تحتاج تجديد',
                amount: fmtInt(store.needsRenewal.length),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _AccountCard(),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الباقات', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text(
                'الباقة الواحدة ${ArabicDates.visits(AppStore.defaultPackage.visitCount)}'
                ' بـ ${fmtCurrency(AppStore.defaultPackage.price)}.'
                ' تُباع من ملف العميلة، أو من زر «تجديد» في الملخص.',
                style: AppText.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: 'تسجيل الخروج',
          onPressed: () => _logout(context),
        ),
      ],
    );
  }

  /// AuthGate is listening for exactly this: the moment it fires, it
  /// disposes this account's store and swaps the whole tree over to
  /// LoginScreen on its own — nothing to navigate to here.
  void _logout(BuildContext context) => StoreScope.of(context).signOut();
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppCard(
      padding: const EdgeInsets.all(22),
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const BrandLeaf(size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.dietitianName,
                  style: AppText.pageHeadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(PracticeProfile.title, style: AppText.meta),
                const SizedBox(height: 8),
                StatusPill.success(
                  PracticeProfile.brandName,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: AppText.pillSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The account itself: the address she signs in with, and the two things
/// she can change about it.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final email = store.accountEmail;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الحساب', style: AppText.sectionTitle),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('البريد الإلكتروني', style: AppText.rowTitle),
              Flexible(
                child: Text(
                  email ?? '—',
                  style: AppText.metaSmall,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'تعديل الاسم',
            onPressed: () => EditNameSheet.show(context),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'تغيير كلمة المرور',
            onPressed: () => ChangePasswordSheet.show(context),
          ),
        ],
      ),
    );
  }
}

/// Renames her. The name shows on حسابي, on the welcome screen's greeting
/// and on the progress card she shares, and it is stored with her data,
/// so it follows her to every device.
class EditNameSheet extends StatefulWidget {
  const EditNameSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const EditNameSheet(),
      );

  @override
  State<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<EditNameSheet> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: StoreScope.read(context).dietitianName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    StoreScope.read(context).updateDietitianName(_name.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تعديل الاسم', style: AppText.navTitle),
              const SizedBox(height: 20),
              const FieldLabel('الاسم'),
              AppTextField(
                controller: _name,
                hint: PracticeProfile.dietitianName,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'حفظ',
                onPressed: _name.text.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Changes the account password. The current one is asked for because
/// Firebase requires a recent sign-in before it will accept a new
/// password — and because a phone left unlocked shouldn't be enough to
/// lock her out of her own account.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const ChangePasswordSheet(),
      );

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in [_current, _next, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final current = _current.text;
    final next = _next.text;

    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = 'أدخلي كلمة المرور الحالية والجديدة.');
      return;
    }
    if (next.length < 6) {
      setState(() => _error = 'كلمة المرور الجديدة ٦ خانات على الأقل.');
      return;
    }
    if (next != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.changePassword(currentPassword: current, newPassword: next);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error.code);
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تغيير كلمة المرور. حاولي مرة أخرى.';
        _submitting = false;
      });
    }
  }

  String _messageFor(String code) {
    return switch (code) {
      // A wrong current password comes back under whichever of these the
      // installed SDK version uses.
      'wrong-password' ||
      'invalid-credential' ||
      'user-mismatch' =>
        'كلمة المرور الحالية غير صحيحة.',
      'weak-password' => 'كلمة المرور الجديدة ضعيفة. اختاري واحدة أطول.',
      'requires-recent-login' => 'لأمانك، سجّلي الخروج ثم الدخول وحاولي مرة أخرى.',
      'too-many-requests' => 'محاولات كثيرة متتالية. حاولي بعد قليل.',
      // Demo mode: there is no real account behind the screen.
      'no-current-user' => 'لا يمكن تغيير كلمة المرور في وضع التجربة.',
      'network-request-failed' => 'تحققي من اتصال الإنترنت وحاولي مرة أخرى.',
      _ => 'تعذّر تغيير كلمة المرور. حاولي مرة أخرى.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تغيير كلمة المرور', style: AppText.navTitle),
              const SizedBox(height: 20),
              const FieldLabel('كلمة المرور الحالية'),
              AppTextField(
                controller: _current,
                hint: '••••••••',
                obscureText: true,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 16),
              const FieldLabel('كلمة المرور الجديدة'),
              AppTextField(
                controller: _next,
                hint: '••••••••',
                obscureText: true,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 16),
              const FieldLabel('تأكيد كلمة المرور الجديدة'),
              AppTextField(
                controller: _confirm,
                hint: '••••••••',
                obscureText: true,
                onChanged: (_) => _clearError(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppText.metaSmall.copyWith(color: AppColors.clayDark),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'حفظ كلمة المرور',
                onPressed: _submitting ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.amountMedium),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.metaSmall, maxLines: 2),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.emphasis = false,
  });

  final String label;
  final String amount;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.rowTitle),
        Text(
          amount,
          style: emphasis
              ? AppText.amountSmall
              : AppText.amountSmall.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
