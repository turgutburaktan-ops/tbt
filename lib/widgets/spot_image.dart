import 'package:flutter/material.dart';

import '../data/spot_image_registry.dart';
import '../models/photo_spot.dart';

class SpotImage extends StatelessWidget {
  final PhotoSpot spot;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SpotImage({
    super.key,
    required this.spot,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final local = spotImageRegistry[spot.id];
    Widget child;

    if (local != null && local.assetPath.trim().isNotEmpty) {
      child = Image.asset(
        local.assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _networkOrFallback(),
      );
    } else {
      child = _networkOrFallback();
    }

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _networkOrFallback() {
    if (spot.imageUrl.trim().isNotEmpty) {
      return Image.network(
        spot.imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: const Color(0xFF222831),
        alignment: Alignment.center,
        child: const Icon(
          Icons.photo_camera_back_outlined,
          color: Colors.white38,
        ),
      );
}
