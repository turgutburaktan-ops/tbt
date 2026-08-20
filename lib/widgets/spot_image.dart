import 'package:flutter/material.dart';

import '../data/spot_image_auto_registry.dart';
import '../data/spot_image_registry.dart';
import '../data/verified_travel_image_registry.dart';
import '../data/verified_travel_image_registry_batch2.dart';
import '../data/verified_travel_image_registry_batch3.dart';
import '../data/verified_travel_image_registry_batch4.dart';
import '../data/verified_travel_image_registry_batch5.dart';
import '../models/photo_spot.dart';
import '../services/spot_image_search_service.dart';

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
    // Gezilecek yer çekirdeği için elle doğrulanan fotoğraf her şeyden önce
    // gelir. Ardından eski elle doğrulanmış kayıt, build kataloğu ve en son
    // arama fallback'i kullanılır. Böylece ikonik yerlerde yanlış görselin
    // otomatik aramadan içeri sızması engellenir.
    final verified = verifiedTravelImageRegistryBatch5[spot.id] ??
        verifiedTravelImageRegistryBatch4[spot.id] ??
        verifiedTravelImageRegistryBatch3[spot.id] ??
        verifiedTravelImageRegistryBatch2[spot.id] ??
        verifiedTravelImageRegistry[spot.id] ??
        spotImageRegistry[spot.id] ??
        spotImageAutoRegistry[spot.id];
    final hasVerifiedAsset =
        verified != null && verified.assetPath.trim().isNotEmpty;
    final hasVerifiedUrl =
        verified != null && verified.networkUrl.trim().isNotEmpty;
    final hasLegacyUrl = spot.imageUrl.trim().isNotEmpty;

    Widget child;
    if (hasVerifiedAsset) {
      child = Image.asset(
        verified.assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _networkOrSearch(verified),
      );
    } else if (hasVerifiedUrl || hasLegacyUrl) {
      child = _networkOrSearch(verified);
    } else {
      child = _searchedImage();
    }

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _networkOrSearch(SpotImageInfo? verified) {
    final verifiedUrl = verified?.networkUrl.trim() ?? '';
    if (verifiedUrl.isNotEmpty) {
      return Image.network(
        verifiedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _legacyOrSearch(),
      );
    }
    return _legacyOrSearch();
  }

  Widget _legacyOrSearch() {
    if (spot.imageUrl.trim().isNotEmpty) {
      return Image.network(
        spot.imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _searchedImage(),
      );
    }
    return _searchedImage();
  }

  Widget _searchedImage() => FutureBuilder<String?>(
        future: SpotImageSearchService.instance.findImage(spot),
        builder: (context, snapshot) {
          final url = snapshot.data?.trim() ?? '';
          if (url.isNotEmpty) {
            return Image.network(
              url,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) {
                SpotImageSearchService.instance.invalidate(spot, url);
                return _fallback();
              },
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: const Color(0xFF1A1D20),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB7BCC2),
                ),
              ),
            );
          }
          return _fallback();
        },
      );

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: const Color(0xFF1A1D20),
        alignment: Alignment.center,
        child: const Icon(
          Icons.photo_camera_back_outlined,
          color: Colors.white38,
        ),
      );
}
