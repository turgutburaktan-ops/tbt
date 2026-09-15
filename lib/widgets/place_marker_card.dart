import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../theme/app_theme.dart';

/// Small, readable map labels; selected route stops keep their numbered icons.
class PlaceMarkerCard {
  static const width = 156.0;
  static const height = 68.0;

  static String cacheKey(PhotoSpot spot) =>
      '${spot.name}\u0000${spot.category}\u0000${spot.rating}';

  static Future<BitmapDescriptor> render(PhotoSpot spot) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, width - 2, height - 10),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.cyan, AppColors.violet],
        ).createShader(body.outerRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final tip = Path()
      ..moveTo(width / 2 - 5, height - 10)
      ..lineTo(width / 2, height - 2)
      ..lineTo(width / 2 + 5, height - 10)
      ..close();
    canvas.drawPath(tip, Paint()..color = AppColors.violet);
    final name = TextPainter(
      text: TextSpan(
        text: spot.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - 20);
    name.paint(canvas, const Offset(10, 7));
    name.dispose();
    final hasRating = spot.rating.isFinite && spot.rating > 0;
    final category = TextPainter(
      text: TextSpan(
        text: spot.category,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: hasRating ? width - 68 : width - 20);
    category.paint(canvas, const Offset(10, 41));
    category.dispose();
    if (hasRating) {
      final rating = TextPainter(
        text: TextSpan(
          text: '★ ${spot.rating.toStringAsFixed(1).replaceAll('.', ',')}',
          style: const TextStyle(
            color: AppColors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rating.paint(canvas, Offset(width - rating.width - 10, 40));
      rating.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * scale).round(),
      (height * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Map card image could not be rendered');
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }
}
