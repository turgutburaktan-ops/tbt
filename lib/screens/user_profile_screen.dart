import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_story.dart';
import '../services/chat_service.dart';
import '../services/invite_link_service.dart';
import '../services/social_service.dart';
import '../services/story_service.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/profile_favorite_places_section.dart';
import '../widgets/public_achievement_badges.dart';
import '../widgets/profile_reward_surface.dart';
import '../widgets/story_strip.dart';
import '../widgets/user_safety_actions.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  Future<void> _shareProfile(String displayName) async {
    await InviteLinkService.instance.shareProfile(
      userId: userId,
      displayName: displayName,
    );
  }

  Future<void> _openChat(BuildContext context, String displayName) async {
    try {
      await ChatService.instance.ensureDirectThread(userId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(otherUserId: userId, otherDisplayName: displayName),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openStories(BuildContext context, List<AppStory> stories) {
    if (stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: stories)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == userId;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Profili paylaş',
            onPressed: () => _shareProfile('TBT kullanıcısı'),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          if (!isOwnProfile && currentUser != null)
            UserSafetyActions(userId: userId),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SocialService.instance.userProfile(userId),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
            return const Center(
              child: Text(
                'Kullanıcı bulunamadı.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = profileSnapshot.data!.data() ?? {};
          final displayName = (data['displayName'] ?? 'Fotoğrafçı').toString();
          final username = (data['username'] ?? displayName).toString();
          final photoUrl = (data['photoUrl'] ?? '').toString();
          final bio = (data['bio'] ?? '').toString().trim();
          final city = (data['city'] ?? '').toString().trim();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.userPosts(userId),
            builder: (context, postsSnapshot) {
              final docs = [
                ...(postsSnapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
              ];
              docs.sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];
                if (at is Timestamp && bt is Timestamp) {
                  return bt.compareTo(at);
                }
                return 0;
              });

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ProfileRewardSurface(
                      profile: data,
                      child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StreamBuilder<List<AppStory>>(
                                stream: StoryService.instance
                                    .watchActiveForUser(userId),
                                builder: (context, storySnapshot) {
                                  final stories =
                                      storySnapshot.data ?? const <AppStory>[];
                                  final hasStory = stories.isNotEmpty;
                                  return GestureDetector(
                                    onTap: hasStory
                                        ? () => _openStories(context, stories)
                                        : null,
                                    child: Container(
                                      padding: EdgeInsets.all(hasStory ? 3 : 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: hasStory
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFF42F5E9),
                                                  Color(0xFF8B5CF6),
                                                ],
                                              )
                                            : null,
                                        border: hasStory
                                            ? null
                                            : Border.all(
                                                color: const Color(0xFF555B62),
                                              ),
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          hasStory ? 2 : 0,
                                        ),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF090A0C),
                                        ),
                                        child: SizedBox(
                                          width: 86,
                                          height: 86,
                                          child: ClipOval(
                                            child: FirebaseMediaImage(
                                              imageUrl: photoUrl,
                                              fallbackStoragePaths:
                                                  FirebaseMediaImage.avatarPaths(
                                                    userId,
                                                  ),
                                              errorWidget: const ColoredBox(
                                                color: Color(0xFF1A1D20),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 42,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat(
                                      value: '${docs.length}',
                                      label: 'Gönderi',
                                    ),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance
                                          .followersCount(userId),
                                      builder: (_, snapshot) => _Stat(
                                        value: '${snapshot.data ?? 0}',
                                        label: 'Takipçi',
                                      ),
                                    ),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance
                                          .followingCount(userId),
                                      builder: (_, snapshot) => _Stat(
                                        value: '${snapshot.data ?? 0}',
                                        label: 'Takip',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${username.replaceFirst('@', '')}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          if (city.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  city,
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          ],
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              bio,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          PublicAchievementBadges(profile: data),
                          if (!isOwnProfile) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: StreamBuilder<bool>(
                                    stream: SocialService.instance.isFollowing(
                                      userId,
                                    ),
                                    builder: (_, snapshot) {
                                      final following = snapshot.data ?? false;
                                      return SizedBox(
                                        height: 44,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: following
                                                ? const Color(0xFF1A1D20)
                                                : const Color(0xFF34383D),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: const BorderSide(
                                                color: Color(0xFF353A40),
                                              ),
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              await SocialService.instance
                                                  .toggleFollow(userId);
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(e.toString()),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            following
                                                ? 'Takiptesin'
                                                : 'Takip Et',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openChat(context, displayName),
                                      icon: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 19,
                                      ),
                                      label: const Text('Mesaj At'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ProfileFavoritePlacesSection(
                      userId: userId,
                      editable: isOwnProfile,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: Color(0xFF2A2E33)),
                  ),
                  if (postsSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (docs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Henüz paylaşım yok',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(1, 2, 1, 36),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                              childAspectRatio: 1,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = docs[index];
                          final post = {...doc.data(), 'id': doc.id};
                          final imageUrl = (post['imageUrl'] ?? '').toString();
                          final storagePath = (post['storagePath'] ?? '')
                              .toString();
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(post: post),
                              ),
                            ),
                            child: Container(
                              color: const Color(0xFF121416),
                              child: imageUrl.isEmpty && storagePath.isEmpty
                                  ? const Icon(
                                      Icons.image_outlined,
                                      color: Colors.white24,
                                    )
                                  : FirebaseMediaImage(
                                      imageUrl: imageUrl,
                                      storagePath: storagePath,
                                      fit: BoxFit.cover,
                                      errorWidget: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        }, childCount: docs.length),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
