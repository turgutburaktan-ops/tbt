enum NearbyVenueCategory { dining, cafe, hotel }

extension NearbyVenueCategoryX on NearbyVenueCategory {
  String get label => switch (this) {
        NearbyVenueCategory.dining => 'Yeme-İçme',
        NearbyVenueCategory.cafe => 'Kafeler',
        NearbyVenueCategory.hotel => 'Oteller',
      };

  List<String> get osmFilters => switch (this) {
        NearbyVenueCategory.dining => const [
            '["amenity"~"^(restaurant|fast_food|food_court|bar|pub|biergarten)\$"]',
            '["shop"~"^(bakery|deli)\$"]',
          ],
        NearbyVenueCategory.cafe => const [
            '["amenity"~"^(cafe|ice_cream)\$"]',
            '["shop"~"^(coffee|pastry|confectionery)\$"]',
          ],
        NearbyVenueCategory.hotel => const [
            '["tourism"~"^(hotel|hostel|guest_house|motel|apartment|chalet)\$"]',
          ],
      };
}

class NearbyVenue {
  final String id;
  final NearbyVenueCategory category;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String openingHours;
  final String phone;
  final String website;

  const NearbyVenue({
    required this.id,
    required this.category,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.openingHours = '',
    this.phone = '',
    this.website = '',
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'openingHours': openingHours,
        'phone': phone,
        'website': website,
      };

  factory NearbyVenue.fromJson(Map<String, dynamic> json) {
    final categoryName = (json['category'] ?? '').toString();
    final category = NearbyVenueCategory.values.firstWhere(
      (value) => value.name == categoryName,
      orElse: () => NearbyVenueCategory.dining,
    );
    return NearbyVenue(
      id: (json['id'] ?? '').toString(),
      category: category,
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: (json['address'] ?? '').toString(),
      openingHours: (json['openingHours'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      website: (json['website'] ?? '').toString(),
    );
  }
}
