import 'photo_spot.dart';

class RoutePlace {
  final PhotoSpot? spot;
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;

  const RoutePlace({
    required this.id,
    this.spot,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
  });
  PhotoSpot toPhotoSpot() =>
      spot ??
      PhotoSpot(
        id: id,
        name: name,
        city: '',
        latitude: latitude,
        longitude: longitude,
        rating: 0,
        bestTime: 'Serbest zaman',
        angle: '',
        imageUrl: '',
        category: category,
      );
}
