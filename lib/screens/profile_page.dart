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
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const SafeArea(child: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))));
        }
        final user = auth.data;
        if (user == null) {
          return SafeArea(
            child: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
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
  OverlayEntry? _preview;

  @override
  void initState() {
    super.initState();
    SocialService.instance.ensureUserProfile();
  }

  @override
  void dispose() {
    _closePreview();
    super.dispose();
  }

  void _openProfilePhoto(String url, String name) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(name)),
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

  void _openFollowList({required bool followers}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FollowListScreen(userId: widget.user.uid, followers: followers)),
    );
  }

  void _showPreview(String imageUrl) {
    if (imageUrl.isEmpty || _preview != null || !mounted) return;

    _preview = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black.withOpacity(.72),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePreview,
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 56, 18, 56),
                  child: Material(
                    color: Colors.transparent,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      panEnabled: true,
                      scaleEnabled: true,
                      clipBehavior: Clip.none,
                      boundaryMargin: const EdgeInsets.all(140),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF11151C),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(blurRadius: 28, spreadRadius: 4, color: Colors.black54)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 280,
                              height: 280,
                              child: Center(child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.white38)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: _closePreview,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_preview!);
  }

  void _closePreview() {
    _preview?.remove();
    _preview = null;
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
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFC107)),
                          ),
                          IconButton(
                            onPressed: () => AuthService.instance.logout(),
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
                                      backgroundColor: const Color(0xFFFFC107),
                                      child: CircleAvatar(
                                        radius: 43,
                                        backgroundColor: const Color(0xFF171C24),
                                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                        child: photoUrl.isEmpty ? const Icon(Icons.person, size: 48, color: Colors.white54) : null,
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
                                        decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                                        child: const Icon(Icons.add_a_photo_outlined, size: 17, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat('${posts.length}', 'Gönderi'),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance.followersCount(widget.user.uid),
                                      builder: (_, s) => _Stat('${s.data ?? 0}', 'Takipçi', onTap: () => _openFollowList(followers: true)),
                                    ),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance.followingCount(widget.user.uid),
                                      builder: (_, s) => _Stat('${s.data ?? 0}', 'Takip', onTap: () => _openFollowList(followers: false)),
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
                            style: TextStyle(color: bio.trim().isEmpty ? Colors.white38 : Colors.white70, height: 1.4),
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
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('İlk Fotoğrafını Paylaş'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = posts[index].data();
                            final imageUrl = (data['imageUrl'] ?? '').toString();
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: data))),
                              onLongPress: () => _showPreview(imageUrl),
                              child: Container(
                                color: const Color(0xFF171C24),
                                child: imageUrl.isEmpty
                                    ? const Icon(Icons.image_outlined, color: Colors.white30)
                                    : Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.low,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white30),
                                      ),
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
      backgroundColor: const Color(0xFF0D1117),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pick() async {
            final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1200);
            if (image != null) setSheetState(() => photo = File(image.path));
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(children: [
                    const Expanded(child: Text('Profili Düzenle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: pick,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFF202833),
                      backgroundImage: photo != null ? FileImage(photo!) : null,
                      child: photo == null ? const Icon(Icons.add_a_photo_outlined, size: 34, color: Color(0xFFFFC107)) : null,
                    ),
                  ),
                  TextButton(onPressed: pick, child: const Text('Profil fotoğrafı seç')),
                  const SizedBox(height: 8),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ad / kullanıcı adı')),
                  const SizedBox(height: 12),
                  TextField(controller: bioController, maxLength: 160, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Açıklama')),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
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
                              } catch (e) {
                                setSheetState(() => saving = false);
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                  );
                                }
                              }
                            },
                      child: Text(saving ? 'Kaydediliyor...' : 'Kaydet', style: const TextStyle(fontWeight: FontWeight.w800)),
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
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
    return onTap == null
        ? child
        : InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: child),
          );
  }
}
