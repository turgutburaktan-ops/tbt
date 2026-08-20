import 'package:cloud_firestore/cloud_firestore.dart';

class AppStory {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String imageUrl;
  final String storagePath;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AppStory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.imageUrl,
    required this.storagePath,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isActive => expiresAt.isAfter(DateTime.now());

  factory AppStory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AppStory(
      id: document.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'TBT kullanıcısı').toString(),
      userPhotoUrl: (data['userPhotoUrl'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      expiresAt: _date(data['expiresAt']) ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
