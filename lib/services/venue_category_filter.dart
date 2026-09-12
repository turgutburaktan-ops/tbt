import '../models/nearby_venue.dart';
import 'person_search_match.dart';

bool suitableVenueCategory(NearbyVenue venue) {
  if (venue.category != NearbyVenueCategory.hotel) return true;
  final name = normalizeSearchText(venue.name);
  return ![
    'gecici barinma',
    'konteyner kent',
    'cadir kent',
    'multeci',
    'refugee',
    'emergency shelter',
  ].any(name.contains);
}
