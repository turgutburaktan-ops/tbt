import 'package:cloud_firestore/cloud_firestore.dart';

class AppStory {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String mediaType;
  final String imageUrl;
  final String storagePath;
  final String videoUrl;
  final String videoStoragePath;
  final String thumbnailUrl;
  final String thumbnailStoragePath;
  final int durationMs;
  final String musicTrackId;
  final String musicTitle;
  final String musicArtist;
  final String musicArtworkUrl;
  final String musicPreviewUrl;
  final int musicStartMs;
  final int musicDurationMs;
  final String musicStickerStyle;
  final String musicLicense;
  final String musicSourceUrl;
  final double musicVolume;
  final double originalAudioVolume;
  final int musicFadeInMs;
  final int musicFadeOutMs;
  final String musicMood;
  final DateTime createdAt;
  final DateTime expiresAt;

  const AppStory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.mediaType,
    required this.imageUrl,
    required this.storagePath,
    required this.videoUrl,
    required this.videoStoragePath,
    required this.thumbnailUrl,
    required this.thumbnailStoragePath,
    required this.durationMs,
    this.musicTrackId = '',
    this.musicTitle = '',
    this.musicArtist = '',
    this.musicArtworkUrl = '',
    this.musicPreviewUrl = '',
    this.musicStartMs = 0,
    this.musicDurationMs = 0,
    this.musicStickerStyle = 'minimal',
    this.musicLicense = '',
    this.musicSourceUrl = '',
    this.musicVolume = .85,
    this.originalAudioVolume = .25,
    this.musicFadeInMs = 350,
    this.musicFadeOutMs = 500,
    this.musicMood = 'Seyahat',
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isActive => expiresAt.isAfter(DateTime.now());
  bool get isVideo => mediaType == 'video' && videoUrl.isNotEmpty;
  bool get hasMusic => musicPreviewUrl.trim().isNotEmpty;
  String get previewUrl => thumbnailUrl.isNotEmpty ? thumbnailUrl : imageUrl;
  String get previewStoragePath =>
      thumbnailStoragePath.isNotEmpty ? thumbnailStoragePath : storagePath;

  factory AppStory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final mediaType = (data['mediaType'] ?? '').toString();
    return AppStory(
      id: document.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'TBT kullanıcısı').toString(),
      userPhotoUrl: (data['userPhotoUrl'] ?? '').toString(),
      mediaType: mediaType == 'video' || videoUrl.isNotEmpty
          ? 'video'
          : 'image',
      imageUrl: (data['imageUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      videoUrl: videoUrl,
      videoStoragePath: (data['videoStoragePath'] ?? '').toString(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
      thumbnailStoragePath: (data['thumbnailStoragePath'] ?? '').toString(),
      durationMs: _int(data['durationMs']),
      musicTrackId: (data['musicTrackId'] ?? '').toString(),
      musicTitle: (data['musicTitle'] ?? '').toString(),
      musicArtist: (data['musicArtist'] ?? '').toString(),
      musicArtworkUrl: (data['musicArtworkUrl'] ?? '').toString(),
      musicPreviewUrl: (data['musicAudioUrl'] ?? data['musicPreviewUrl'] ?? '').toString(),
      musicStartMs: _int(data['musicStartMs']),
      musicDurationMs: _int(data['musicDurationMs']),
      musicStickerStyle: (data['musicStickerStyle'] ?? 'minimal').toString(),
      musicLicense: (data['musicLicense'] ?? '').toString(),
      musicSourceUrl: (data['musicSourceUrl'] ?? '').toString(),
      musicVolume: _double(data['musicVolume'], .85),
      originalAudioVolume: _double(data['originalAudioVolume'], .25),
      musicFadeInMs: _int(data['musicFadeInMs']),
      musicFadeOutMs: _int(data['musicFadeOutMs']),
      musicMood: (data['musicMood'] ?? 'Seyahat').toString(),
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      expiresAt:
          _date(data['expiresAt']) ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }

  static double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble().clamp(0, 1);
    return double.tryParse(value?.toString() ?? '')?.clamp(0, 1) ?? fallback;
  }

  static int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
