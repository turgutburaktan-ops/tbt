import 'route_chat_service.dart';
import 'creator_service.dart';
import 'day_plan_engine.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import '../models/travel_plan.dart';
import 'spot_repository.dart';

class TravelPlanService {
  TravelPlanService._();

  static final TravelPlanService instance = TravelPlanService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Rota kaydetmek için giriş yapmalısın.');
    return user;
  }

  Stream<List<TravelPlan>> watchMine() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <TravelPlan>[]);
    return _firestore
        .collection('travel_plans')
        .where('memberIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs.map(TravelPlan.fromDoc).toList();
          plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return plans;
        });
  }

  Future<String> create({
    required String title,
    required String city,
    required int durationHours,
    required String budget,
    required String transport,
    required List<String> interests,
    required List<PhotoSpot> spots,
    String area = '',
    List<String> mealPreferences = const [],
    DateTime? startAt,
    double distanceKm = 0,
    int travelMinutes = 0,
    int estimatedBudget = 0,
    String weatherSummary = '',
    bool isPublic = false,
    String? visibility,
    bool? allowJoinRequests,
    Map<String, dynamic> meetingPoint = const {},
    Map<String, dynamic> dayPlan = const {},
    Map<String, dynamic> routeOrigin = const {},
    List<Map<String, dynamic>> stopDetails = const [],
  }) async {
    final user = _requireUser();
    final audience = visibility ?? (isPublic ? 'public' : 'private');
    if (!['private', 'followers', 'public'].contains(audience))
      throw ArgumentError('Invalid visibility');
    final reference = _firestore.collection('travel_plans').doc();
    await reference.set({
      'ownerId': user.uid,
      'ownerName': (user.displayName ?? '').trim().isEmpty
          ? 'TBT kullanıcısı'
          : user.displayName!.trim(),
      'title': title.trim().isEmpty ? '$city rotası' : title.trim(),
      'city': city,
      'area': area,
      'routeOrigin': routeOrigin,
      'mealPreferences': mealPreferences,
      'durationHours': durationHours,
      if (dayPlan.isNotEmpty) 'dayPlan': dayPlan,
      'budget': budget,
      'transport': transport,
      'interests': interests,
      'spotIds': spots.map((spot) => spot.id).toList(growable: false),
      'spotNames': spots.map((spot) => spot.name).toList(growable: false),
      'stopSnapshots': spots
          .map(
            (spot) => {
              'id': spot.id,
              'name': spot.name,
              'city': spot.city,
              'latitude': spot.latitude,
              'longitude': spot.longitude,
              'category': spot.category,
              'description': spot.description,
              'imageUrl': spot.imageUrl,
              'bestTime': spot.bestTime,
              ...{
                for (final detail in stopDetails.where(
                  (d) => d['id'] == spot.id,
                ))
                  ...detail,
              },
            },
          )
          .toList(growable: false),
      'memberIds': [user.uid],
      if (meetingPoint.isNotEmpty) 'meetingPoint': meetingPoint,
      'joinEnabled': audience != 'private' && startAt != null && (allowJoinRequests ?? true),
      'startAt': Timestamp.fromDate(startAt ?? DateTime.now()),
      'hasSchedule': startAt != null,
      'status': 'planned',
      'distanceKm': distanceKm,
      'travelMinutes': travelMinutes,
      'estimatedBudget': estimatedBudget,
      'weatherSummary': weatherSummary,
      'isPublic': audience == 'public',
      'visibility': audience,
      'ratingTotal': 0,
      'ratingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<TravelPlan> read(String id, {bool preferCache = false}) async {
    final ref = _firestore.collection('travel_plans').doc(id);
    if (preferCache) {
      try {
        final cached = await ref.get(const GetOptions(source: Source.cache));
        if (cached.exists) return TravelPlan.fromDoc(cached);
      } catch (_) {}
    }
    return TravelPlan.fromDoc(await ref.get());
  }

  Future<void> setOptions(
    String id, {
    String? visibility,
    DateTime? startAt,
    String? transport,
    String? status,
    bool? allowMemberEdits,
  }) async {
    final uid = _requireUser().uid;
    final ref = _firestore.collection('travel_plans').doc(id);
    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      if (d == null || d['ownerId'] != uid)
        throw Exception('Yalnızca rota sahibi düzenleyebilir.');
      final v =
          visibility ??
          (d['visibility'] ?? (d['isPublic'] == true ? 'public' : 'private'))
              .toString();
      final scheduled =
          startAt != null ||
          d['hasSchedule'] == true ||
          d['joinEnabled'] == true;
      final changes = <String>[];
      if (startAt != null &&
          (d['startAt'] is! Timestamp ||
              (d['startAt'] as Timestamp).toDate() != startAt)) {
        changes.add('Gezi tarihi ve saati güncellendi.');
      }
      if (transport != null && transport != d['transport'])
        changes.add('Ulaşım şekli güncellendi.');
      if (changes.isNotEmpty && (d['memberIds'] as List? ?? []).contains(uid)) {
        tx.set(
          ref.collection('messages').doc(),
          RouteChatService.instance.envelope(changes.join(' '), 'update', null),
        );
      }
      tx.update(ref, {
        'visibility': v,
        'isPublic': v == 'public',
        'joinEnabled': v != 'private' && scheduled && d['joinEnabled'] == true,
        'hasSchedule': scheduled,
        if (startAt != null) 'startAt': Timestamp.fromDate(startAt),
        if (transport != null) 'transport': transport,
        if (status != null) 'status': status,
        if (allowMemberEdits != null) 'allowMemberEdits': allowMemberEdits,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> copyPlan(TravelPlan plan) async {
    final spots = await resolveSpots(plan);
    return create(
      title: '${plan.title} kopyası',
      city: plan.city,
      durationHours: plan.durationHours,
      budget: plan.budget,
      transport: plan.transport,
      interests: plan.interests,
      spots: spots,
      stopDetails: plan.stopSnapshots,
      dayPlan: plan.dayPlan,
      routeOrigin: plan.routeOrigin,
      distanceKm: plan.distanceKm,
      travelMinutes: plan.travelMinutes,
    );
  }

  Future<void> updateDesignedRoute(String id, Map<String,dynamic> changes) async {
    final uid = _requireUser().uid;
    final ref = _firestore.collection('travel_plans').doc(id);
    await _firestore.runTransaction((tx) async {
      final old = (await tx.get(ref)).data();
      if(old == null || old['ownerId'] != uid) throw Exception('Bu rotayı yalnızca sahibi düzenleyebilir.');
      const allowed = {'title','city','transport','spotIds','spotNames','stopSnapshots','dayPlan','routeOrigin','distanceKm','travelMinutes','visibility','isPublic','joinEnabled','hasSchedule','startAt','meetingPoint'};
      if(changes.keys.any((k)=>!allowed.contains(k))) throw ArgumentError('Invalid route fields');
      tx.update(ref,{...changes,'updatedAt':FieldValue.serverTimestamp()});
    });
  }

  Future<void> bookmark(String id, bool saved) async {
    final ref = _firestore
        .collection('users')
        .doc(_requireUser().uid)
        .collection('saved_routes')
        .doc(id);
    if (saved) {
      await ref.set({'routeId': id, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  Future<void> updateRoutePreferences(
    String id,
    String transport,
    String note, {
    Map<String, dynamic>? origin,
  }) async {
    _requireUser();
    await _firestore.collection('travel_plans').doc(id).update({
      'transport': transport,
      'routeNote': note,
      'routeOrigin': origin ?? {},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> configureSharing(
    String id, {
    required bool isPublic,
    required bool together,
    bool privateOnly = false,
    DateTime? start,
    Map<String, dynamic>? meetingPoint,
    int? limit,
  }) async {
    final uid = _requireUser().uid;
    final ref = _firestore.collection('travel_plans').doc(id);
    await _firestore.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null || data['ownerId'] != uid)
        throw Exception('Rota sahibi gerekli.');
      if (together &&
          (!isPublic ||
              start == null ||
              !start.isAfter(DateTime.now()) ||
              meetingPoint == null))
        throw Exception('Tarih, saat ve buluşma noktası gerekli.');
      if (limit != null &&
          (limit < 2 ||
              limit > 60 ||
              limit < (data['memberIds'] as List).length))
        throw Exception('Kişi sınırı mevcut katılımcı sayısından az olamaz.');
      tx.update(ref, {
        'isPublic': isPublic,
        'joinEnabled': together,
        'participantLimit': limit ?? 60,
        'visibility': isPublic ? 'public' : 'private',
        if (together) 'hasSchedule': true,
        if (together) 'startAt': Timestamp.fromDate(start!),
        if (together) 'meetingPoint': meetingPoint,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> requestJoin(String id) async {
    final user = _requireUser();
    final ref = _firestore.collection('travel_plans').doc(id);
    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      if (d == null ||
          (d['isPublic'] != true && d['visibility'] != 'followers') ||
          d['joinEnabled'] != true ||
          !(d['startAt'] as Timestamp).toDate().isAfter(DateTime.now()))
        throw Exception('Bu rota katılıma açık değil.');
      if ((d['memberIds'] as List).length >=
          (d['participantLimit'] as num? ?? 60))
        throw Exception('Rota dolu.');
      tx.set(ref.collection('join_requests').doc(user.uid), {
        'userId': user.uid,
        'name': user.displayName ?? 'TBT kullanıcısı',
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reviewJoin(String id, String applicant, bool accept) async {
    final uid = _requireUser().uid;
    final ref = _firestore.collection('travel_plans').doc(id);
    final request = ref.collection('join_requests').doc(applicant);
    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(ref)).data();
      final r = (await tx.get(request)).data();
      if (d == null || d['ownerId'] != uid || r?['status'] != 'pending')
        throw Exception('Katılım isteği artık geçerli değil.');
      final members = List<String>.from(d['memberIds']);
      if (accept && !members.contains(applicant)) {
        if (d['joinEnabled'] != true ||
            (d['isPublic'] != true && d['visibility'] != 'followers') ||
            !(d['startAt'] as Timestamp).toDate().isAfter(DateTime.now()))
          throw Exception('Rota katılıma kapalı.');
        if (members.length >= (d['participantLimit'] as num? ?? 60))
          throw Exception('Rota dolu.');
        members.add(applicant);
        tx.update(ref, {
          'memberIds': members,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(request, {
        'status': accept ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> invite({
    required String planId,
    required String planTitle,
    required Iterable<String> userIds,
  }) async {
    final user = _requireUser();
    final ids = userIds.where((id) => id.isNotEmpty && id != user.uid).toSet();
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    final plan = _firestore.collection('travel_plans').doc(planId);
    await _firestore.runTransaction((tx) async {
      final d = (await tx.get(plan)).data();
      if (d == null || d['ownerId'] != user.uid)
        throw Exception('Arkadaşları yalnızca rota sahibi davet edebilir.');
      final members = {...List<String>.from(d['memberIds']), ...ids};
      if (members.length > (d['participantLimit'] as num? ?? 60))
        throw Exception('Rota kişi sınırı aşılıyor.');
      tx.update(plan, {
        'memberIds': members.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    for (final id in ids) {
      final notification = _firestore
          .collection('users')
          .doc(id)
          .collection('notifications')
          .doc();
      batch.set(notification, {
        'type': 'travel_plan_invite',
        'title': 'Rotaya davet edildin',
        'body': '$planTitle rotasını Rota bölümünde görebilirsin.',
        'actorId': user.uid,
        'planId': planId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> delete(String planId) async {
    final user = _requireUser();
    final ref = _firestore.collection('travel_plans').doc(planId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      if (snap.data()?['ownerId'] != user.uid) throw Exception('Yalnız rota sahibi silebilir.');
      tx.delete(ref);
    });
  }

  Future<void> setPublic(String planId, bool value) async {
    _requireUser();
    await _firestore.collection('travel_plans').doc(planId).update({
      'isPublic': value,
      'visibility': value ? 'public' : 'private',
      if (!value) 'joinEnabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTitle(String planId, String title) async {
    _requireUser();
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw Exception('Rota adı 1-80 karakter olmalı.');
    }
    await _firestore.collection('travel_plans').doc(planId).update({
      'title': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStops(
    String planId,
    List<Map<String, dynamic>> stops,
  ) async {
    _requireUser();
    if (stops.isEmpty || stops.length > 12) {
      throw Exception('Rotada 1-12 durak bulunmalı.');
    }
    final normalized = stops
        .map((stop) {
          final item = Map<String, dynamic>.from(stop);
          item.removeWhere((key, value) => value == null);
          return item;
        })
        .toList(growable: false);
    await _firestore.collection('travel_plans').doc(planId).update({
      'spotIds': normalized.map((s) => (s['id'] ?? '').toString()).toList(),
      'spotNames': normalized
          .map((s) => (s['name'] ?? 'Durak').toString())
          .toList(),
      'stopSnapshots': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> publishToFeed(TravelPlan plan) async {
    final user = _requireUser();
    if (plan.ownerId != user.uid) {
      throw Exception('Yalnızca kendi rotanı paylaşabilirsin.');
    }
    final result = await CreatorService.instance.publishing(
      'publishRoute',
      'route_${plan.id}',
      {'planId': plan.id},
    );
    return result['id'].toString();
  }

  Future<void> addStop(String planId, PhotoSpot spot) =>
      addStops(planId, [spot]);

  Future<void> addStops(String planId, List<PhotoSpot> additions) async {
    _requireUser();
    final initial = await read(planId);
    final legacy = initial.stopSnapshots.isEmpty
        ? await resolveSpots(initial)
        : <PhotoSpot>[];
    final ref = _firestore.collection('travel_plans').doc(planId);
    await _firestore.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw Exception('Rota bulunamadı.');
      final stops = (data['stopSnapshots'] as List? ?? [])
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      if (stops.isEmpty) {
        for (final id in List<String>.from(data['spotIds'] ?? [])) {
          final old = legacy.where((s) => s.id == id).firstOrNull;
          if (old == null)
            throw Exception(
              'Eski rota durağı bulunamadı. Rotayı yeniden açıp tekrar dene.',
            );
          stops.add({
            'id': old.id,
            'name': old.name,
            'city': old.city,
            'latitude': old.latitude,
            'longitude': old.longitude,
            'imageUrl': old.imageUrl,
            'category': old.category,
          });
        }
      }
      for (final spot in additions) {
        if (stops.any((s) => s['id'] == spot.id)) continue;
        if (stops.length >= 12)
          throw Exception('Rotaya en fazla 12 durak eklenebilir.');
        stops.add({
          'id': spot.id,
          'name': spot.name,
          'city': spot.city,
          'latitude': spot.latitude,
          'longitude': spot.longitude,
          'category': spot.category,
          'description': spot.description,
          'imageUrl': spot.imageUrl,
          'bestTime': spot.bestTime,
        });
      }
      tx.update(ref, {
        'spotIds': stops.map((s) => s['id']).toList(),
        'spotNames': stops.map((s) => s['name']).toList(),
        'stopSnapshots': stops,
        if (data['dayPlan'] is Map)
          'dayPlan': {
            ...Map<String, dynamic>.from(data['dayPlan'] as Map),
            'routeChanged': true,
          },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addCustomStop({
    required String planId,
    required String name,
    required double latitude,
    required double longitude,
    String city = '',
  }) async {
    _requireUser();
    final cleanName = name.trim().isEmpty
        ? 'Haritadan seçilen durak'
        : name.trim();
    final id =
        'custom_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}';
    await _firestore.collection('travel_plans').doc(planId).update({
      'spotIds': FieldValue.arrayUnion([id]),
      'spotNames': FieldValue.arrayUnion([cleanName]),
      'stopSnapshots': FieldValue.arrayUnion([
        {
          'id': id,
          'name': cleanName,
          'city': city,
          'latitude': latitude,
          'longitude': longitude,
          'category': 'Özel durak',
          'bestTime': '',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TravelPlan>> watchPublic() {
    return _firestore
        .collection('travel_plans')
        .where('isPublic', isEqualTo: true)
        .limit(80)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs.map(TravelPlan.fromDoc).toList();
          plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return plans;
        });
  }

  Future<void> rate(String planId, int rating) async {
    final user = _requireUser();
    if (rating < 1 || rating > 5) return;
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('ratings')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<List<PhotoSpot>> resolveRouteSpots(TravelPlan plan) async {
    final stops = await resolveSpots(plan);
    final origin = plan.routeOrigin;
    if (origin['latitude'] is num && origin['longitude'] is num)
      return [
        PhotoSpot(
          id: 'route_origin',
          name: 'Başlangıç',
          city: plan.city,
          latitude: (origin['latitude'] as num).toDouble(),
          longitude: (origin['longitude'] as num).toDouble(),
          rating: 0,
          bestTime: '',
          angle: '',
          imageUrl: '',
        ),
        ...stops,
      ];
    final lat = (plan.dayPlan['originLatitude'] as num?)?.toDouble();
    final lon = (plan.dayPlan['originLongitude'] as num?)?.toDouble();
    if (lat == null || lon == null || plan.dayPlan['returnIncluded'] != true)
      return stops;
    return dayPlanRouteStops(stops, lat, lon, plan.city);
  }

  Future<List<PhotoSpot>> resolveSpots(TravelPlan plan) async {
    final all = plan.stopSnapshots.isNotEmpty
        ? <PhotoSpot>[]
        : await SpotRepository.instance.loadSpots();
    final byId = {for (final spot in all) spot.id: spot};
    final snapshots = {
      for (final item in plan.stopSnapshots)
        (item['id'] ?? '').toString(): item,
    };
    return plan.spotIds
        .map((id) {
          final existing = byId[id];
          if (existing != null) return existing;
          final item = snapshots[id];
          if (item == null) return null;
          return PhotoSpot(
            id: id,
            name: (item['name'] ?? 'Rota durağı').toString(),
            city: (item['city'] ?? plan.city).toString(),
            latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
            rating: 0,
            bestTime: (item['bestTime'] ?? '').toString(),
            angle: '',
            imageUrl: (item['imageUrl'] ?? '').toString(),
            description: (item['description'] ?? '').toString(),
            category: (item['category'] ?? 'Mekan').toString(),
          );
        })
        .whereType<PhotoSpot>()
        .toList(growable: false);
  }
}

