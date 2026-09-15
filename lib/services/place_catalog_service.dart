import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import 'published_spot_catalog.dart';
import 'spot_browsing.dart';

const catalogKinds = ['gezi', 'dining', 'cafe', 'hotel'];

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.spot,
    this.venue,
    this.attribution = '',
  });
  final String id;
  final PhotoSpot spot;
  final NearbyVenue? venue;
  final String attribution;

  static CatalogItem? decode(Map<String, dynamic> d) {
    final legacy = d['legacyId'] as String? ?? '';
    final kind = d['kind'] as String? ?? '';
    final id = d['canonicalId'] as String? ?? '';
    if (legacy.isEmpty || !catalogKinds.contains(kind)) return null;
    if (kind == 'gezi') {
      final spot = PublishedSpotCatalog.decode(legacy, d);
      return spot == null || id != 'spot:$legacy'
          ? null
          : CatalogItem(id: id, spot: spot);
    }
    if (id != 'venue:$kind:$legacy') return null;
    final v = NearbyVenue.fromJson({...d, 'id': legacy, 'category': kind});
    if (v.name.isEmpty || !v.latitude.isFinite || !v.longitude.isFinite)
      return null;
    return CatalogItem(
      id: id,
      venue: v,
      attribution: d['attribution'] as String? ?? '',
      spot: PhotoSpot(
        id: id,
        name: v.name,
        city: d['city'] as String? ?? '',
        latitude: v.latitude,
        longitude: v.longitude,
        rating: (d['rating'] as num?)?.toDouble() ?? 0,
        bestTime: v.openingHours,
        angle: '',
        imageUrl: v.imageUrl,
        category: v.category.label,
        description: v.description,
        tags: const ['FirestoreDoğrulanmış'],
      ),
    );
  }
}

class CatalogPage {
  const CatalogPage(
    this.items, {
    this.nextCursor,
    this.sourceStatus = 'ready',
    this.fromCache = false,
  });
  final List<CatalogItem> items;
  final String? nextCursor;
  final String sourceStatus;
  final bool fromCache;
}

class PlaceCatalogService {
  PlaceCatalogService._();
  static final instance = PlaceCatalogService._();
  final _pages = LinkedHashMap<String, CatalogPage>();
  static String partition(String city, String kind) =>
      '${foldPlaceText(city.replaceAll('İ', 'i')).replaceAll('â', 'a').replaceAll('i̇', 'i').replaceAll(' ', '_')}_$kind';

  Future<CatalogPage> page(
    String city,
    String kind, {
    String? cursor,
    bool refresh = false,
  }) async {
    if (!catalogKinds.contains(kind) || city.trim().isEmpty)
      throw Exception('Bir şehir seçmelisin.');
    final key = '${partition(city, kind)}:${cursor ?? ''}';
    final root = FirebaseFirestore.instance.doc(
      'place_catalog/${partition(city, kind)}',
    );
    Query<Map<String, dynamic>> query = root
        .collection('items')
        .orderBy(FieldPath.documentId)
        .limit(40);
    if (cursor != null) query = query.startAfter([cursor]);
    try {
      final options = GetOptions(
        source: refresh ? Source.server : Source.serverAndCache,
      );
      final snapshots = await Future.wait([
        root.get(options),
        query.get(options),
      ]).timeout(const Duration(seconds: 12));
      final meta = snapshots[0] as DocumentSnapshot<Map<String, dynamic>>;
      final data = snapshots[1] as QuerySnapshot<Map<String, dynamic>>;
      if (meta.data()?['ready'] != true)
        throw Exception('Bu şehirdeki yerler henüz hazırlanıyor.');
      if (data.metadata.isFromCache && data.docs.isEmpty)
        throw Exception(
          'Yerler yüklenemedi. Bağlantını kontrol edip tekrar dene.',
        );
      final result = CatalogPage(
        data.docs
            .map((d) => CatalogItem.decode(d.data()))
            .whereType<CatalogItem>()
            .toList(),
        nextCursor: data.docs.length == 40 ? data.docs.last.id : null,
        sourceStatus: meta.data()?['sourceStatus'] as String? ?? 'pending',
        fromCache: data.metadata.isFromCache,
      );
      _pages.remove(key);
      _pages[key] = result;
      while (_pages.length > 24) {
        _pages.remove(_pages.keys.first);
      }
      return result;
    } catch (_) {
      final cached = _pages[key];
      if (cached != null)
        return CatalogPage(
          cached.items,
          nextCursor: cached.nextCursor,
          sourceStatus: cached.sourceStatus,
          fromCache: true,
        );
      rethrow;
    }
  }

  Future<List<CatalogItem>> city(
    String city,
    String kind, {
    bool refresh = false,
    void Function(List<CatalogItem>)? onPage,
  }) async {
    final items = <CatalogItem>[];
    String? cursor;
    do {
      final result = await page(city, kind, cursor: cursor, refresh: refresh);
      items.addAll(result.items);
      onPage?.call(List.of(items));
      if (result.nextCursor != null && result.nextCursor == cursor)
        throw StateError('Katalog sayfası ilerlemedi.');
      cursor = result.nextCursor;
    } while (cursor != null);
    return items;
  }
}
