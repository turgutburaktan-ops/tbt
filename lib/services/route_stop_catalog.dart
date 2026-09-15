import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import 'nearby_venue_service.dart';
import 'spot_browsing.dart';
import 'spot_repository.dart';

Future<List<PhotoSpot>> loadRouteStopCatalog(String city, int category) async {
  if (category == 0) {
    return browseCitySpots(
      await SpotRepository.instance.loadSpots(),
      city: city,
    );
  }
  final area = await NearbyVenueService.instance.findCity(city);
  if (area == null) throw Exception('Şehir bilgisi alınamadı. Tekrar dene.');
  final venues = await NearbyVenueService.instance.nearby(
    category: NearbyVenueCategory.values[category - 1],
    latitude: area.latitude,
    longitude: area.longitude,
    useSelectedCity: false,
  );
  return venues
      .map(
        (v) => PhotoSpot(
          id: 'venue:${v.category.name}:${v.id}',
          name: v.name,
          city: city,
          latitude: v.latitude,
          longitude: v.longitude,
          rating: 0,
          bestTime: v.openingHours,
          angle: '',
          imageUrl: v.imageUrl,
          category: v.category.label,
          description: v.description,
          tags: const ['FirestoreDoğrulanmış'],
        ),
      )
      .toList();
}
