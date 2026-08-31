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
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
    );
  }
}
