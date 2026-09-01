import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatting.dart';

/// The sage line chart with a soft area fill under it.
///
/// Hand-rolled with a [CustomPainter] rather than a chart package: the
/// design needs exactly one series, three grid lines, ring markers and an
/// emphasised final point.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.logs,
    this.height = 150,
    this.lineWidth = 4,
    this.markerRadius = 5.5,
    this.lastMarkerRadius = 8,
    this.showLabels = true,
  });

  final List<WeightLog> logs;
  final double height;
  final double lineWidth;
  final double markerRadius;
  final double lastMarkerRadius;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (logs.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('لا توجد قياسات كافية بعد', style: AppText.metaSmall),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _WeightChartPainter(
              logs: logs,
              lineWidth: lineWidth,
              markerRadius: markerRadius,
              lastMarkerRadius: lastMarkerRadius,
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 6),
          _DateAxis(logs: logs),
        ],
      ],
    );
  }
}

/// Four evenly spaced date labels, oldest on the left to match the chart.
class _DateAxis extends StatelessWidget {
  const _DateAxis({required this.logs});

  final List<WeightLog> logs;

  @override
  Widget build(BuildContext context) {
    final first = logs.first.date;
    final last = logs.last.date;
    final span = last.difference(first).inMilliseconds;

    final labels = List.generate(4, (i) {
      final date = span == 0
          ? first
          : first.add(Duration(milliseconds: (span * i / 3).round()));
      // Only the endpoints carry the month, exactly as in the design.
      return (i == 0 || i == 3)
          ? ArabicDates.dayMonth(date)
          : fmtInt(date.day);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final label in labels) Text(label, style: AppText.metaTiny)],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.logs,
    required this.lineWidth,
    required this.markerRadius,
    required this.lastMarkerRadius,
  });

  final List<WeightLog> logs;
  final double lineWidth;
  final double markerRadius;
  final double lastMarkerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Three grid lines across the upper two-thirds, as in the mockup.
    final gridPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 5.4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final values = logs.map((l) => l.weightKg).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    // A flat series still needs a range, or every point lands on one line.
    final range = (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    final inset = lastMarkerRadius + 6;
    final top = lineWidth;
    final bottom = size.height * 0.78;

    final points = <Offset>[];
    for (var i = 0; i < logs.length; i++) {
      final x = inset + (size.width - inset * 2) * i / (logs.length - 1);
      final y = top + (bottom - top) * (maxValue - values[i]) / range;
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x425F7D5A), Color(0x005F7D5A)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.sage,
    );

    // Ring markers for every reading; the latest is filled and larger.
    for (final point in points.take(points.length - 1)) {
      canvas
        ..drawCircle(point, markerRadius, Paint()..color = AppColors.card)
        ..drawCircle(
          point,
          markerRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineWidth * 0.875
            ..color = AppColors.sage,
        );
    }
    canvas.drawCircle(points.last, lastMarkerRadius, Paint()..color = AppColors.sage);
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) => old.logs != logs;
}
