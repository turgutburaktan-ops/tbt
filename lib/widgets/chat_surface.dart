import 'package:flutter/material.dart';

/// Shared by the inbox and conversations, without affecting the rest of TBT.
class ChatSurface extends StatelessWidget {
  const ChatSurface({super.key, required this.child});
  final Widget child;
  static const background = Color(0xFF191519);
  static const panel = Color(0xFF241E23);
  static const accent = Color(0xFFF3B29B);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: accent, onPrimary: background,
          secondary: accent, onSecondary: background,
          primaryContainer: const Color(0xFF50383E),
          onPrimaryContainer: const Color(0xFFFFE8DE),
          surface: panel, onSurface: const Color(0xFFF8EFE9),
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: background, surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFF8EFE9)),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true, fillColor: panel,
          prefixIconColor: accent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: accent)),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: panel, selectedColor: const Color(0xFF50383E),
          side: BorderSide.none, shape: const StadiumBorder(),
          labelStyle: const TextStyle(color: Color(0xFFF8EFE9)),
        ),
      ),
      child: child,
    );
  }
}

class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF302329), ChatSurface.background, Color(0xFF24201C)],
    )),
    child: CustomPaint(painter: _ChatPattern(), child: child),
  );
}

class _ChatPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ChatSurface.accent.withValues(alpha: .055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = 28; y < size.height; y += 116) {
      for (double x = 24; x < size.width; x += 112) {
        final dx = x + ((y ~/ 116).isOdd ? 42 : 0);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx, y, 25, 18), const Radius.circular(7)), paint);
        canvas.drawLine(Offset(dx + 7, y + 18), Offset(dx + 4, y + 23), paint);
        canvas.drawCircle(Offset(dx + 57, y + 55), 10, paint);
        canvas.drawLine(Offset(dx + 53, y + 55), Offset(dx + 61, y + 55), paint);
        canvas.drawLine(Offset(dx + 57, y + 51), Offset(dx + 57, y + 59), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _ChatPattern oldDelegate) => false;
}
