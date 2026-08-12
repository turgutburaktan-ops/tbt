import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/social_service.dart';
import 'create_post_screen.dart';
import 'login_screen.dart';
import 'my_posts_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFC107),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return _LoggedOutProfile(
            onLogin: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          );
        }

        return _InstagramStyleProfile(user: user);
      },
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoggedOutProfile({
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 58,
                backgroundColor: Color(0xFFFFC107),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFF171C24),
                  child: Icon(
                    Icons.person_outline,
                    size: 62,
                    color: Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Profilini görmek için giriş yap',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Fotoğraflarını paylaşmak ve topluluğa katılmak için hesabına giriş yap.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    'Giriş Yap / Kayıt Ol',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstagramStyleProfile extends StatefulWidget {
  final User user;

  const _InstagramStyleProfile({
    required this.user,
  });

  @override
  State<_InstagramStyleProfile> createState() =>
      _InstagramStyleProfileState();
}

class _InstagramStyleProfileState
    extends State<_InstagramStyleProfile> {
  @override
  void initState() {
    super.initState();
    SocialService.instance.ensureUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    final displayName =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : 'Fotoğrafçı';

    final photoUrl = user.photoURL ?? '';
    final email = user.email ?? '';

    return SafeArea(
      child: Column(
        children: [
          // ÜST BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              10,
              12,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ayarlar',
                  onPressed: () => _openSettings(context),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: SocialService.instance.userPosts(
                user.uid,
              ),
              builder: (context, postsSnapshot) {
                final docs =
                    postsSnapshot.data?.docs ?? [];

                final sortedDocs = [...docs];

                sortedDocs.sort((a, b) {
                  final aTime =
                      a.data()['createdAt'];
                  final bTime =
                      b.data()['createdAt'];

                  if (aTime is Timestamp &&
                      bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }

                  return 0;
                });

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          10,
                          18,
                          18,
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor:
                                      const Color(0xFFFFC107),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor:
                                        const Color(0xFF171C24),
                                    backgroundImage:
                                        photoUrl.isNotEmpty
                                            ? NetworkImage(
                                                photoUrl,
                                              )
                                            : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 48,
                                            color:
                                                Colors.white54,
                                          )
                                        : null,
                                  ),
                                ),

                                const SizedBox(width: 18),

                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceAround,
                                    children: [
                                      _SmallStat(
                                        value:
                                            '${sortedDocs.length}',
                                        label: 'Fotoğraf',
                                      ),
                                      StreamBuilder<int>(
                                        stream: SocialService
                                            .instance
                                            .followingCount(
                                          user.uid,
                                        ),
                                        builder: (
                                          context,
                                          snapshot,
                                        ) {
                                          return _SmallStat(
                                            value:
                                                '${snapshot.data ?? 0}',
                                            label:
                                                'Takip',
                                          );
                                        },
                                      ),
                                      StreamBuilder<int>(
                                        stream: SocialService
                                            .instance
                                            .followersCount(
                                          user.uid,
                                        ),
                                        builder: (
                                          context,
                                          snapshot,
                                        ) {
                                          return _SmallStat(
                                            value:
                                                '${snapshot.data ?? 0}',
                                            label:
                                                'Takipçi',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),

                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment:
                                    Alignment.centerLeft,
                                child: Text(
                                  email,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: Divider(
                        height: 1,
                        color: Color(0xFF242A33),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grid_on_rounded,
                              size: 20,
                              color: Color(
                                0xFFFFC107,
                              ),
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Paylaşımlarım',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    Color(0xFFFFC107),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (postsSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                Color(0xFFFFC107),
                          ),
                        ),
                      )
                    else if (sortedDocs.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(
                              32,
                            ),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons
                                      .photo_library_outlined,
                                  size: 58,
                                  color:
                                      Colors.white30,
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
                                const Text(
                                  'Henüz fotoğraf paylaşmadın',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 6,
                                ),
                                const Text(
                                  'İlk paylaşımın burada görünecek.',
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                FilledButton.icon(
                                  style: FilledButton
                                      .styleFrom(
                                    backgroundColor:
                                        const Color(
                                      0xFFFFC107,
                                    ),
                                    foregroundColor:
                                        Colors.black,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreatePostScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons
                                        .add_a_photo_outlined,
                                  ),
                                  label: const Text(
                                    'Fotoğraf Paylaş',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          3,
                          3,
                          3,
                          90,
                        ),
                        sliver: SliverGrid(
                          delegate:
                              SliverChildBuilderDelegate(
                            (context, index) {
                              final data =
                                  sortedDocs[index]
                                      .data();

                              final imageUrl =
                                  (data['imageUrl'] ??
                                          '')
                                      .toString();

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MyPostsScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  color: const Color(
                                    0xFF171C24,
                                  ),
                                  child:
                                      imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit
                                                  .cover,
                                              errorBuilder:
                                                  (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Icon(
                                                  Icons
                                                      .broken_image_outlined,
                                                  color:
                                                      Colors.white30,
                                                );
                                              },
                                            )
                                          : const Icon(
                                              Icons
                                                  .image_outlined,
                                              color:
                                                  Colors.white30,
                                            ),
                                ),
                              );
                            },
                            childCount:
                                sortedDocs.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF151A22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                const ListTile(
                  title: Text(
                    'Ayarlar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Fotoğraf Paylaş',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const CreatePostScreen(),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon:
                      Icons.photo_library_outlined,
                  title: 'Çekimlerim',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const MyPostsScreen(),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.favorite_border,
                  title: 'Kaydedilen Noktalar',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Kaydedilenlere alt menüden ulaşabilirsin.',
                        ),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon:
                      Icons.location_on_outlined,
                  title: 'Konum Tercihleri',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Konum tercihlerini harita geliştirmesinde bağlayacağız.',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(
                  color: Color(0xFF242A33),
                ),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Çıkış Yap',
                  danger: true,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await AuthService.instance.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String value;
  final String label;

  const _SmallStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: danger
            ? Colors.redAccent
            : const Color(0xFFFFC107),
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              danger ? Colors.redAccent : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white30,
      ),
      onTap: onTap,
    );
  }
}
