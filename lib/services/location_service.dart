import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _cachedPosition;
  static DateTime? _cachedAt;
  static Future<Position?>? _inFlight;

  static const Duration _cacheLifetime = Duration(minutes: 3);
  static const Duration _requestTimeout = Duration(seconds: 6);

  static Future<Position?> getCurrentPosition({bool forceRefresh = false}) {
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        _cachedPosition != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheLifetime) {
      return Future.value(_cachedPosition);
    }

    final running = _inFlight;
    if (running != null) return running;

    final request = _resolvePosition(forceRefresh: forceRefresh);
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  static Future<Position?> _resolvePosition({required bool forceRefresh}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (!enabled) return _cachedPosition ?? await _lastKnownPosition();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _cachedPosition ?? await _lastKnownPosition();
      }

      if (!forceRefresh) {
        final lastKnown = await _lastKnownPosition();
        if (lastKnown != null) {
          _remember(lastKnown);
          return lastKnown;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _requestTimeout,
        ),
      ).timeout(_requestTimeout);
      _remember(position);
      return position;
    } on TimeoutException {
      return _cachedPosition ?? await _lastKnownPosition();
    } catch (_) {
      return _cachedPosition ?? await _lastKnownPosition();
    }
  }

  static Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  static void _remember(Position position) {
    _cachedPosition = position;
    _cachedAt = DateTime.now();
  }

  static void clearCache() {
    _cachedPosition = null;
    _cachedAt = null;
  }
}
