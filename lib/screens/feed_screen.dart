import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D10),
        body: Center(
          child: Text(
            'Akışı görmek için giriş yapmalısın.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D10),
        elevation: 0,
        title: const Text(
          'Akış',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: SocialService.instance.followingIds(),
        builder: (context, followingSnapshot) {
          if (followingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF16B8A6),
              ),
            );
          }

          if (followingSnapshot.hasError) {
            return Center(
              child: Text(
                'Takip listesi yüklenemedi.\n${followingSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            );
          }

          final followingIds = followingSnapshot.data ?? <String>[];

          if (followingIds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 70,
                      color: Color(0xFF16B8A6),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Henüz kimseyi takip etmiyorsun',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kullanıcıları takip ettiğinde paylaşımları burada görünecek.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy(
                  'createdAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, postsSnapshot) {
              if (postsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF16B8A6),
                  ),
                );
              }

              if (postsSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      'Akış yüklenemedi.\n${postsSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                );
              }

              final allPosts = postsSnapshot.data?.docs ?? [];

              final feedPosts = allPosts.where(
                (doc) {
                  final data = doc.data();
                  final userId = (data['userId'] ?? '').toString();

                  return followingIds.contains(userId);
                },
              ).toList();

              if (feedPosts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 70,
                          color: Colors.white38,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Takip ettiklerinden henüz paylaşım yok',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 30,
                ),
                itemCount: feedPosts.length,
                itemBuilder: (context, index) {
                  final doc = feedPosts[index];
                  final data = doc.data();

                  final userId = (data['userId'] ?? '').toString();

                  final userName =
                      (data['userName'] ?? 'Fotoğrafçı').toString();

                  final imageUrl = (data['imageUrl'] ?? '').toString();

                  final caption = (data['caption'] ?? '').toString();

                  final spotName = (data['spotName'] ?? '').toString();

                  final latitude = data['latitude'];

                  final longitude = data['longitude'];

                  return _FeedPostCard(
                    userId: userId,
                    userName: userName,
                    imageUrl: imageUrl,
                    caption: caption,
                    spotName: spotName,
                    latitude: latitude is num ? latitude.toDouble() : null,
                    longitude: longitude is num ? longitude.toDouble() : null,
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

class _FeedPostCard extends StatelessWidget {
  final String userId;
  final String userName;
  final String imageUrl;
  final String caption;
  final String spotName;
  final double? latitude;
  final double? longitude;

  const _FeedPostCard({
    required this.userId,
    required this.userName,
    required this.imageUrl,
    required this.caption,
    required this.spotName,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF11181D),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: userId.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: userId,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFF16B8A6),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF152128),
                      child: Icon(
                        Icons.person,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color: const Color(0xFF152128),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              14,
              14,
              6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
                const Spacer(),
                if (spotName.isNotEmpty)
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF16B8A6),
                  ),
              ],
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                4,
                14,
                4,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$userName ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: caption,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (spotName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                6,
                14,
                14,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 17,
                    color: Color(0xFF16B8A6),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      spotName,
                      style: const TextStyle(
                        color: Color(0xFF16B8A6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
