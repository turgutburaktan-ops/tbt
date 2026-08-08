class PhotoSpot {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final double rating;
  final String bestTime;
  final String angle;
  final String imageUrl;

  const PhotoSpot({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.bestTime,
    required this.angle,
    required this.imageUrl,
  });
}

const demoSpots = <PhotoSpot>[
  PhotoSpot(
    id: 'galata',
    name: 'Galata Kulesi',
    city: 'İstanbul',
    latitude: 41.0256,
    longitude: 28.9744,
    rating: 4.8,
    bestTime: '17:45 - 19:10',
    angle: 'Karşı sokaktan, hafif alçak açı',
    imageUrl: 'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',
  ),
  PhotoSpot(
    id: 'sultanahmet',
    name: 'Sultanahmet Camii',
    city: 'İstanbul',
    latitude: 41.0054,
    longitude: 28.9768,
    rating: 4.7,
    bestTime: '18:00 - 19:20',
    angle: 'Avlu tarafından geniş açı',
    imageUrl: 'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?w=900',
  ),
  PhotoSpot(
    id: 'kapadokya',
    name: 'Kapadokya',
    city: 'Nevşehir',
    latitude: 38.6431,
    longitude: 34.8281,
    rating: 4.9,
    bestTime: '06:00 - 07:30',
    angle: 'Balonları üst üçte birlik alana yerleştir',
    imageUrl: 'https://images.unsplash.com/photo-1528181304800-259b08848526?w=900',
  ),
];
