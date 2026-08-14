import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import 'create_post_screen.dart';
import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';

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
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return SafeArea(
            child: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Giriş Yap / Kayıt Ol'),
              ),
            ),
          );
        }
        return _ProfileBody(user: user);
      },
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final User user;
  const _ProfileBody({required this.user});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  @override
  void initState() {
    super.initState();
    SocialService.instance.ensureUserProfile();
  }

  void _openFollowList(bool followers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: widget.user.uid,
          followers: followers,
        ),
      ),
    );
  }

  void _openProfilePhoto(String url, String name) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(name),
          ),
          body: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            clipBehavior: Clip.none,
            child: Center(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SocialService.instance.userProfile(widget.user.uid),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data() ?? const <String, dynamic>{};
          final displayName = (profile['displayName'] ?? widget.user.displayName ?? 'Fotoğrafçı').toString();
          final bio = (profile['bio'] ?? '').toString();
          final photoUrl = (profile['photoUrl'] ?? widget.user.photoURL ?? '').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.userPosts(widget.user.uid),
            builder: (context, postSnapshot) {
              final posts = [...(postSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
              posts.sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];
                if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                return 0;
              });

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editProfile(displayName, bio),
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6)),
                          ),
                          IconButton(
                            onPressed: AuthService.instance.logout,
                            icon: const Icon(Icons.logout_rounded, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GestureDetector(
                                    onTap: () => _openProfilePhoto(photoUrl, displayName),
                                    child: CircleAvatar(
                                      radius: 47,
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      child: CircleAvatar(
                                        radius: 43,
                                        backgroundColor: const Color(0xFF141126),
                                        backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                                        child: photoUrl.isEmpty
                                            ? const Icon(Icons.person, size: 48, color: Colors.white54)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () => _editProfile(displayName, bio),
                                      child: Container(
                                        width: 29,
                                        height: 29,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF8B5CF6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add_a_photo_outlined, size: 17, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat('${posts.length}', 'Gönderi'),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance.followersCount(widget.user.uid),
                                      builder: (_, s) => _Stat(
                                        '${s.data ?? 0}',
                                        'Takipçi',
                                        onTap: () => _openFollowList(true),
                                      ),
                                    ),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance.followingCount(widget.user.uid),
                                      builder: (_, s) => _Stat(
                                        '${s.data ?? 0}',
                                        'Takip',
                                        onTap: () => _openFollowList(false),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(
                            bio.trim().isEmpty ? 'Profiline bir açıklama ekle' : bio,
                            style: TextStyle(
                              color: bio.trim().isEmpty ? Colors.white38 : Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: () => _editProfile(displayName, bio),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Profili Düzenle'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1, color: Colors.white12)),
                  if (postSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('İlk Fotoğrafını Paylaş'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = posts[index].data();
                            final imageUrl = (data['imageUrl'] ?? '').toString();
                            final caption = (data['caption'] ?? '').toString().trim();
                            final spotName = (data['spotName'] ?? '').toString().trim();
                            return _PostTile(
                              imageUrl: imageUrl,
                              caption: caption,
                              spotName: spotName,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PostDetailScreen(post: data)),
                              ),
                            );
                          },
                          childCount: posts.length,
                        ),
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

  Future<void> _editProfile(String displayName, String bio) async {
    final nameController = TextEditingController(text: displayName);
    final bioController = TextEditingController(text: bio);
    File? photo;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090812),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pick() async {
            final image = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
              maxWidth: 1200,
            );
            if (image != null) setSheetState(() => photo = File(image.path));
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Profili Düzenle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  GestureDetector(
                    onTap: pick,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: photo == null ? null : FileImage(photo!),
                      child: photo == null ? const Icon(Icons.add_a_photo_outlined) : null,
                    ),
                  ),
                  TextButton(onPressed: pick, child: const Text('Profil fotoğrafı seç')),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad / kullanıcı adı'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioController,
                    maxLength: 160,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                await ProfileService.instance.updateProfile(
                                  displayName: nameController.text,
                                  bio: bioController.text,
                                  photo: photo,
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                              } catch (_) {
                                setSheetState(() => saving = false);
                              }
                            },
                      child: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    nameController.dispose();
    bioController.dispose();
  }
}

class _PostTile extends StatelessWidget {
  final String imageUrl;
  final String caption;
  final String spotName;
  final VoidCallback onTap;

  const _PostTile({
    required this.imageUrl,
    required this.caption,
    required this.spotName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141126),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0x888B5CF6),
          width: 1.4,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFF10151C),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.image_outlined, color: Colors.white30)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white30,
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption.isEmpty ? 'Fotoğraf' : caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          spotName.isEmpty ? 'Konum yok' : spotName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _Stat(this.value, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
    return onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.all(6), child: child),
          );
  }
}
