import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/creator_service.dart';
import '../widgets/creator_view_tracker.dart';
import 'post_detail_screen.dart';
import 'reels_screen.dart';
import 'travel_plan_detail_screen.dart';

class PostDeepLinkScreen extends StatelessWidget {
  final String postId;
  final String? repostId, storyId;
  const PostDeepLinkScreen({
    super.key,
    required this.postId,
    this.repostId,
    this.storyId,
  });

  Future<Widget> _page() async {
    await CreatorService.instance.publishing('resolve', postId, {
      if (repostId != null) 'repostId': repostId,
      if (storyId != null) 'storyId': storyId,
    });
    final doc = await FirebaseFirestore.instance.doc('posts/$postId').get();
    if (!doc.exists) throw StateError('Gönderi bulunamadı');
    final post = {...doc.data()!, 'id': doc.id};
    if (post['mediaType'] == 'route') {
      final plan = await FirebaseFirestore.instance
          .doc('travel_plans/${post['travelPlanId']}')
          .get();
      if (!plan.exists || plan.data()?['isPublic'] != true)
        throw StateError('Rota kullanılamıyor');
      return CreatorViewTracker(
        postId: postId,
        child: TravelPlanDetailScreen(plan: TravelPlan.fromDoc(plan)),
      );
    }
    if (post['mediaType'] == 'video' ||
        (post['videoUrl'] ?? '').toString().isNotEmpty)
      return ReelsScreen(initialPost: post);
    return PostDetailScreen(post: post);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, auth) {
      if (auth.data == null)
        return Scaffold(
          appBar: AppBar(title: const Text('Paylaşım')),
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Gönderiyi görmek için giriş yap'),
            ),
          ),
        );
      return _content(context);
    },
  );
  Widget _content(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.doc('posts/$postId').snapshots(),
        builder: (context, source) => FutureBuilder<Widget>(
          future: source.hasData && source.data!.exists ? _page() : null,
          builder: (context, snapshot) {
            if (source.connectionState == ConnectionState.waiting ||
                (source.data?.exists == true &&
                    snapshot.connectionState == ConnectionState.waiting)) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) return snapshot.data!;
            return Scaffold(
              appBar: AppBar(title: const Text('Paylaşım')),
              body: const Center(
                child: Text('Bu paylaşım artık kullanılamıyor.'),
              ),
            );
          },
        ),
      );
}
