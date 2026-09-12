import 'post_sharing_actions.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/creator_center_screen.dart';
import 'shared_post_card.dart';

/// Adds Creator highlights without replacing existing posts, routes or events.
class ProfileSharingSection extends StatelessWidget {
  const ProfileSharingSection({
    super.key,
    required this.userId,
    this.creator = false,
    this.own = false,
  });
  final String userId;
  final bool creator, own;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (creator && own)
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatorCenterScreen()),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Creator Merkezi'),
          ),
        ),
      if (creator)
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .doc('creator_profiles/$userId')
              .snapshots(),
          builder: (context, snapshot) {
            final pins = List<String>.from(
              snapshot.data?.data()?['pinnedPostIds'] as List? ?? const [],
            );
            if (pins.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Creator’ın seçtikleri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                for (final id in pins.take(3))
                  SharedPostCard(
                    key: ValueKey('pin-$id'),
                    postId: id,
                    compact: true,
                  ),
              ],
            );
          },
        ),
      ExpansionTile(
        title: const Text('Yeniden paylaşımlar'),
        leading: const Icon(Icons.repeat),
        children: [_ReferenceList(userId: userId, bookmarks: false)],
      ),
      if (own)
        ExpansionTile(
          title: const Text('Kaydedilen gönderiler'),
          leading: const Icon(Icons.bookmark_outline),
          children: [_ReferenceList(userId: userId, bookmarks: true)],
        ),
    ],
  );
}

class _ReferenceList extends StatefulWidget {
  const _ReferenceList({required this.userId, required this.bookmarks});
  final String userId;
  final bool bookmarks;
  @override
  State<_ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends State<_ReferenceList> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _watch();
  Stream<QuerySnapshot<Map<String, dynamic>>> _watch() async* {
    final query = FirebaseFirestore.instance
        .collection(widget.bookmarks ? 'post_bookmarks' : 'post_reposts')
        .where('userId', isEqualTo: widget.userId);
    try {
      yield* query.orderBy('createdAt', descending: true).limit(30).snapshots();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;
      // Old deployments may lack the composite index. Retain owner filtering.
      yield* query.snapshots();
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Paylaşımlar yüklenemedi.'),
                  TextButton(
                    onPressed: () => setState(() => _stream = _watch()),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            );
          if (!snapshot.hasData)
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          final docs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final at = a.data()['createdAt'], bt = b.data()['createdAt'];
              if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
              return a.id.compareTo(b.id);
            });
          if (docs.isEmpty)
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz içerik yok.'),
            );
          return Column(
            children: [
              for (final doc in docs.take(30))
                Column(
                  key: ValueKey(doc.id),
                  children: [
                    SharedPostCard(
                      postId: doc.data()['postId'].toString(),
                      repostId: widget.bookmarks ? null : doc.id,
                      compact: true,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PostSharingActions(
                        postId: doc.data()['postId'].toString(),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      );
}
