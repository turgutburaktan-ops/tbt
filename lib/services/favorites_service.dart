import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_spot.dart';

class FavoritesService {
  FavoritesService._();

  static const String _storageKey = 'saved_spot_ids';

  static final ValueNotifier<List<PhotoSpot>> savedSpots =
      ValueNotifier<List<PhotoSpot>>([]);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final savedIds = prefs.getStringList(_storageKey) ?? [];

    savedSpots.value = demoSpots
        .where((spot) => savedIds.contains(spot.id))
        .toList();
  }

  static bool isSaved(PhotoSpot spot) {
    return savedSpots.value.any((item) => item.id == spot.id);
  }

  static Future<void> toggle(PhotoSpot spot) async {
    final current = List<PhotoSpot>.from(savedSpots.value);

    final index = current.indexWhere((item) => item.id == spot.id);

    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(spot);
    }

    savedSpots.value = current;

    await _save();
  }

  static Future<void> remove(PhotoSpot spot) async {
    final current = List<PhotoSpot>.from(savedSpots.value);

    current.removeWhere((item) => item.id == spot.id);

    savedSpots.value = current;

    await _save();
  }

  static Future<void> clear() async {
    savedSpots.value = [];

    await _save();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final ids = savedSpots.value.map((spot) => spot.id).toList();

    await prefs.setStringList(_storageKey, ids);
  }
}
