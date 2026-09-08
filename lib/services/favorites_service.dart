import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_spot.dart';
import 'spot_repository.dart';

class FavoritesService {
  FavoritesService._();

  static const String _storageKey = 'saved_spot_ids';

  static final ValueNotifier<List<PhotoSpot>> savedSpots =
      ValueNotifier<List<PhotoSpot>>([]);

  static SharedPreferences? _prefs;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_storageKey) ?? const <String>[];
    if (savedIds.isEmpty) {
      savedSpots.value = const [];
      return;
    }
    try {
      final published = await SpotRepository.instance.loadSpots();
      savedSpots.value = published
          .where((spot) => savedIds.contains(spot.id))
          .toList(growable: false);
    } catch (_) {
      // Preserve stored IDs for a later retry; never restore demo records.
      savedSpots.value = const [];
    }
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
    final current = List<PhotoSpot>.from(savedSpots.value)
      ..removeWhere((item) => item.id == spot.id);
    savedSpots.value = current;
    await _save();
  }

  static Future<void> clear() async {
    savedSpots.value = const <PhotoSpot>[];
    await _save();
  }

  static Future<void> _save() {
    final ids = savedSpots.value.map((spot) => spot.id).toList(growable: false);
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      try {
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        await prefs.setStringList(_storageKey, ids);
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
