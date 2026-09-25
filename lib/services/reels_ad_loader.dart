import 'dart:async';
import 'ad_consent_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class ReelsAdHandle {
  Widget view();
  void dispose();
}

typedef ReelsAdLoader = Future<ReelsAdHandle?> Function();

class _NativeReelsAd implements ReelsAdHandle {
  final NativeAd ad;
  bool _disposed = false;
  final int generation;
  _NativeReelsAd(this.ad, this.generation) {
    AdConsentService.instance.addListener(_consentChanged);
  }
  void _consentChanged() {
    if (!AdConsentService.instance.canRequestAds ||
        generation != AdConsentService.instance.generation) dispose();
  }
  @override
  Widget view() => AnimatedBuilder(
    animation: AdConsentService.instance,
    builder: (_, __) => _disposed ? const SizedBox.shrink() : AdWidget(ad: ad),
  );
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    AdConsentService.instance.removeListener(_consentChanged);
    unawaited(ad.dispose().catchError((Object _) {}));
  }
}

/// One bounded request. A late SDK callback cannot resurrect a timed-out ad.
Future<ReelsAdHandle?> loadReelsAd() async {
  if (kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) return null;
  final android = defaultTargetPlatform == TargetPlatform.android;
  final id = kDebugMode
      ? (android ? 'ca-app-pub-3940256099942544/1044960115' : 'ca-app-pub-3940256099942544/2521693316')
      : (android
          ? const String.fromEnvironment('ADMOB_NATIVE_ANDROID')
          : const String.fromEnvironment('ADMOB_NATIVE_IOS'));
  if (id.isEmpty) return null;
  if (!await AdConsentService.instance.waitUntilReady()) return null;
  final generation = AdConsentService.instance.generation;
  final result = Completer<ReelsAdHandle?>();
  late final _NativeReelsAd handle;
  void fail() {
    handle.dispose();
    if (!result.isCompleted) result.complete(null);
  }
  final ad = NativeAd(
    adUnitId: id,
    factoryId: 'tbtReels',
    request: const AdRequest(),
    nativeAdOptions: NativeAdOptions(
      mediaAspectRatio: MediaAspectRatio.portrait,
      adChoicesPlacement: AdChoicesPlacement.topRightCorner,
      videoOptions: VideoOptions(startMuted: true, customControlsRequested: false),
    ),
    listener: NativeAdListener(
      onAdLoaded: (_) {
        if (result.isCompleted) { handle.dispose(); return; }
        if (!AdConsentService.instance.canRequestAds ||
            generation != AdConsentService.instance.generation) { fail(); return; }
        result.complete(handle);
      },
      onAdFailedToLoad: (_, __) => fail(),
    ),
  );
  handle = _NativeReelsAd(ad, generation);
  final timeout = Timer(const Duration(seconds: 12), fail);
  try {
    unawaited(ad.load().catchError((Object _) { fail(); }));
    return await result.future;
  } finally {
    timeout.cancel();
  }
}
