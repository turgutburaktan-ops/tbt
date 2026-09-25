import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Kept injectable so consent failures and concurrent requests can be tested.
abstract class AdConsentGateway {
  Future<void> update();
  Future<void> gather();
  Future<bool> canRequest();
  Future<bool> privacyRequired();
  Future<void> showOptions();
  Future<void> initializeAds();
}

class _GoogleConsentGateway implements AdConsentGateway {
  @override
  Future<void> update() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => done.complete(),
      (error) => done.completeError(error),
    );
    return done.future.timeout(const Duration(seconds: 15));
  }

  Future<void> _form(void Function(void Function(FormError?)) present) {
    final done = Completer<void>();
    present((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(error);
      }
    });
    // Never time out an open form while the user is making a choice.
    return done.future;
  }

  @override
  Future<void> gather() => _form(ConsentForm.loadAndShowConsentFormIfRequired);
  @override
  Future<void> showOptions() => _form(ConsentForm.showPrivacyOptionsForm);
  @override
  Future<bool> canRequest() => ConsentInformation.instance.canRequestAds();
  @override
  Future<bool> privacyRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;
  @override
  Future<void> initializeAds() async {
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 8));
  }
}

class AdConsentService extends ChangeNotifier {
  AdConsentService({required AdConsentGateway gateway, this.supported = true})
      : _gateway = gateway;

  static final instance = AdConsentService(
    gateway: _GoogleConsentGateway(),
    supported: !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS),
  );

  final AdConsentGateway _gateway;
  final bool supported;
  final _ready = Completer<void>();
  Future<void>? _initializing;
  bool _sdkReady = false;
  bool canRequestAds = false;
  bool privacyOptionsRequired = false;
  bool showingOptions = false;
  int generation = 0;

  /// Bootstrap calls this after ATT; placements only wait, never open a form.
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      if (!supported) return;
      try {
        await _gateway.update();
        await _gateway.gather();
      } catch (error) {
        if (kDebugMode) debugPrint('Ad consent update: $error');
        // UMP alone decides whether a previous valid choice permits ads.
      }
      await _refresh();
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<bool> waitUntilReady() async {
    if (!supported) return false;
    await _ready.future;
    return canRequestAds;
  }

  Future<void> _refresh() async {
    canRequestAds = false;
    try {
      privacyOptionsRequired = await _gateway.privacyRequired();
      if (await _gateway.canRequest()) {
        if (!_sdkReady) {
          await _gateway.initializeAds();
          _sdkReady = true;
        }
        canRequestAds = true;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Ad consent status: $error');
    }
    notifyListeners();
  }

  Future<bool> showPrivacyOptions() async {
    await waitUntilReady();
    if (!privacyOptionsRequired || showingOptions) return false;
    showingOptions = true;
    canRequestAds = false;
    generation++;
    notifyListeners(); // Dispose ads obtained under the previous choice.
    bool success = true;
    try {
      await _gateway.showOptions();
    } catch (error) {
      success = false;
      if (kDebugMode) debugPrint('Ad privacy options: $error');
    } finally {
      showingOptions = false;
      await _refresh();
    }
    return success;
  }
}
