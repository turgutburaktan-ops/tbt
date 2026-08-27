import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityDemand {
  final String id;
  final String userId;
  final String activity;
  final String city;
  final String university;
  final String window;
  final DateTime expiresAt;

  const ActivityDemand({
    required this.id,
    required this.userId,
    required this.activity,
    required this.city,
    required this.university,
    required this.window,
    required this.expiresAt,
  });

  factory ActivityDemand.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawExpiry = data['expiresAt'];
    return ActivityDemand(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      activity: (data['activity'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      university: (data['university'] ?? '').toString(),
      window: (data['window'] ?? 'today').toString(),
      expiresAt: rawExpiry is Timestamp
          ? rawExpiry.toDate()
          : DateTime.tryParse(rawExpiry?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ActivityDemandService {
  ActivityDemandService._();
  static final ActivityDemandService instance = ActivityDemandService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  String? _cachedUniversity;
  String? _cachedUniversityUserId;
  DateTime? _cachedUniversityAt;

  static const collection = 'activity_demands';
  static const Duration _profileCacheLifetime = Duration(minutes: 10);

  String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  DateTime expiryFor(String window) {
    final now = DateTime.now();
    switch (window) {
      case 'tomorrow':
        return DateTime(now.year, now.month, now.day + 2);
      case 'weekend':
        final daysUntilMonday = (8 - now.weekday) % 7;
        final monday = now.add(
          Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday),
        );
        return DateTime(monday.year, monday.month, monday.day);
      case 'today':
      default:
        return DateTime(now.year, now.month, now.day + 1);
    }
  }

  String _docId(String uid, String activity, String city, String window) =>
      '${uid}_${_key(activity)}_${_key(city)}_$window';

  Stream<List<ActivityDemand>> watchActive({int limit = 600}) {
    return _firestore.collection(collection).limit(limit).snapshots().map((
      snap,
    ) {
      final now = DateTime.now();
      return snap.docs
          .map(ActivityDemand.fromDocument)
          .where((d) => d.expiresAt.isAfter(now))
          .toList(growable: false);
    });
  }

  Future<void> setDemand({
    required String activity,
    required String city,
    required String window,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Future.error(Exception('Katılmak için giriş yapmalısın.'));
    }
    final cleanCity = city.trim();
    if (cleanCity.length < 2) {
      return Future.error(Exception('Şehir seçmelisin.'));
    }

    final docId = _docId(user.uid, activity, cleanCity, window);
    final running = _inFlight[docId];
    if (running != null) return running;

    final request = _setDemandInternal(
      userId: user.uid,
      activity: activity,
      city: cleanCity,
      window: window,
      docId: docId,
    );
    _inFlight[docId] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[docId], request)) _inFlight.remove(docId);
    });
  }

  Future<void> _setDemandInternal({
    required String userId,
    required String activity,
    required String city,
    required String window,
    required String docId,
  }) async {
    final university = await _universityFor(userId);
    final ref = _firestore.collection(collection).doc(docId);
    await ref.set({
      'userId': userId,
      'activity': activity.trim(),
      'activityKey': _key(activity),
      'city': city,
      'cityKey': _key(city),
      'university': university,
      'universityKey': _key(university),
      'window': window,
      'expiresAt': Timestamp.fromDate(expiryFor(window)),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _universityFor(String userId) async {
    final cachedAt = _cachedUniversityAt;
    if (_cachedUniversityUserId == userId &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _profileCacheLifetime) {
      return _cachedUniversity ?? '';
    }
    try {
      final profile = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 3));
      final university = (profile.data()?['university'] ?? '').toString().trim();
      _cachedUniversityUserId = userId;
      _cachedUniversity = university;
      _cachedUniversityAt = DateTime.now();
      return university;
    } catch (_) {
      return _cachedUniversityUserId == userId ? _cachedUniversity ?? '' : '';
    }
  }

  Future<void> removeDemand({
    required String activity,
    required String city,
    required String window,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final docId = _docId(user.uid, activity, city, window);
    final running = _inFlight[docId];
    if (running != null) await running;
    await _firestore.collection(collection).doc(docId).delete();
  }

  bool matches(
    ActivityDemand demand, {
    required String activity,
    required String city,
    required String window,
  }) {
    return _key(demand.activity) == _key(activity) &&
        _key(demand.city) == _key(city) &&
        demand.window == window;
  }
}
