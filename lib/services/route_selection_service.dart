import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/route_place.dart';

class RouteSelectionService {
  RouteSelectionService._();

  static final instance = RouteSelectionService._();

  final ValueNotifier<Map<String, RoutePlace>> selected =
      ValueNotifier<Map<String, RoutePlace>>(<String, RoutePlace>{});

  Set<String> get selectedIds => selected.value.keys.toSet();

  bool contains(String id) => selected.value.containsKey(id);

  void toggle(RoutePlace place) {
    final next = Map<String, RoutePlace>.from(selected.value);
    if (next.containsKey(place.id)) {
      next.remove(place.id);
    } else {
      next[place.id] = place;
    }
    selected.value = next;
  }

  void clear() {
    if (selected.value.isEmpty) return;
    selected.value = <String, RoutePlace>{};
  }

  Future<bool> openSelectedRoute() async {
    var places = selected.value.values.toList(growable: false);
    if (places.isEmpty) return false;
    if (places.length > 10) places = places.take(10).toList(growable: false);

    final destination = places.last;
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    };

    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );
          params['origin'] = '${position.latitude},${position.longitude}';
        }
      }
    } catch (_) {}

    if (places.length > 1) {
      params['waypoints'] = places
          .take(places.length - 1)
          .map((place) => '${place.latitude},${place.longitude}')
          .join('|');
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
