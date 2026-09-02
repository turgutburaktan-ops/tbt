import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/spot_image_auto_registry.dart';
import '../data/spot_image_registry.dart';
import '../data/verified_travel_image_registry.dart';
import '../data/verified_travel_image_registry_batch2.dart';
import '../data/verified_travel_image_registry_batch3.dart';
import '../data/verified_travel_image_registry_batch4.dart';
import '../data/verified_travel_image_registry_batch5.dart';
import '../data/verified_travel_image_registry_batch6.dart';
import '../data/verified_travel_image_registry_batch7.dart';
import '../data/verified_travel_image_registry_batch8.dart';
import '../data/verified_travel_image_registry_batch9.dart';
import '../data/verified_travel_image_registry_batch10.dart';
import '../data/verified_travel_image_registry_batch11.dart';
import '../data/verified_travel_image_registry_batch12.dart';
import '../data/verified_travel_image_registry_generated.dart';
import '../models/photo_spot.dart';
import '../services/spot_image_search_service.dart';

class SpotImage extends StatelessWidget {
  // These automatic matches pointed to a different city or a different
  // landmark. A neutral placeholder is safer than showing a misleading photo.
  static const _suppressedAutomaticMatches = <String>{
    'elazig-agin-tarihi-evleri',
    'elazig-bakircilar-carsisi-complete',
    'elazig-meryem-ana-kilisesi',
    'elazig-palu-tas-koprusu',
    'elz-agin',
    'elz-bakircilar',
    'elz-eski-hukumet',
    'elz-kapalicarsi',
    'elz-meryem-ana',
    'elz-palu-kilise',
  };
  final PhotoSpot spot;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool highResolution;

  const SpotImage({
    super.key,
    required this.spot,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.highResolution = false,
  });

  @override
  Widget build(BuildContext context) {
    if (_suppressedAutomaticMatches.contains(spot.id)) {
      return borderRadius == null
          ? _fallback()
          : ClipRRect(borderRadius: borderRadius!, child: _fallback());
    }
    final verified =
        verifiedTravelImageRegistryGenerated[spot.id] ??
        verifiedTravelImageRegistryBatch12[spot.id] ??
        verifiedTravelImageRegistryBatch11[spot.id] ??
        verifiedTravelImageRegistryBatch10[spot.id] ??
        verifiedTravelImageRegistryBatch9[spot.id] ??
        verifiedTravelImageRegistryBatch8[spot.id] ??
        verifiedTravelImageRegistryBatch7[spot.id] ??
        verifiedTravelImageRegistryBatch6[spot.id] ??
        verifiedTravelImageRegistryBatch5[spot.id] ??
        verifiedTravelImageRegistryBatch4[spot.id] ??
        verifiedTravelImageRegistryBatch3[spot.id] ??
        verifiedTravelImageRegistryBatch2[spot.id] ??
        verifiedTravelImageRegistry[spot.id] ??
        spotImageRegistry[spot.id] ??
        spotImageAutoRegistry[spot.id];
    final previewAsset = _previewAssetPath(verified?.assetPath ?? '');
    final hasVerifiedAsset = previewAsset.isNotEmpty;
    final hasVerifiedUrl =
        verified != null && verified.networkUrl.trim().isNotEmpty;
    final hasLegacyUrl = spot.imageUrl.trim().isNotEmpty;

    Widget child;
    if (highResolution && (hasVerifiedUrl || hasLegacyUrl)) {
      child = _networkOrSearch(
        verified,
        preview: false,
        placeholderAsset: previewAsset,
      );
    } else if (hasVerifiedAsset) {
      child = Image.asset(
        previewAsset,
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

  Widget _networkOrSearch(
    SpotImageInfo? verified, {
    bool preview = true,
    String placeholderAsset = '',
  }) {
    final verifiedUrl = verified?.networkUrl.trim() ?? '';
    if (verifiedUrl.isNotEmpty) {
      return _cachedImage(
        preview ? _previewUrl(verifiedUrl) : verifiedUrl,
        placeholderAsset: placeholderAsset,
        onError: () => _legacyOrSearch(preview: preview),
      );
    }
    return _legacyOrSearch(preview: preview);
  }

  Widget _cachedImage(
    String url, {
    required Widget Function() onError,
    String placeholderAsset = '',
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: _httpHeaders(url),
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) {
        if (placeholderAsset.isNotEmpty) {
          return Image.asset(
            placeholderAsset,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _loadingPlaceholder(),
          );
        }
        return _loadingPlaceholder();
      },
      errorWidget: (_, __, ___) => onError(),
    );
  }

  Widget _loadingPlaceholder() => Container(
    width: width,
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20252B), Color(0xFF121519)],
      ),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.landscape_outlined, color: Colors.white24, size: 24),
  );

  Widget _legacyOrSearch({bool preview = true}) {
    if (spot.imageUrl.trim().isNotEmpty) {
      final url = preview ? _previewUrl(spot.imageUrl) : spot.imageUrl;
      return _cachedImage(url, onError: _searchedImage);
    }
    return _searchedImage();
  }

  String _previewAssetPath(String sourcePath) {
    final trimmed = sourcePath.trim();
    if (trimmed.isEmpty) return '';
    // Verified registry entries already point at the bundled, audited image.
    // Rewriting them to generated webp paths left new places without photos.
    return trimmed;
  }

  String _previewUrl(String sourceUrl) {
    return sourceUrl
        .replaceFirst(RegExp(r'/(3840|2560|1920|1280|1000|960)px-'), '/500px-')
        .replaceFirst(
          RegExp(r'([?&])width=(3840|2560|1920|1280|1000|960)'),
          r'$1width=500',
        );
  }

  Map<String, String>? _httpHeaders(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (!host.endsWith('wikimedia.org') && !host.endsWith('wikipedia.org')) {
      return null;
    }
    return const <String, String>{
      'User-Agent': 'BestPhotoSpot/1.0 (contact: turgutburaktan@gmail.com)',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
  }

  Widget _searchedImage() => FutureBuilder<String?>(
    future: SpotImageSearchService.instance.findImage(spot),
    builder: (context, snapshot) {
      final url = snapshot.data?.trim() ?? '';
      if (url.isNotEmpty) {
        return _cachedImage(
          highResolution ? url : _previewUrl(url),
          onError: () {
            SpotImageSearchService.instance.invalidate(spot, url);
            return _fallback();
          },
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _loadingPlaceholder();
      }
      return _fallback();
    },
  );

  Widget _fallback() => Container(
    width: width,
    height: height,
    color: const Color(0xFF1A1D20),
    alignment: Alignment.center,
    child: const Icon(Icons.photo_camera_back_outlined, color: Colors.white38),
  );
}
