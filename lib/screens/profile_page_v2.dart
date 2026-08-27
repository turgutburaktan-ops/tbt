import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_story.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import '../services/story_service.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/story_strip.dart';
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
              child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
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
            child: Center(
              child: FirebaseMediaImage(
                imageUrl: url,
                fallbackStoragePaths:
                    FirebaseMediaImage.avatarPaths(widget.user.uid),
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(Icons.person, size: 72, color: Colors.white38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openStories(List<AppStory> stories) {
    if (stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(stories: stories),
      ),
    );
  }

  Future<void> _shareProfile(String displayName) async {
    final handle =
        displayName.trim().isEmpty ? 'Fotoğrafçı' : displayName.trim();
    await Clipboard.setData(ClipboardData(text: '@$handle'));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Profil adı panoya kopyalandı.')),
      );
  }

  Future<void> _handleProfileMenu(
    String value,
    String displayName,
    String bio,
  ) async {
    switch (value) {
      case 'edit':
        await _editProfile(displayName, bio);
        return;
      case 'share':
        await _shareProfile(displayName);
        return;
      case 'campus':
        if (mounted) Navigator.pushNamed(context, '/campus');
        return;
      case 'logout':
        await AuthService.instance.logout();
        return;
    }
  }

  void _showPostPreview(
    String imageUrl,
    String storagePath,
    List<String> fallbackStoragePaths,
  ) {
    if (imageUrl.isEmpty &&
        storagePath.isEmpty &&
        fallbackStoragePaths.isEmpty) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: FirebaseMediaImage(
                  imageUrl: imageUrl,
                  storagePath: storagePath,
                  fallbackStoragePaths: fallbackStoragePaths,
                  fit: BoxFit.contain,
                  errorWidget: const ColoredBox(
                    color: Color(0xFF121416),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
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
          final profile =
              profileSnapshot.data?.data() ?? const <String, dynamic>{};
          final displayName = (profile['displayName'] ??
                  widget.user.displayName ??
                  'Fotoğrafçı')
              .toString();
          final bio = (profile['bio'] ?? '').toString();
          final photoUrl =
              (profile['photoUrl'] ?? widget.user.photoURL ?? '').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.userPosts(widget.user.uid),
            builder: (context, postSnapshot) {
              final posts = [
                ...(postSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              ];
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
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Profil işlemleri',
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white70,
                            ),
                            color: const Color(0xFF17191C),
                            onSelected: (value) => _handleProfileMenu(
                              value,
                              displayName,
                              bio,
                            ),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Profili düzenle'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: ListTile(
                                  leading: Icon(Icons.share_outlined),
                                  title: Text('Profili paylaş'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'campus',
                                child: ListTile(
                                  leading: Icon(Icons.school_outlined),
                                  title: Text('Kampüs'),
                                ),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'logout',
                                child: ListTile(
                                  leading: Icon(Icons.logout_rounded),
                                  title: Text('Çıkış yap'),
                                ),
                              ),
                            ],
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
                                  StreamBuilder<List<AppStory>>(
                                    stream: StoryService.instance
                                        .watchActiveForUser(widget.user.uid),
                                    builder: (context, storySnapshot) {
                                      final stories = storySnapshot.data ??
                                          const <AppStory>[];
                                      final hasStory = stories.isNotEmpty;
                                      return GestureDetector(
                                        onTap: () {
                                          if (hasStory) {
                                            _openStories(stories);
                                          } else {
                                            _openProfilePhoto(
                                                photoUrl, displayName);
                                          }
                                        },
                                        child: Container(
                                          padding:
                                              EdgeInsets.all(hasStory ? 3 : 0),
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
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(
                                                hasStory ? 2 : 0),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF090A0C),
                                            ),
                                            child: CircleAvatar(
                                              radius: 47,
                                              backgroundColor:
                                                  const Color(0xFFB7BCC2),
                                              child: SizedBox(
                                                width: 86,
                                                height: 86,
                                                child: ClipOval(
                                                  child: FirebaseMediaImage(
                                                    imageUrl: photoUrl,
                                                    fallbackStoragePaths:
                                                        FirebaseMediaImage
                                                            .avatarPaths(
                                                                widget.user.uid),
                                                    errorWidget:
                                                        const ColoredBox(
                                                      color: Color(0xFF121416),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.person,
                                                          size: 48,
                                                          color: Colors.white54,
                                                        ),
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
                                  Positioned(
                                    right: -2,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _editProfile(displayName, bio),
                                      child: Container(
                                        width: 29,
                                        height: 29,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFB7BCC2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 17,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat('${posts.length}', 'Gönderi'),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance
                                          .followersCount(widget.user.uid),
                                      builder: (_, s) => _Stat(
                                        '${s.data ?? 0}',
                                        'Takipçi',
                                        onTap: () => _openFollowList(true),
                                      ),
                                    ),
                                    StreamBuilder<int>(
                                      stream: SocialService.instance
                                          .followingCount(widget.user.uid),
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
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            bio.trim().isEmpty
                                ? 'Profiline bir açıklama ekle'
                                : bio,
                            style: TextStyle(
                              color: bio.trim().isEmpty
                                  ? Colors.white38
                                  : Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF17191C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              onPressed: () =>
                                  _editProfile(displayName, bio),
                              child: const Text(
                                'Profili Düzenle',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      height: 52,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.grid_on_rounded,
                                    color: Colors.white, size: 23),
                                SizedBox(height: 10),
                                SizedBox(
                                  height: 2,
                                  width: 70,
                                  child:
                                      ColoredBox(color: Color(0xFFB7BCC2)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (postSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFB7BCC2)),
                      ),
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreatePostScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('İlk Fotoğrafını Paylaş'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(1, 2, 1, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = posts[index].data();
                            final imageUrl =
                                (data['imageUrl'] ?? '').toString();
                            final storagePath =
                                (data['storagePath'] ?? '').toString();
                            final fallbackStoragePaths =
                                FirebaseMediaImage.postPaths(
                              widget.user.uid,
                              posts[index].id,
                            );
                            final caption =
                                (data['caption'] ?? '').toString().trim();
                            final spotName =
                                (data['spotName'] ?? '').toString().trim();
                            return _PostTile(
                              imageUrl: imageUrl,
                              storagePath: storagePath,
                              fallbackStoragePaths: fallbackStoragePaths,
                              caption: caption,
                              spotName: spotName,
                              onLongPress: () => _showPostPreview(
                                imageUrl,
                                storagePath,
                                fallbackStoragePaths,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(
                                    post: {...data, 'id': posts[index].id},
                                  ),
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
      backgroundColor: const Color(0xFF090A0C),
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
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profili Düzenle',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: pick,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: photo == null ? null : FileImage(photo!),
                      child: photo == null
                          ? const Icon(Icons.add_a_photo_outlined)
                          : null,
                    ),
                  ),
                  TextButton(
                    onPressed: pick,
                    child: const Text('Profil fotoğrafı seç'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Ad / kullanıcı adı'),
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
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
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
  final String storagePath;
  final List<String> fallbackStoragePaths;
  final String caption;
  final String spotName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PostTile({
    required this.imageUrl,
    required this.storagePath,
    required this.fallbackStoragePaths,
    required this.caption,
    required this.spotName,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F0B18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: imageUrl.isEmpty &&
                storagePath.isEmpty &&
                fallbackStoragePaths.isEmpty
            ? const Center(
                child: Icon(Icons.image_outlined, color: Colors.white30),
              )
            : FirebaseMediaImage(
                imageUrl: imageUrl,
                storagePath: storagePath,
                fallbackStoragePaths: fallbackStoragePaths,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white30,
                  ),
                ),
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
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
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
