import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryContextLinkService {
  StoryContextLinkService._();
  static final instance = StoryContextLinkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _latestOwnStory() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('stories')
        .where('userId', isEqualTo: user.uid)
        .limit(20)
        .get()
        .timeout(const Duration(seconds: 7));
    if (snapshot.docs.isEmpty) return null;

    QueryDocumentSnapshot<Map<String, dynamic>>? latest;
    DateTime latestAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final doc in snapshot.docs) {
      final raw = doc.data()['createdAt'];
      final at = raw is Timestamp
          ? raw.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      if (latest == null || at.isAfter(latestAt)) {
        latest = doc;
        latestAt = at;
      }
    }
    return latest;
  }

  Future<void> _writeToStoryAndArchive(
    QueryDocumentSnapshot<Map<String, dynamic>> story,
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();
    batch.set(story.reference, data, SetOptions(merge: true));
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('story_archive')
          .doc(story.id),
      data,
      SetOptions(merge: true),
    );
    await batch.commit().timeout(const Duration(seconds: 7));
  }

  Future<void> attachToLatestOwnStory({
    required String contextType,
    required String contextId,
    required String contextName,
    required String templateId,
    required String templateTitle,
    required int slotCount,
  }) async {
    final latest = await _latestOwnStory();
    if (latest == null) return;

    await _writeToStoryAndArchive(latest, <String, dynamic>{
      'storyContextType': contextType,
      'storyContextId': contextId,
      'storyContextName': contextName,
      'storyTemplateId': templateId,
      'storyTemplateTitle': templateTitle,
      'storyTemplateSlotCount': slotCount,
      'storyTemplateVersion': 1,
      'storyContextLinkedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> attachMusicToLatestOwnStory({
    required String trackId,
    required String title,
    required String artist,
    required String artworkUrl,
    required String previewUrl,
    required int startMs,
    required int durationMs,
    required String stickerStyle,
    required String license,
    required String sourceUrl,
    required double musicVolume,
    required double originalAudioVolume,
    required int fadeInMs,
    required int fadeOutMs,
    required String mood,
  }) async {
    final latest = await _latestOwnStory();
    if (latest == null) return;

    await _writeToStoryAndArchive(latest, <String, dynamic>{
      'musicTrackId': trackId,
      'musicTitle': title,
      'musicArtist': artist,
      'musicArtworkUrl': artworkUrl,
      'musicPreviewUrl': previewUrl,
      'musicAudioUrl': previewUrl,
      'musicStartMs': startMs,
      'musicDurationMs': durationMs,
      'musicStickerStyle': stickerStyle,
      'musicLicense': license,
      'musicSourceUrl': sourceUrl,
      'musicVolume': musicVolume.clamp(0, 1),
      'originalAudioVolume': originalAudioVolume.clamp(0, 1),
      'musicFadeInMs': fadeInMs.clamp(0, 1500),
      'musicFadeOutMs': fadeOutMs.clamp(0, 1500),
      'musicMood': mood,
      'musicVersion': 3,
      'musicLinkedAt': FieldValue.serverTimestamp(),
    });
  }
}
