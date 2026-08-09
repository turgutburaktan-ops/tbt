import 'package:flutter/foundation.dart';

import '../models/photo_spot.dart';

class FavoritesService {
  FavoritesService._();

  static final ValueNotifier<List<PhotoSpot>> savedSpots =
      ValueNotifier<List<PhotoSpot>>([]);

  static bool isSaved(PhotoSpot spot) {
    return savedSpots.value.any(
      (item) => item.id == spot.id,
    );
  }

  static void toggle(PhotoSpot spot) {
    final current = List<PhotoSpot>.from(
      savedSpots.value,
    );

    final index = current.indexWhere(
      (item) => item.id == spot.id,
    );

    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(spot);
    }

    savedSpots.value = current;
  }

  static void remove(PhotoSpot spot) {
    final current = List<PhotoSpot>.from(
      savedSpots.value,
    );

    current.removeWhere(
      (item) => item.id == spot.id,
    );

    savedSpots.value = current;
  }

  static void clear() {
    savedSpots.value = [];
  }
}
