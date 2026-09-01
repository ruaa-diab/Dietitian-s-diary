import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The leaf-and-plate illustration on the empty Today screen.
class NoVisitsIllustration extends StatelessWidget {
  const NoVisitsIllustration({super.key, this.width = 210, this.height = 180});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _NoVisitsPainter()),
      );
}

class _NoVisitsPainter extends CustomPainter {
  // Drawn on the 200×170 grid the design used.
  static const _grid = Size(200, 170);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / _grid.width).clamp(0.0, size.height / _grid.height);
    canvas
      ..save()
      ..translate(
        (size.width - _grid.width * scale) / 2,
        (size.height - _grid.height * scale) / 2,
      )
      ..scale(scale);

    canvas.drawCircle(
      const Offset(100, 78),
      58,
      Paint()..color = AppColors.sageBgAlt,
    );

    // Right leaf.
    canvas.drawPath(
      Path()
        ..moveTo(100, 96)
        ..cubicTo(100, 70, 116, 50, 140, 46)
        ..cubicTo(138, 72, 124, 90, 100, 96)
        ..close(),
      Paint()..color = AppColors.sage,
    );

    // Left leaf, a shade lighter.
    canvas.drawPath(
      Path()
        ..moveTo(100, 96)
        ..cubicTo(100, 74, 87, 58, 67, 54)
        ..cubicTo(68, 76, 80, 91, 100, 96)
        ..close(),
      Paint()..color = AppColors.sageMid,
    );

    canvas
      ..drawLine(
        const Offset(100, 122),
        const Offset(100, 70),
        Paint()
          ..color = AppColors.sageDark
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        const Offset(62, 138),
        const Offset(138, 138),
        Paint()
          ..color = AppColors.clay
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(const Offset(152, 34), 7, Paint()..color = AppColors.honey)
      ..drawCircle(const Offset(44, 46), 5, Paint()..color = AppColors.honey)
      ..restore();
  }

  @override
  bool shouldRepaint(_NoVisitsPainter oldDelegate) => false;
}

/// The contact-card illustration on the empty Clients screen.
class NoClientsIllustration extends StatelessWidget {
  const NoClientsIllustration({super.key, this.width = 210, this.height = 180});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _NoClientsPainter()),
      );
}

class _NoClientsPainter extends CustomPainter {
  static const _grid = Size(200, 170);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / _grid.width).clamp(0.0, size.height / _grid.height);
    canvas
      ..save()
      ..translate(
        (size.width - _grid.width * scale) / 2,
        (size.height - _grid.height * scale) / 2,
      )
      ..scale(scale);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 52, 132, 86),
          const Radius.circular(24),
        ),
        Paint()..color = AppColors.clayTint,
      )
      ..drawCircle(const Offset(78, 88), 17, Paint()..color = AppColors.clay)
      ..drawPath(
        Path()
          ..moveTo(56, 122)
          ..cubicTo(56, 109, 66, 102, 78, 102)
          ..cubicTo(90, 102, 100, 109, 100, 122)
          ..close(),
        Paint()..color = AppColors.clay,
      );

    final linePaint = Paint()
      ..color = const Color(0xFFDCA79F)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(116, 84), const Offset(146, 84), linePaint)
      ..drawLine(const Offset(116, 100), const Offset(138, 100), linePaint);

    final plusPaint = Paint()
      ..color = AppColors.card
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(const Offset(152, 46), 18, Paint()..color = AppColors.sage)
      ..drawLine(const Offset(152, 38), const Offset(152, 54), plusPaint)
      ..drawLine(const Offset(144, 46), const Offset(160, 46), plusPaint)
      ..drawCircle(const Offset(40, 36), 6, Paint()..color = AppColors.honey)
      ..restore();
  }

  @override
  bool shouldRepaint(_NoClientsPainter oldDelegate) => false;
}

/// Scattered confetti behind the celebration card — circles and rounded
/// bars in clay, sage and honey, at the positions from the design.
class ConfettiLayer extends StatelessWidget {
  const ConfettiLayer({super.key});

  static const _pieces = <({double top, double left, double w, double h, Color color, double turns})>[
    (top: 0.09, left: 0.14, w: 12, h: 12, color: AppColors.honey, turns: 0),
    (top: 0.15, left: 0.76, w: 9, h: 20, color: AppColors.clay, turns: 22 / 360),
    (top: 0.22, left: 0.34, w: 8, h: 8, color: AppColors.sage, turns: 0),
    (top: 0.07, left: 0.56, w: 8, h: 18, color: AppColors.honey, turns: -30 / 360),
    (top: 0.29, left: 0.88, w: 11, h: 11, color: AppColors.clay, turns: 0),
    (top: 0.74, left: 0.10, w: 9, h: 19, color: AppColors.sage, turns: 15 / 360),
    (top: 0.84, left: 0.66, w: 12, h: 12, color: AppColors.honey, turns: 0),
    (top: 0.91, left: 0.28, w: 8, h: 16, color: AppColors.clay, turns: -18 / 360),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            for (final piece in _pieces)
              Positioned(
                top: constraints.maxHeight * piece.top,
                // Positions are canvas coordinates, so they stay left-based
                // even though the app runs RTL.
                left: constraints.maxWidth * piece.left,
                child: RotationTransition(
                  turns: AlwaysStoppedAnimation(piece.turns),
                  child: Container(
                    width: piece.w,
                    height: piece.h,
                    decoration: BoxDecoration(
                      color: piece.color,
                      borderRadius: BorderRadius.circular(piece.w == piece.h ? 99 : 5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
