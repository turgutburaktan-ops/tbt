import '../theme/app_theme.dart';
import 'dart:io';
import 'dart:async';
import '../services/ad_consent_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A clearly labelled, in-flow Google native ad. It deliberately does not
/// support app-open, interstitial or rewarded placements.
class SponsoredNativeAd extends StatefulWidget {
  final EdgeInsetsGeometry margin;
  final bool compact;
  const SponsoredNativeAd({
    super.key,
    this.compact = false,
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
    AdConsentService.instance.addListener(_consentChanged);
    unawaited(_load());
  }

  void _consentChanged() {
    if (!AdConsentService.instance.canRequestAds) {
      final previous = _ad;
      _ad = null;
      if (mounted) setState(() => _loaded = false);
      previous?.dispose();
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS) || _unitId.isEmpty) return;
    if (!await AdConsentService.instance.waitUntilReady() || !mounted || _ad != null) return;
    final generation = AdConsentService.instance.generation;
    {
      final ad = NativeAd(
        adUnitId: _unitId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted || !identical(_ad, ad) ||
                !AdConsentService.instance.canRequestAds ||
                generation != AdConsentService.instance.generation) {
              ad.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted && identical(_ad, ad)) {
              setState(() { _ad = null; _loaded = false; });
            }
          },
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: widget.compact ? TemplateType.small : TemplateType.medium,
          mainBackgroundColor: AppColors.surface,
          cornerRadius: 18,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.black,
            backgroundColor: const Color(0xFF55E0D2),
            style: NativeTemplateFontStyle.bold,
            size: 14,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: AppColors.surface,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white70,
            backgroundColor: AppColors.surface,
            style: NativeTemplateFontStyle.normal,
            size: 12,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white60,
            backgroundColor: AppColors.surface,
            style: NativeTemplateFontStyle.normal,
            size: 11,
          ),
        ),
      );
      _ad = ad;
      try {
        await ad.load();
      } catch (_) {
        ad.dispose();
        if (mounted && identical(_ad, ad)) {
          setState(() { _ad = null; _loaded = false; });
        }
      }
    }
  }

  @override
  void dispose() {
    AdConsentService.instance.removeListener(_consentChanged);
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
          color: AppColors.surface,
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
            SizedBox(
              height: widget.compact ? 120 : 290,
              width: double.infinity,
              child: AdWidget(ad: _ad!),
            ),
          ],
        ),
      ),
    );
  }
}
