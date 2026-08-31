import 'package:cloud_firestore/cloud_firestore.dart';

class TravelPlan {
  final String id;
  final String ownerId;
  final String title;
  final String city;
  final int durationHours;
  final String budget;
  final String transport;
  final List<String> interests;
  final List<String> spotIds;
  final List<String> spotNames;
  final List<String> memberIds;
  final List<Map<String, dynamic>> stopSnapshots;
  final DateTime startAt;
  final double distanceKm;
  final int travelMinutes;
  final int estimatedBudget;
  final String weatherSummary;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TravelPlan({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.city,
    required this.durationHours,
    required this.budget,
    required this.transport,
    required this.interests,
    required this.spotIds,
    required this.spotNames,
    required this.memberIds,
    this.stopSnapshots = const [],
    required this.startAt,
    this.distanceKm = 0,
    this.travelMinutes = 0,
    this.estimatedBudget = 0,
    this.weatherSummary = '',
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TravelPlan.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    DateTime readDate(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : DateTime.now();
    }

    List<String> strings(String key) => (data[key] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return TravelPlan(
      id: document.id,
      ownerId: (data['ownerId'] ?? '').toString(),
      title: (data['title'] ?? 'Gezi planı').toString(),
      city: (data['city'] ?? '').toString(),
      durationHours: (data['durationHours'] as num?)?.toInt() ?? 3,
      budget: (data['budget'] ?? 'Orta').toString(),
      transport: (data['transport'] ?? 'Araç').toString(),
      interests: strings('interests'),
      spotIds: strings('spotIds'),
      spotNames: strings('spotNames'),
      memberIds: strings('memberIds'),
      stopSnapshots:
          (data['stopSnapshots'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false),
      startAt: data['startAt'] is Timestamp
          ? (data['startAt'] as Timestamp).toDate()
          : readDate('createdAt'),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      travelMinutes: (data['travelMinutes'] as num?)?.toInt() ?? 0,
      estimatedBudget: (data['estimatedBudget'] as num?)?.toInt() ?? 0,
      weatherSummary: (data['weatherSummary'] ?? '').toString(),
      isPublic: data['isPublic'] == true,
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
    );
  }
}
