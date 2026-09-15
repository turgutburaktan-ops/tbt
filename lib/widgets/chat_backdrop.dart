import 'package:flutter/material.dart';

/// A static travel pattern painted behind content; it never handles gestures.
class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color ?? Theme.of(context).scaffoldBackgroundColor,
    child: CustomPaint(painter: const ChatTravelPatternPainter(), child: child),
  );
}

class ChatTravelPatternPainter extends CustomPainter {
  const ChatTravelPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x249FC7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double y = -20; y < size.height; y += 164) {
      for (double x = -30; x < size.width; x += 184) {
        canvas.save();
        canvas.translate(x, y);
        // Mountain outline and snow cap.
        canvas.drawPath(
          Path()
            ..moveTo(18, 67)
            ..lineTo(44, 28)
            ..lineTo(72, 67)
            ..lineTo(18, 67)
            ..moveTo(34, 44)
            ..lineTo(43, 48)
            ..lineTo(50, 38),
          line,
        );
        // Map pin.
        canvas.drawPath(
          Path()
            ..moveTo(131, 96)
            ..cubicTo(123, 85, 116, 78, 116, 68)
            ..cubicTo(116, 49, 146, 49, 146, 68)
            ..cubicTo(146, 78, 139, 85, 131, 96),
          line,
        );
        canvas.drawCircle(const Offset(131, 68), 5, line);
        // Compass and a short winding trail.
        canvas.drawCircle(const Offset(55, 126), 15, line);
        canvas.drawPath(
          Path()
            ..moveTo(61, 116)
            ..lineTo(58, 129)
            ..lineTo(49, 136)
            ..lineTo(52, 123)
            ..close(),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(88, 119)
            ..quadraticBezierTo(111, 109, 114, 124)
            ..quadraticBezierTo(116, 140, 145, 132),
          line,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChatTravelPatternPainter oldDelegate) => false;
}
