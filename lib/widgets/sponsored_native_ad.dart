import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A clearly labelled, in-flow Google native ad. It deliberately does not
/// support app-open, interstitial or rewarded placements.
class SponsoredNativeAd extends StatefulWidget {
  final EdgeInsetsGeometry margin;
  const SponsoredNativeAd({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  State<SponsoredNativeAd> createState() => _SponsoredNativeAdState();
}

class _SponsoredNativeAdState extends State<SponsoredNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;

  String get _unitId {
    const androidProduction = String.fromEnvironment('ADMOB_NATIVE_ANDROID');
    const iosProduction = String.fromEnvironment('ADMOB_NATIVE_IOS');
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-3940256099942544/3986624511';
    }
    return Platform.isAndroid ? androidProduction : iosProduction;
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && _unitId.isNotEmpty) {
      final ad = NativeAd(
        adUnitId: _unitId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) setState(() => _loaded = false);
          },
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: const Color(0xFF12161B),
          cornerRadius: 18,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.black,
            backgroundColor: const Color(0xFF55E0D2),
            style: NativeTemplateFontStyle.bold,
            size: 14,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: const Color(0xFF12161B),
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white70,
            backgroundColor: const Color(0xFF12161B),
            style: NativeTemplateFontStyle.normal,
            size: 12,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white60,
            backgroundColor: const Color(0xFF12161B),
            style: NativeTemplateFontStyle.normal,
            size: 11,
          ),
        ),
      );
      _ad = ad;
      ad.load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Sponsorlu içerik',
      child: Container(
        margin: widget.margin,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF12161B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x3355E0D2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(13, 9, 13, 2),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, size: 15, color: Color(0xFF55E0D2)),
                  SizedBox(width: 6),
                  Text('Sponsorlu', style: TextStyle(color: Color(0xFF55E0D2), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .3)),
                ],
              ),
            ),
            SizedBox(height: 290, child: AdWidget(ad: _ad!)),
          ],
        ),
      ),
    );
  }
}
