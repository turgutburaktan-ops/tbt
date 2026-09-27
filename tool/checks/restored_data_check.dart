import '../../lib/models/photo_spot.dart';
import '../../lib/services/spot_browsing.dart';
import '../../lib/services/profile_details_patch.dart';

void check(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

PhotoSpot spot(
  String id,
  String name,
  String city,
  double lat,
  double rating,
) => PhotoSpot(
  id: id,
  name: name,
  city: city,
  latitude: lat,
  longitude: 39.2,
  rating: rating,
  bestTime: '',
  angle: '',
  imageUrl: '',
);

void main() {
  final spots = [
    spot('near', 'İzzet Paşa Camii', 'Elazığ', 38.67, 2),
    spot('rated', 'Harput', 'Elazığ', 38.71, 5),
    spot('other', 'İzzet Paşa', 'İstanbul', 41, 5),
  ];
  final nearby = browseCitySpots(
    spots,
    city: 'ELAZIG',
    latitude: 38.67,
    longitude: 39.2,
  );
  check(
    nearby.map((s) => s.id).join(',') == 'near,rated',
    'City isolation and nearest order',
  );
  final popular = browseCitySpots(spots, city: 'Elazığ', nearest: false);
  check(popular.first.id == 'rated', 'Popularity order');
  final search = browseCitySpots(spots, city: 'Elazığ', query: 'izzet pasa');
  check(
    search.length == 1 && search.first.id == 'near',
    'Turkish search must remain in selected city',
  );
  check(
    browseCitySpots(spots, city: 'Ankara').isEmpty,
    'Empty cities must not leak other cities',
  );
  check(
    browseCitySpots(spots, city: null).isEmpty,
    'Unknown location must request a city',
  );
  final profile = {
    'photoUrl': 'existing-avatar.jpg',
    'bio': 'old',
    'username': 'burak',
  };
  profile.addAll(
    profileDetailsPatch(
      displayName: 'Burak',
      bio: 'new',
    ).cast<String, String>(),
  );
  check(
    profile['photoUrl'] == 'existing-avatar.jpg' && profile['bio'] == 'new',
    'Bio edits preserve avatar',
  );
  check(profile['username'] == 'burak', 'Other profile fields preserved');
  profile.addAll(
    profileDetailsPatch(
      displayName: 'Burak',
      bio: 'new',
      uploadedPhotoUrl: 'new-avatar.jpg',
    ).cast<String, String>(),
  );
  check(
    profile['photoUrl'] == 'new-avatar.jpg',
    'Explicit photo uploads replace avatar',
  );
  profile.addAll(
    profileDetailsPatch(
      displayName: 'Burak',
      bio: '',
      uploadedPhotoUrl: '',
    ).cast<String, String>(),
  );
  check(
    profile['photoUrl'] == 'new-avatar.jpg',
    'Empty upload URL never deletes avatar',
  );
  print('9 restored-data checks passed.');
}
