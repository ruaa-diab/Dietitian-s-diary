import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import '../widgets/line_icon.dart';
import 'record_payment_sheet.dart';
import 'progress_card_screen.dart';

/// Screen 06 — the package-complete celebration.
///
/// Pushed as a transparent route so the screen underneath stays visible
/// behind the scrim, as in the mockup.
class PackageCompleteScreen extends StatefulWidget {
  const PackageCompleteScreen({super.key, required this.clientId});

  final String clientId;

  static Route<void> route({required String clientId}) => PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => PackageCompleteScreen(clientId: clientId),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<PackageCompleteScreen> createState() => _PackageCompleteScreenState();
}

class _PackageCompleteScreenState extends State<PackageCompleteScreen>
    with TickerProviderStateMixin {
  // Built eagerly in initState, not as lazy `late final` fields: a lazy
  // initializer that has never been read fires on first access, and if
  // that first access were dispose() itself (the widget torn down before
  // its first build), creating a new AnimationController's Ticker then
  // crashes — it needs a live element to look up, which disposal doesn't
  // have.
  late final AnimationController _pop;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pop.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(widget.clientId);
    if (client == null) return const SizedBox.shrink();

    final perPackage = AppStore.packageRate.visitCount;
    final packagesDone = store.packagesUsed(client.id);
    // How long this package took: from her first visit in it to her last.
    final attendedDates = store
        .visitsForClient(client.id)
        .where((v) => v.status == VisitStatus.attended)
        .map((v) => v.scheduledAt)
        .toList()
      ..sort();
    final block = attendedDates.length >= perPackage
        ? attendedDates.sublist(attendedDates.length - perPackage)
        : attendedDates;
    final days = block.length < 2
        ? 0
        : ArabicDates.daysBetween(block.first, block.last);
    final missed = store.noShowCount(client.id);

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
                        perPackage: perPackage,
                        packagesDone: packagesDone,
                        days: days,
                        missed: missed,
                        due: store.balanceDueFor(client.id),
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
    required this.perPackage,
    required this.packagesDone,
    required this.days,
    required this.missed,
    required this.due,
  });

  final Animation<double> float;
  final Client client;
  final int perPackage;

  /// How many packages she has now finished in total — "باقتها الثانية".
  final int packagesDone;
  final int days;
  final int missed;
  final double due;

  @override
  Widget build(BuildContext context) {
    final firstName = client.name.split(' ').first;
    final ordinal = packagesDone >= 2 ? ' (باقتها ${fmtInt(packagesDone)})' : '';

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
              child: const CompletionRing(progress: 1),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${fmtInt(perPackage)} من ${fmtInt(perPackage)} — الباقة اكتملت',
            textAlign: TextAlign.center,
            style: AppText.eyebrow,
          ),
          const SizedBox(height: 10),
          Text(
            'أنهت $firstName باقتها$ordinal',
            textAlign: TextAlign.center,
            style: AppText.cardHeadline,
          ),
          const SizedBox(height: 12),
          Text(
            due > 0
                ? 'أكملت ${ArabicDates.visits(perPackage)}.'
                    ' المستحق عليها الآن ${fmtCurrency(due)}.'
                : 'أكملت ${ArabicDates.visits(perPackage)}.'
                    ' وقت مناسب للاتفاق على الباقة التالية.',
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
                label: ArabicDates.visits(perPackage),
                background: AppColors.sageBgAlt,
                foreground: AppColors.sageText,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              ),
              if (days > 0)
                StatusPill.due(
                  ArabicDates.days(days),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                ),
              StatusPill(
                label: missed == 0
                    ? 'بلا غياب'
                    : 'غابت ${ArabicDates.visits(missed)}',
                background: AppColors.honeyBg,
                foreground: AppColors.honeyText,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: due > 0 ? 'تسجيل دفعة' : 'تسجيل دفعة الباقة التالية',
            onPressed: () {
              Navigator.of(context).pop();
              RecordPaymentSheet.show(context, clientId: client.id);
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
