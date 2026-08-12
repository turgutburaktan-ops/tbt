import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    final isOwnProfile =
        currentUser?.uid == userId;

    return Scaffold(
      backgroundColor:
          const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1117),
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: const Text(
          'Profil',
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: SocialService.instance
            .userProfile(userId),
        builder: (
          context,
          profileSnapshot,
        ) {
          if (profileSnapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFFFFC107),
              ),
            );
          }

          if (!profileSnapshot.hasData ||
              !profileSnapshot
                  .data!.exists) {
            return const Center(
              child: Text(
                'Kullanıcı bulunamadı.',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            );
          }

          final data =
              profileSnapshot.data!.data() ??
                  {};

          final displayName =
              (data['displayName'] ??
                      'Fotoğrafçı')
                  .toString();

          final photoUrl =
              (data['photoUrl'] ?? '')
                  .toString();

          final email =
              (data['email'] ?? '')
                  .toString();

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              40,
            ),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor:
                      const Color(
                    0xFFFFC107,
                  ),
                  child: CircleAvatar(
                    radius: 49,
                    backgroundColor:
                        const Color(
                      0xFF171C24,
                    ),
                    backgroundImage:
                        photoUrl.isNotEmpty
                            ? NetworkImage(
                                photoUrl,
                              )
                            : null,
                    child: photoUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 56,
                            color:
                                Colors.white54,
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              Center(
                child: Text(
                  displayName,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              if (email.isNotEmpty) ...[
                const SizedBox(
                  height: 5,
                ),
                Center(
                  child: Text(
                    email,
                    style:
                        const TextStyle(
                      color:
                          Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 24,
              ),

              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<
                        int>(
                      stream: SocialService
                          .instance
                          .followersCount(
                        userId,
                      ),
                      builder: (
                        context,
                        snapshot,
                      ) {
                        return _StatBox(
                          value:
                              '${snapshot.data ?? 0}',
                          label:
                              'Takipçi',
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: StreamBuilder<
                        int>(
                      stream: SocialService
                          .instance
                          .followingCount(
                        userId,
                      ),
                      builder: (
                        context,
                        snapshot,
                      ) {
                        return _StatBox(
                          value:
                              '${snapshot.data ?? 0}',
                          label:
                              'Takip',
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                      stream:
                          SocialService
                              .instance
                              .userPosts(
                        userId,
                      ),
                      builder: (
                        context,
                        snapshot,
                      ) {
                        return _StatBox(
                          value:
                              '${snapshot.data?.docs.length ?? 0}',
                          label:
                              'Çekim',
                        );
                      },
                    ),
                  ),
                ],
              ),

              if (!isOwnProfile) ...[
                const SizedBox(
                  height: 18,
                ),

                StreamBuilder<bool>(
                  stream: SocialService
                      .instance
                      .isFollowing(
                    userId,
                  ),
                  builder: (
                    context,
                    snapshot,
                  ) {
                    final following =
                        snapshot.data ??
                            false;

                    return SizedBox(
                      height: 52,
                      child:
                          FilledButton(
                        style:
                            FilledButton
                                .styleFrom(
                          backgroundColor:
                              following
                                  ? const Color(
                                      0xFF222831,
                                    )
                                  : const Color(
                                      0xFFFFC107,
                                    ),
                          foregroundColor:
                              following
                                  ? Colors.white
                                  : Colors.black,
                        ),
                        onPressed:
                            () async {
                          try {
                            await SocialService
                                .instance
                                .toggleFollow(
                              userId,
                            );
                          } catch (e) {
                            if (!context
                                .mounted) {
                              return;
                            }

                            ScaffoldMessenger
                                    .of(
                                  context,
                                )
                                .showSnackBar(
                              SnackBar(
                                content:
                                    Text(
                                  e.toString(),
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          following
                              ? 'Takiptesin'
                              : 'Takip Et',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(
                height: 28,
              ),

              const Row(
                children: [
                  Icon(
                    Icons.grid_on,
                    color: Color(
                      0xFFFFC107,
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    'Paylaşımlar',
                    style:
                        TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              StreamBuilder<
                  QuerySnapshot<
                      Map<String,
                          dynamic>>>(
                stream: SocialService
                    .instance
                    .userPosts(
                  userId,
                ),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot
                          .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Padding(
                      padding:
                          EdgeInsets.all(
                        30,
                      ),
                      child: Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              Color(
                            0xFFFFC107,
                          ),
                        ),
                      ),
                    );
                  }

                  final docs =
                      snapshot.data
                              ?.docs ??
                          [];

                  docs.sort(
                    (a, b) {
                      final aTime =
                          a.data()[
                              'createdAt'];
                      final bTime =
                          b.data()[
                              'createdAt'];

                      if (aTime
                              is Timestamp &&
                          bTime
                              is Timestamp) {
                        return bTime
                            .compareTo(
                          aTime,
                        );
                      }

                      return 0;
                    },
                  );

                  if (docs.isEmpty) {
                    return Container(
                      padding:
                          const EdgeInsets
                              .all(
                        30,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFF151A22,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                      ),
                      child:
                          const Column(
                        children: [
                          Icon(
                            Icons
                                .photo_library_outlined,
                            color:
                                Colors.white38,
                            size: 48,
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Henüz paylaşım yok',
                            style:
                                TextStyle(
                              color:
                                  Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView
                      .builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount:
                        docs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          3,
                      crossAxisSpacing:
                          4,
                      mainAxisSpacing:
                          4,
                    ),
                    itemBuilder:
                        (
                      context,
                      index,
                    ) {
                      final data =
                          docs[index]
                              .data();

                      final imageUrl =
                          (data['imageUrl'] ??
                                  '')
                              .toString();

                      return ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                        child:
                            imageUrl
                                    .isNotEmpty
                                ? Image
                                    .network(
                                    imageUrl,
                                    fit: BoxFit
                                        .cover,
                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        color:
                                            const Color(
                                          0xFF171C24,
                                        ),
                                        child:
                                            const Icon(
                                          Icons
                                              .broken_image_outlined,
                                          color:
                                              Colors.white38,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color:
                                        const Color(
                                      0xFF171C24,
                                    ),
                                    child:
                                        const Icon(
                                      Icons
                                          .image_outlined,
                                      color:
                                          Colors.white38,
                                    ),
                                  ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFF151A22,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              color:
                  Color(
                0xFFFFC107,
              ),
              fontSize: 21,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
