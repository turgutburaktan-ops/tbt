import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';

class SocialConnectionsScreen extends StatelessWidget {
  final String userId;
  final bool followersMode;

  const SocialConnectionsScreen({
    super.key,
    required this.userId,
    required this.followersMode,
  });

  @override
  Widget build(BuildContext context) {
    final stream = followersMode
        ? SocialService.instance.followers(userId)
        : SocialService.instance.following(userId);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: Text(followersMode ? 'Takipçiler' : 'Takip Edilenler'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                followersMode
                    ? 'Henüz takipçin yok.'
                    : 'Henüz kimseyi takip etmiyorsun.',
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final targetId = (data['userId'] ?? docs[index].id).toString();
              return _UserTile(userId: targetId, fallback: data);
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> fallback;

  const _UserTile({required this.userId, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: SocialService.instance.userProfile(userId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? fallback;
        final name = (data['displayName'] ?? 'Fotoğrafçı').toString();
        final bio = (data['bio'] ?? '').toString();
        final photoUrl = (data['photoUrl'] ?? '').toString();

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF1A1D20),
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
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
  }
}
