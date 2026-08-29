import 'dart:typed_data' as typed_data;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef ByteData = typed_data.ByteData;

class StoryContextLinkService {
  StoryContextLinkService._();
  static final instance = StoryContextLinkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> attachToLatestOwnStory({
    required String contextType,
    required String contextId,
    required String contextName,
    required String templateId,
    required String templateTitle,
    required int slotCount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('stories')
        .where('userId', isEqualTo: user.uid)
        .limit(20)
        .get()
        .timeout(const Duration(seconds: 7));
    if (snapshot.docs.isEmpty) return;

    QueryDocumentSnapshot<Map<String, dynamic>>? latest;
    DateTime latestAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final doc in snapshot.docs) {
      final raw = doc.data()['createdAt'];
      final at = raw is Timestamp ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      if (latest == null || at.isAfter(latestAt)) {
        latest = doc;
        latestAt = at;
      }
    }
    if (latest == null) return;

    final data = <String, dynamic>{
      'storyContextType': contextType,
      'storyContextId': contextId,
      'storyContextName': contextName,
      'storyTemplateId': templateId,
      'storyTemplateTitle': templateTitle,
      'storyTemplateSlotCount': slotCount,
      'storyTemplateVersion': 1,
      'storyContextLinkedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(latest.reference, data, SetOptions(merge: true));
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('story_archive')
          .doc(latest.id),
      data,
      SetOptions(merge: true),
    );
    await batch.commit().timeout(const Duration(seconds: 7));
  }
}
