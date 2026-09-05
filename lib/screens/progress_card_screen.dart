import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/practice_profile.dart';
import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';
import '../widgets/progress_card.dart';

/// Hosts the shareable progress card and the share action.
///
/// The card is laid out at its native 412pt width inside a
/// [RepaintBoundary] and scaled down to fit the screen, so the exported
/// image is always the full-size design regardless of the device.
class ProgressCardScreen extends StatefulWidget {
  const ProgressCardScreen({super.key, required this.clientId});

  final String clientId;

  static Route<void> route({required String clientId}) => MaterialPageRoute<void>(
        builder: (_) => ProgressCardScreen(clientId: clientId),
      );

  @override
  State<ProgressCardScreen> createState() => _ProgressCardScreenState();
}

class _ProgressCardScreenState extends State<ProgressCardScreen> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final client = store.clientOrNull(widget.clientId);
    final attended = client == null ? 0 : store.attendedCount(client.id);

    if (client == null || attended == 0) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onShare: null, busy: false),
              Expanded(
                child: Center(
                  child: Text('لا زيارات لعرض تقدّمها بعد.', style: AppText.bodyLarge),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Since her first recorded visit — the span the card is bragging about.
    final firstVisit = store
        .visitsForClient(client.id)
        .where((v) => v.status == VisitStatus.attended)
        .lastOrNull
        ?.scheduledAt;
    final days = ArabicDates.daysBetween(firstVisit ?? client.startDate, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onShare: _busy ? null : _share, busy: _busy),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ProgressCard(
                        client: client,
                        packageNumber: store.packagesUsed(client.id),
                        packageSize: AppStore.packageRate.visitCount,
                        days: days,
                        attendedVisits: attended,
                        byline: store.dietitianByline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the card to a PNG and hands it to the system share sheet.
  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final clientName = StoreScope.read(context).client(widget.clientId).name;
    try {
      final bytes = await captureProgressCard(_boundaryKey);
      if (bytes == null) return;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/taghdiya-progress.png');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'تقدّم $clientName مع ${PracticeProfile.brandName}',
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّرت المشاركة. حاولي مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Renders the boundary behind [key] to PNG bytes at [pixelRatio].
///
/// Exposed separately so the same card can be exported from anywhere the
/// share flow ends up living.
Future<Uint8List?> captureProgressCard(GlobalKey key, {double pixelRatio = 3}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onShare, required this.busy});

  final VoidCallback? onShare;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconAction(
              icon: AppIcons.chevron,
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text('بطاقة التقدّم', style: AppText.navTitle)),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.clay),
              )
            else
              TextActionButton(label: 'مشاركة', onPressed: onShare),
          ],
        ),
      ),
    );
  }
}
