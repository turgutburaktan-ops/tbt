import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_event.dart';

class EventPrivacyService {
  EventPrivacyService._();
  static final EventPrivacyService instance = EventPrivacyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<String>> resolveAudience(
    EventVisibility visibility, {
    List<String> selectedUserIds = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Gizlilik ayarı için giriş yapmalısın.');

    if (visibility == EventVisibility.public ||
        visibility == EventVisibility.private) {
      return const [];
    }
    if (visibility == EventVisibility.selectedPeople) {
      return selectedUserIds
          .where((id) => id.isNotEmpty && id != user.uid)
          .toSet()
          .toList();
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    if (visibility == EventVisibility.followers) {
      final snap = await userRef.collection('followers').get();
      return snap.docs.map((d) => d.id).toList();
    }
    if (visibility == EventVisibility.mutuals) {
      final followers = await userRef.collection('followers').get();
      final following = await userRef.collection('following').get();
      final followerIds = followers.docs.map((d) => d.id).toSet();
      return following.docs
          .map((d) => d.id)
          .where(followerIds.contains)
          .toList();
    }
    if (visibility == EventVisibility.closeFriends) {
      final snap = await userRef.collection('close_friends').get();
      return snap.docs.map((d) => d.id).toList();
    }
    return const [];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> users() =>
      _firestore.collection('users').limit(300).snapshots();
}
