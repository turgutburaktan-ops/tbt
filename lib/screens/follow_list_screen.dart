import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final bool followers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.followers,
  });

  @override
  Widget build(BuildContext context) {
    final stream = followers
        ? SocialService.instance.followers(userId)
        : SocialService.instance.following(userId);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: Text(followers ? 'Takipçiler' : 'Takip'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                followers ? 'Henüz takipçi yok.' : 'Henüz kimseyi takip etmiyorsun.',
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 74,
              color: Colors.white10,
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final targetId = (data['userId'] ?? doc.id).toString();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: SocialService.instance.userProfile(targetId),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data?.data() ?? const <String, dynamic>{};
                  final name = (profile['displayName'] ?? data['displayName'] ?? 'Fotoğrafçı').toString();
                  final photoUrl = (profile['photoUrl'] ?? data['photoUrl'] ?? '').toString();
                  final bio = (profile['bio'] ?? '').toString().trim();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFF202833),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: bio.isEmpty
                        ? null
                        : Text(
                            bio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54),
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
