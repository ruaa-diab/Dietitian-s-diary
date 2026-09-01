import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import '../widgets/line_icon.dart';
import 'new_package_screen.dart';
import 'progress_card_screen.dart';

/// Screen 06 — the package-complete celebration.
///
/// Pushed as a transparent route so the screen underneath stays visible
/// behind the scrim, as in the mockup.
class PackageCompleteScreen extends StatefulWidget {
  const PackageCompleteScreen({super.key, required this.packageId});

  final String packageId;

  static Route<void> route({required String packageId}) => PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => PackageCompleteScreen(packageId: packageId),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<PackageCompleteScreen> createState() => _PackageCompleteScreenState();
}

class _PackageCompleteScreenState extends State<PackageCompleteScreen>
    with TickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pop.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pkg = store.package(widget.packageId);
    final client = store.client(pkg.clientId);

    final attended = store.attendedCount(pkg.id);
    final days = ArabicDates.daysBetween(pkg.startDate, pkg.endDate ?? DateTime.now());
    final fullAttendance = attended == pkg.visitCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.scrim)),
          const Positioned.fill(child: ConfettiLayer()),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
                    child: FadeTransition(
                      opacity: _pop,
                      child: _CelebrationCard(
                        float: _float,
                        client: client,
                        package: pkg,
                        attended: attended,
                        days: days,
                        fullAttendance: fullAttendance,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.float,
    required this.client,
    required this.package,
    required this.attended,
    required this.days,
    required this.fullAttendance,
  });

  final Animation<double> float;
  final Client client;
  final ClientPackage package;
  final int attended;
  final int days;
  final bool fullAttendance;

  @override
  Widget build(BuildContext context) {
    final firstName = client.name.split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(color: Color(0x47362B2C), blurRadius: 60, offset: Offset(0, 24)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: float,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -6 * Curves.easeInOut.transform(float.value)),
                child: child,
              ),
              child: CompletionRing(progress: attended / package.visitCount),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${fmtInt(attended)} من ${fmtInt(package.visitCount)} — الباقة اكتملت',
            textAlign: TextAlign.center,
            style: AppText.eyebrow,
          ),
          const SizedBox(height: 10),
          Text(
            'أنهت $firstName باقتها',
            textAlign: TextAlign.center,
            style: AppText.cardHeadline,
          ),
          const SizedBox(height: 12),
          Text(
            'أكملت ${ArabicDates.visits(package.visitCount)}.'
            ' وقت مناسب لعرض الباقة التالية.',
            textAlign: TextAlign.center,
            style: AppText.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              StatusPill(
                label: ArabicDates.visits(package.visitCount),
                background: AppColors.sageBgAlt,
                foreground: AppColors.sageText,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              ),
              StatusPill.due(
                ArabicDates.days(days),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              ),
              StatusPill(
                label: fullAttendance
                    ? 'حضور كامل'
                    : 'حضور ${fmtInt(attended)} من ${fmtInt(package.visitCount)}',
                background: AppColors.honeyBg,
                foreground: AppColors.honeyText,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'بيع الباقة التالية',
            onPressed: () {
              Navigator.of(context)
                ..pop()
                ..push(MaterialPageRoute<void>(
                  builder: (_) => NewPackageScreen(clientId: client.id),
                ));
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'مشاركة تقدّمها',
            height: 56,
            radius: 20,
            textStyle: AppText.buttonMedium,
            onPressed: () => Navigator.of(context)
                .push(ProgressCardScreen.route(clientId: client.id)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 50,
            child: TextActionButton(
              label: 'لاحقاً',
              color: AppColors.textMuted,
              style: AppText.textButton,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
