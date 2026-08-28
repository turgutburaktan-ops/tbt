import 'dart:math' as math;

import 'package:flutter/material.dart';

class TbtBrandMark extends StatelessWidget {
  final double size;
  final bool roundedBackground;

  const TbtBrandMark({
    super.key,
    this.size = 34,
    this.roundedBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _TbtBrandPainter(),
    );
    if (!roundedBackground) return mark;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .10),
      decoration: BoxDecoration(
        color: const Color(0xFF080A12),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: const Color(0x2628D9F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F7A42FF),
            blurRadius: 12,
            spreadRadius: -3,
          ),
        ],
      ),
      child: CustomPaint(painter: _TbtBrandPainter()),
    );
  }
}

class _TbtBrandPainter extends CustomPainter {
  static const _cyan = Color(0xFF11D7ED);
  static const _blue = Color(0xFF2D8CFF);
  static const _violet = Color(0xFF8C35FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final center = Offset(size.width * .50, size.height * .40);
    final radius = s * .34;
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final gradient = const SweepGradient(
      startAngle: -math.pi * .8,
      endAngle: math.pi * 1.2,
      colors: [_cyan, _blue, _violet, _cyan],
    ).createShader(ringRect);

    final blade = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .105
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final start = -math.pi * .92 + i * (math.pi * 2 / 6);
      canvas.drawArc(
        ringRect,
        start,
        math.pi * .23,
        false,
        blade,
      );
    }

    final eyePaint = Paint()..shader = gradient;
    canvas.drawCircle(center, s * .055, eyePaint);

    final road = Path()
      ..moveTo(center.dx - s * .08, center.dy + s * .23)
      ..cubicTo(
        center.dx - s * .26,
        center.dy + s * .37,
        center.dx + s * .18,
        center.dy + s * .42,
        center.dx + s * .02,
        center.dy + s * .62,
      )
      ..cubicTo(
        center.dx - s * .07,
        center.dy + s * .73,
        center.dx - s * .19,
        center.dy + s * .75,
        center.dx - s * .25,
        center.dy + s * .80,
      );
    final roadPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_violet, _blue, _cyan],
      ).createShader(Rect.fromLTWH(0, center.dy, s, s * .65))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .17
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(road, roadPaint);

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .027
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - s * .015, center.dy + s * .42),
      Offset(center.dx + s * .035, center.dy + s * .45),
      dashPaint,
    );
    canvas.drawLine(
      Offset(center.dx + s * .045, center.dy + s * .50),
      Offset(center.dx + s * .03, center.dy + s * .55),
      dashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TbtBrandPainter oldDelegate) => false;
}
