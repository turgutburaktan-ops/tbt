import '../data/official_photo_spot_candidates.dart';
import '../data/official_photo_spot_candidates_supplement.dart';
import '../data/turkiye81_spot_candidates.dart';
import '../models/photo_spot.dart';
import 'spot_repository.dart';

class NationwideSpotDirectoryEntry {
  final String id;
  final String name;
  final String city;
  final String category;
  final String sourceName;
  final String sourcePage;
  final bool sourceVerified;
  final bool mapReady;
  final PhotoSpot? publishedSpot;

  const NationwideSpotDirectoryEntry({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.sourceName,
    required this.sourcePage,
    required this.sourceVerified,
    required this.mapReady,
    this.publishedSpot,
  });
}

class NationwideSpotDirectoryService {
  NationwideSpotDirectoryService._();
  static final NationwideSpotDirectoryService instance =
      NationwideSpotDirectoryService._();

  Future<List<NationwideSpotDirectoryEntry>> load() async {
    final published = await SpotRepository.instance.loadSpots(limit: 2000);
    final publishedByKey = <String, PhotoSpot>{
      for (final spot in published) _key(spot.city, spot.name): spot,
    };

    final candidates = <OfficialSpotCandidate>[
      ...officialPhotoSpotCandidates,
      ...officialPhotoSpotCandidatesSupplement,
      ...turkiye81SpotCandidates,
    ];

    final byKey = <String, NationwideSpotDirectoryEntry>{};

    // Önce kaynak-teyitli/ulusal aday havuzunu ekle.
    for (final candidate in candidates) {
      final key = _key(candidate.city, candidate.name);
      final spot = publishedByKey[key];
      final sourceVerified = _isTrustedTourismSource(candidate);
      byKey.putIfAbsent(
        key,
        () => NationwideSpotDirectoryEntry(
          id: candidate.id,
          name: candidate.name,
          city: candidate.city,
          category: candidate.suggestedCategory,
          sourceName: candidate.sourceName,
          sourcePage: candidate.sourcePage,
          sourceVerified: sourceVerified,
          mapReady: spot != null,
          publishedSpot: spot,
        ),
      );
    }

    // Katalogda olup aday listesinde bulunmayan hazır noktaları da koru.
    for (final spot in published) {
      final key = _key(spot.city, spot.name);
      byKey.putIfAbsent(
        key,
        () => NationwideSpotDirectoryEntry(
          id: spot.id,
          name: spot.name,
          city: spot.city,
          category: spot.category,
          sourceName: 'Uygulama kürasyon kataloğu',
          sourcePage: '',
          sourceVerified: true,
          mapReady: true,
          publishedSpot: spot,
        ),
      );
    }

    final result = byKey.values.toList()
      ..sort((a, b) {
        final city = a.city.compareTo(b.city);
        return city != 0 ? city : a.name.compareTo(b.name);
      });
    return List.unmodifiable(result);
  }

  Future<Map<String, int>> coverageByCity() async {
    final entries = await load();
    final counts = <String, int>{};
    for (final item in entries) {
      counts.update(item.city, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<List<NationwideSpotDirectoryEntry>> mapReady() async =>
      (await load()).where((e) => e.mapReady).toList(growable: false);

  Future<List<NationwideSpotDirectoryEntry>>
  sourceVerifiedWaitingForMap() async => (await load())
      .where((e) => e.sourceVerified && !e.mapReady)
      .toList(growable: false);

  static bool _isTrustedTourismSource(OfficialSpotCandidate candidate) {
    final source = '${candidate.sourceName} ${candidate.sourcePage}'
        .toLowerCase();
    return source.contains('gotürkiye') ||
        source.contains('goturkiye') ||
        source.contains('kültür ve turizm') ||
        source.contains('kultur ve turizm') ||
        source.contains('.ktb.gov.tr');
  }

  static String _key(String city, String name) =>
      '${_normalize(city)}|${_normalize(name)}';

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
