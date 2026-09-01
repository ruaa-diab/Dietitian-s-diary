import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A stroke-based icon drawn on a 24×24 grid, matching the custom line
/// icons in the design (≈2–2.4px stroke, round caps and joins) rather
/// than Material's filled set.
@immutable
class LineIconData {
  const LineIconData(this.draw, {this.strokeWidth = 2, this.grid = 24});

  /// Adds the icon's strokes to [path], in [grid]-unit coordinates.
  final void Function(Path path) draw;
  final double strokeWidth;
  final double grid;
}

class LineIcon extends StatelessWidget {
  const LineIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth,
  });

  final LineIconData icon;
  final Color color;
  final double size;

  /// Overrides the icon's own stroke width, in grid units.
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LineIconPainter(
          icon: icon,
          color: color,
          strokeWidth: strokeWidth ?? icon.strokeWidth,
        ),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter({required this.icon, required this.color, required this.strokeWidth});

  final LineIconData icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / icon.grid;
    final path = Path();
    icon.draw(path);

    canvas
      ..save()
      ..scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

/// The icon set used across the app, transcribed from the design's SVGs.
abstract final class AppIcons {
  /// Bottom nav — اليوم.
  static final calendar = LineIconData((p) {
    p.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 5, 18, 16),
      const Radius.circular(4),
    ));
    p
      ..moveTo(8, 3)
      ..lineTo(8, 7)
      ..moveTo(16, 3)
      ..lineTo(16, 7)
      ..moveTo(3, 11)
      ..lineTo(21, 11);
  });

  /// Bottom nav — العميلات.
  static final person = LineIconData((p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 3.6));
    p
      ..moveTo(5, 20)
      ..cubicTo(5, 16.4, 8.1, 14.4, 12, 14.4)
      ..cubicTo(15.9, 14.4, 19, 16.4, 19, 20);
  });

  /// Bottom nav — الملخص.
  static final bars = LineIconData((p) {
    p
      ..moveTo(5, 19)
      ..lineTo(5, 11)
      ..moveTo(12, 19)
      ..lineTo(12, 5)
      ..moveTo(19, 19)
      ..lineTo(19, 13);
  });

  /// Bottom nav — باقة جديدة, and the "new client" CTA.
  static final plus = LineIconData((p) {
    p
      ..moveTo(12, 5)
      ..lineTo(12, 19)
      ..moveTo(5, 12)
      ..lineTo(19, 12);
  }, strokeWidth: 2.4);

  static final check = LineIconData((p) {
    p
      ..moveTo(20, 6)
      ..lineTo(9, 17)
      ..lineTo(4, 12);
  }, strokeWidth: 3);

  static final close = LineIconData((p) {
    p
      ..moveTo(18, 6)
      ..lineTo(6, 18)
      ..moveTo(6, 6)
      ..lineTo(18, 18);
  }, strokeWidth: 2.6);

  static final search = LineIconData((p) {
    p.addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 7));
    p
      ..moveTo(16.5, 16.5)
      ..lineTo(21, 21);
  }, strokeWidth: 2.2);

  /// Back chevron. Points right, which is "back" in an RTL layout.
  static final chevron = LineIconData((p) {
    p
      ..moveTo(9, 6)
      ..lineTo(15, 12)
      ..lineTo(9, 18);
  }, strokeWidth: 2.2);

  /// Overflow menu.
  static final more = LineIconData((p) {
    for (final y in const [5.0, 12.0, 19.0]) {
      p.addOval(Rect.fromCircle(center: Offset(12, y), radius: 1.4));
    }
  }, strokeWidth: 2.2);

  /// Money / balance-due.
  static final card = LineIconData((p) {
    p.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.5, 6, 19, 12),
      const Radius.circular(3),
    ));
    p
      ..moveTo(2.5, 10)
      ..lineTo(21.5, 10);
  });

  /// Trend arrow used by the weight delta and the revenue change.
  static final arrowUp = LineIconData((p) {
    p
      ..moveTo(12, 19)
      ..lineTo(12, 6)
      ..moveTo(6, 12)
      ..lineTo(12, 6)
      ..lineTo(18, 12);
  }, strokeWidth: 3);

  /// Renewal loop.
  static final refresh = LineIconData((p) {
    p
      ..moveTo(20, 12)
      ..arcToPoint(
        const Offset(17.7, 6.4),
        radius: const Radius.circular(8),
        largeArc: true,
        clockwise: false,
      );
    p
      ..moveTo(20, 4)
      ..lineTo(20, 8)
      ..lineTo(16, 8);
  });
}

/// The تَغذية brand mark — a stroked stem with two filled leaves. Drawn
/// directly because it mixes fills and strokes, unlike the line icons.
class BrandLeaf extends StatelessWidget {
  const BrandLeaf({
    super.key,
    this.size = 24,
    this.strokeColor = const Color(0xFFFFFFFF),
    this.leafColor = const Color(0xFFFFFFFF),
    this.underLeafColor = const Color(0xFFF3CFC9),
  });

  final double size;
  final Color strokeColor;
  final Color leafColor;
  final Color underLeafColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandLeafPainter(
          strokeColor: strokeColor,
          leafColor: leafColor,
          underLeafColor: underLeafColor,
        ),
      ),
    );
  }
}

class _BrandLeafPainter extends CustomPainter {
  _BrandLeafPainter({
    required this.strokeColor,
    required this.leafColor,
    required this.underLeafColor,
  });

  final Color strokeColor;
  final Color leafColor;
  final Color underLeafColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..scale(scale);

    final upperLeaf = Path()
      ..moveTo(12, 11)
      ..cubicTo(12, 6, 15, 3, 20, 2)
      ..cubicTo(20, 7, 17, 10, 12, 11)
      ..close();
    final lowerLeaf = Path()
      ..moveTo(12, 13)
      ..cubicTo(12, 9, 9.5, 6.5, 5.5, 5.5)
      ..cubicTo(5.5, 9.5, 8, 12, 12, 13)
      ..close();

    canvas
      ..drawPath(upperLeaf, Paint()..color = leafColor)
      ..drawPath(lowerLeaf, Paint()..color = underLeafColor)
      ..drawLine(
        const Offset(12, 21),
        const Offset(12, 11),
        Paint()
          ..color = strokeColor
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BrandLeafPainter old) =>
      old.strokeColor != strokeColor ||
      old.leafColor != leafColor ||
      old.underLeafColor != underLeafColor;
}

/// The circular "package complete" illustration: a full progress ring
/// with a checkmark, on the celebration screen.
class CompletionRing extends StatelessWidget {
  const CompletionRing({super.key, this.size = 132, required this.progress});

  /// 0–1; the mockup shows a full ring at 1.
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CompletionRingPainter(progress)),
      );
}

class _CompletionRingPainter extends CustomPainter {
  _CompletionRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 132;
    canvas
      ..save()
      ..scale(scale);

    const center = Offset(66, 66);
    canvas
      ..drawCircle(center, 62, Paint()..color = const Color(0xFFEDF2E9))
      ..drawCircle(
        center,
        50,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = const Color(0xFFDCE6D5),
      )
      ..drawArc(
        Rect.fromCircle(center: center, radius: 50),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF5F7D5A),
      )
      ..drawPath(
        Path()
          ..moveTo(46, 67)
          ..lineTo(59, 80)
          ..lineTo(85, 53),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF5F7D5A),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_CompletionRingPainter old) => old.progress != progress;
}
