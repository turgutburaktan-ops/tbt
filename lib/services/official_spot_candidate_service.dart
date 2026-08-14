import '../data/official_photo_spot_candidates.dart';
import '../models/photo_spot.dart';
import 'spot_repository.dart';

class OfficialSpotCandidateAudit {
  final int totalCandidates;
  final int alreadyPublishedLike;
  final List<OfficialSpotCandidate> pendingVerification;

  const OfficialSpotCandidateAudit({
    required this.totalCandidates,
    required this.alreadyPublishedLike,
    required this.pendingVerification,
  });
}

class OfficialSpotCandidateService {
  OfficialSpotCandidateService._();

  static final OfficialSpotCandidateService instance =
      OfficialSpotCandidateService._();

  Future<OfficialSpotCandidateAudit> audit() async {
    final existing = await SpotRepository.instance.loadSpots(limit: 500);
    final existingKeys = <String>{
      for (final spot in existing) _key('${spot.city}|${spot.name}'),
    };

    final pending = <OfficialSpotCandidate>[];
    var matched = 0;

    for (final candidate in officialPhotoSpotCandidates) {
      final key = _key('${candidate.city}|${candidate.name}');
      if (existingKeys.contains(key)) {
        matched++;
      } else {
        pending.add(candidate);
      }
    }

    return OfficialSpotCandidateAudit(
      totalCandidates: officialPhotoSpotCandidates.length,
      alreadyPublishedLike: matched,
      pendingVerification: pending,
    );
  }

  List<OfficialSpotCandidate> byCity(String city) {
    final key = _key(city);
    return officialPhotoSpotCandidates
        .where((candidate) => _key(candidate.city) == key)
        .toList(growable: false);
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
