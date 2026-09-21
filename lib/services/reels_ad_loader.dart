import 'dart:async';
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
  _NativeReelsAd(this.ad);
  @override
  Widget view() => AdWidget(ad: ad);
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
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
        result.complete(handle);
      },
      onAdFailedToLoad: (_, __) => fail(),
    ),
  );
  handle = _NativeReelsAd(ad);
  final timeout = Timer(const Duration(seconds: 12), fail);
  try {
    unawaited(ad.load().catchError((Object _) { fail(); }));
    return await result.future;
  } finally {
    timeout.cancel();
  }
}
