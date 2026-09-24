import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_update_policy.dart';

class StoreUpdateOffer {
  const StoreUpdateOffer({required this.id, required this.required, this.downloaded = false, this.ios = false});
  final String id;
  final bool required, downloaded, ios;
}

class AppUpdateService extends ChangeNotifier with WidgetsBindingObserver {
  StoreUpdateOffer? offer;
  bool busy = false;
  String? error;
  bool _checking = false, _disposed = false;
  DateTime? _checkedAt;
  AppUpdateInfo? _android;
  Timer? _startup;
  StreamSubscription<InstallStatus>? _downloads;
  static final _iosStore = Uri.parse('https://apps.apple.com/app/id6808182194');

  void start() {
    if (kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) return;
    WidgetsBinding.instance.addObserver(this);
    // Let startup, sign-in and permission UI settle first.
    _startup = Timer(const Duration(seconds: 12), () => unawaited(check()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      unawaited(check(force: offer != null || _android != null));
    }
  }

  void _emit() { if (!_disposed) notifyListeners(); }

  Future<Map<String, dynamic>> _policy() async {
    try {
      return (await FirebaseFirestore.instance.doc('app_config/update_policy')
        .get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 5))).data() ?? {};
    } catch (_) { return {}; }
  }

  Future<void> check({bool force = false}) async {
    if (_disposed || _checking || busy || kIsWeb) return;
    if (!force && _checkedAt != null && DateTime.now().difference(_checkedAt!) < const Duration(hours: 6)) return;
    _checking = true;
    try {
      final info = await PackageInfo.fromPlatform().timeout(const Duration(seconds: 8));
      if (_disposed) return;
      StoreUpdateOffer? next;
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Direct APK installs are intentionally outside this feature.
        if (info.installerStore != 'com.android.vending') return;
        final update = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 12));
        _android = update;
        if (update.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
        if (update.updateAvailability == UpdateAvailability.updateAvailable || update.installStatus == InstallStatus.downloaded) {
          final available = update.availableVersionCode;
          if (available == null || available <= (int.tryParse(info.buildNumber) ?? available)) return;
          if (!update.flexibleUpdateAllowed && !update.immediateUpdateAllowed && update.installStatus != InstallStatus.downloaded) return;
          final policy = await _policy();
          final minimum = policy['androidMinimumBuild'];
          next = StoreUpdateOffer(id: 'android-$available',
            required: requiresAndroidUpdate(int.parse(info.buildNumber), available, minimum is int ? minimum : 0),
            downloaded: update.installStatus == InstallStatus.downloaded);
          if (_disposed) return;
          _downloads ??= InAppUpdate.installUpdateListener.listen((status) {
            if (status == InstallStatus.downloaded && !_disposed && _android?.availableVersionCode != null) {
              offer = StoreUpdateOffer(id: 'android-${_android!.availableVersionCode}', required: offer?.required ?? false, downloaded: true);
              busy = false;
              _emit();
            }
          }, onError: (Object _) {});
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (info.installerStore != 'com.apple') return;
        final country = WidgetsBinding.instance.platformDispatcher.locale.countryCode?.toLowerCase() ?? 'tr';
        final response = await http.get(Uri.https('itunes.apple.com', '/lookup', {'id':'6808182194','country':country})).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return;
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'];
        if (results is! List || results.isEmpty) return;
        final app = results.first as Map<String, dynamic>;
        if (app['bundleId'] != info.packageName || app['trackId'] != 6808182194) return;
        final minimumOs = app['minimumOsVersion'];
        final deviceOs = RegExp(r'\d+(?:\.\d+)*').firstMatch(Platform.operatingSystemVersion)?.group(0);
        if (minimumOs is! String || deviceOs == null || (compareAppVersions(deviceOs, minimumOs) ?? -1) < 0) return;
        final version = app['version'];
        if (version is! String || compareAppVersions(version, info.version) != 1) return;
        final policy = await _policy();
        final minimum = policy['iosMinimumVersion'];
        next = StoreUpdateOffer(id:'ios-$version', ios:true,
          required: minimum is String && requiresIosUpdate(info.version,version,minimum));
      }
      _checkedAt = DateTime.now();
      if (next != null && !next.required) {
        final prefs = await SharedPreferences.getInstance();
        final postponed = prefs.getInt('update_later_${next.id}');
        if (postponed != null && DateTime.now().millisecondsSinceEpoch - postponed < const Duration(days:1).inMilliseconds) next = null;
      }
      if (_disposed) return;
      offer = next;
      error = null;
      _emit();
    } catch (_) {
      // Store/network failure must not block application startup.
      _checkedAt = DateTime.now();
    } finally { _checking = false; }
  }

  Future<void> postpone() async {
    final current = offer;
    if (current == null || current.required || busy) return;
    offer = null;
    _emit();
    try { await (await SharedPreferences.getInstance()).setInt('update_later_${current.id}',DateTime.now().millisecondsSinceEpoch); } catch (_) {}
  }

  Future<void> update() async {
    final current = offer;
    if (busy || current == null) return;
    busy = true; error = null; _emit();
    try {
      if (current.ios) {
        if (!await launchUrl(_iosStore, mode: LaunchMode.externalApplication)) throw StateError('Store unavailable');
        if (!current.required) {
          busy = false;
          await postpone();
        }
      } else if (current.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
      } else if ((current.required && _android?.immediateUpdateAllowed == true) || _android?.flexibleUpdateAllowed != true) {
        final result = await InAppUpdate.performImmediateUpdate();
        if (result != AppUpdateResult.success) error = 'Güncelleme tamamlanmadı. Yeniden deneyebilirsin.';
      } else {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          offer = StoreUpdateOffer(id:current.id,required:current.required,downloaded:true);
        } else { error = 'Güncelleme tamamlanmadı. Yeniden deneyebilirsin.'; }
      }
    } catch (_) { error = 'Güncelleme başlatılamadı. Bağlantını kontrol edip tekrar dene.'; }
    finally { busy = false; _emit(); }
  }

  @override
  void dispose() {
    _disposed = true;
    _startup?.cancel();
    _downloads?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
