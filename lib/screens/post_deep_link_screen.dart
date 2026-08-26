import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'post_detail_screen.dart';

class PostDeepLinkScreen extends StatelessWidget {
  final String postId;

  const PostDeepLinkScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Paylaşım')),
            body: const Center(child: Text('Bu paylaşım artık mevcut değil.')),
          );
        }
        return PostDetailScreen(post: {...doc.data()!, 'id': doc.id});
      },
    );
  }
}
