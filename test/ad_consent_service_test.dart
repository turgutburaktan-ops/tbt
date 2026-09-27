import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/ad_consent_service.dart';

class FakeConsent implements AdConsentGateway {
  bool allowed = false;
  bool required = true;
  bool updateFails = false;
  bool sdkFails = false;
  bool formFails = false;
  int updates = 0;
  int sdkStarts = 0;
  int forms = 0;
  Completer<void>? updateGate;
  Completer<void>? optionsGate;
  @override
  Future<void> update() async {
    updates++;
    if (updateFails) throw StateError('offline');
    await updateGate?.future;
  }
  @override
  Future<void> gather() async {
    if (formFails) throw StateError('form unavailable');
  }
  @override
  Future<bool> canRequest() async => allowed;
  @override
  Future<bool> privacyRequired() async => required;
  @override
  Future<void> showOptions() async {
    forms++;
    await optionsGate?.future;
  }
  @override
  Future<void> initializeAds() async {
    sdkStarts++;
    if (sdkFails) throw StateError('SDK unavailable');
  }
}

void main() {
  test('first-launch ads wait for UMP; concurrent initialization runs once', () async {
    final gateway = FakeConsent()..allowed = true..updateGate = Completer<void>();
    final service = AdConsentService(gateway: gateway);
    bool placementReady = false;
    final placement = service.waitUntilReady().then((ok) => placementReady = ok);
    final a = service.initialize();
    final b = service.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(placementReady, false);
    expect(gateway.sdkStarts, 0);
    gateway.updateGate!.complete();
    await Future.wait([a, b, placement]);
    expect(placementReady, true);
    expect(gateway.updates, 1);
    expect(gateway.sdkStarts, 1);
  });

  test('UMP denial never initializes the ad SDK', () async {
    final gateway = FakeConsent();
    final service = AdConsentService(gateway: gateway);
    await service.initialize();
    expect(await service.waitUntilReady(), false);
    expect(gateway.sdkStarts, 0);
    expect(service.privacyOptionsRequired, true);
  });

  test('offline first launch fails closed, but UMP can authorize cached consent', () async {
    for (final cached in [false, true]) {
      final gateway = FakeConsent()..updateFails = true..allowed = cached;
      final service = AdConsentService(gateway: gateway);
      await service.initialize();
      expect(await service.waitUntilReady(), cached);
      expect(gateway.sdkStarts, cached ? 1 : 0);
    }
  });

  test('privacy changes invalidate old ads and cannot open duplicate forms', () async {
    final gateway = FakeConsent()..allowed = true..optionsGate = Completer<void>();
    final service = AdConsentService(gateway: gateway);
    await service.initialize();
    final states = <bool>[];
    service.addListener(() => states.add(service.canRequestAds));
    final form = service.showPrivacyOptions();
    await Future<void>.delayed(Duration.zero);
    expect(service.canRequestAds, false);
    expect(service.generation, 1);
    expect(await service.showPrivacyOptions(), false);
    expect(gateway.forms, 1);
    gateway.allowed = false;
    gateway.optionsGate!.complete();
    expect(await form, true);
    expect(service.canRequestAds, false);
    expect(states, [false, false]);
  });

  test('a new allowed choice resumes ads without initializing the SDK twice', () async {
    final gateway = FakeConsent()..allowed = true;
    final service = AdConsentService(gateway: gateway);
    await service.initialize();
    expect(await service.showPrivacyOptions(), true);
    expect(service.canRequestAds, true);
    expect(gateway.sdkStarts, 1);
  });

  test('form or SDK errors release waiters without allowing unsafe requests', () async {
    final formGateway = FakeConsent()..formFails = true;
    final formService = AdConsentService(gateway: formGateway);
    await formService.initialize();
    expect(await formService.waitUntilReady(), false);
    final sdkGateway = FakeConsent()..allowed = true..sdkFails = true;
    final sdkService = AdConsentService(gateway: sdkGateway);
    await sdkService.initialize();
    expect(await sdkService.waitUntilReady(), false);
  });

  test('unsupported platforms never invoke mobile consent APIs', () async {
    final gateway = FakeConsent()..allowed = true;
    final service = AdConsentService(gateway: gateway, supported: false);
    expect(await service.waitUntilReady(), false);
    await service.initialize();
    expect(gateway.updates, 0);
    expect(service.privacyOptionsRequired, false);
  });
}
