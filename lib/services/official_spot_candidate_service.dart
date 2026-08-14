import '../data/official_photo_spot_candidates.dart';
import '../data/official_photo_spot_candidates_supplement.dart';
import '../data/turkiye81_spot_candidates.dart';
import 'spot_repository.dart';

class OfficialSpotCandidateAudit {
  final int totalCandidates;
  final int alreadyPublishedLike;
  final int coveredCities;
  final List<OfficialSpotCandidate> pendingVerification;

  const OfficialSpotCandidateAudit({
    required this.totalCandidates,
    required this.alreadyPublishedLike,
    required this.coveredCities,
    required this.pendingVerification,
  });
}

class OfficialSpotCandidateService {
  OfficialSpotCandidateService._();
  static final OfficialSpotCandidateService instance = OfficialSpotCandidateService._();

  List<OfficialSpotCandidate> get allCandidates {
    final byKey = <String, OfficialSpotCandidate>{};
    for (final candidate in [
      ...allOfficialPhotoSpotCandidates,
      ...turkiye81SpotCandidates,
    ]) {
      final key = _key('${candidate.city}|${candidate.name}');
      byKey.putIfAbsent(key, () => candidate);
    }
    return List.unmodifiable(byKey.values);
  }

  Future<OfficialSpotCandidateAudit> audit() async {
    final existing = await SpotRepository.instance.loadSpots(limit: 1000);
    final existingKeys = <String>{
      for (final spot in existing) _key('${spot.city}|${spot.name}'),
    };
    final pending = <OfficialSpotCandidate>[];
    final cities = <String>{};
    var matched = 0;

    for (final candidate in allCandidates) {
      cities.add(_key(candidate.city));
      final key = _key('${candidate.city}|${candidate.name}');
      if (existingKeys.contains(key)) {
        matched++;
      } else {
        pending.add(candidate);
      }
    }

    return OfficialSpotCandidateAudit(
      totalCandidates: allCandidates.length,
      alreadyPublishedLike: matched,
      coveredCities: cities.length,
      pendingVerification: pending,
    );
  }

  List<OfficialSpotCandidate> byCity(String city) {
    final key = _key(city);
    return allCandidates
        .where((candidate) => _key(candidate.city) == key)
        .toList(growable: false);
  }

  Map<String, int> candidateCountByCity() {
    final counts = <String, int>{};
    for (final candidate in allCandidates) {
      counts.update(candidate.city, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9|]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
