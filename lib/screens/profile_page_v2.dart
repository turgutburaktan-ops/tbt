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
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/story_strip.dart';
import 'create_post_screen.dart';
import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';
import 'user_statistics_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
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

  bool _campusEligible(Map<String, dynamic> profile) {
    const activeYears = <String>{'Hazırlık', '1', '2', '3', '4', '5', '6'};
    final university = (profile['university'] ?? '').toString().trim();
    final classYear = (profile['classYear'] ?? '').toString().trim();
    return university.isNotEmpty && activeYears.contains(classYear);
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

  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserStatisticsScreen(userId: widget.user.uid),
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
      MaterialPageRoute(builder: (_) => StoryViewerScreen(stories: stories)),
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
      case 'stats':
        _openStatistics();
        return;
      case 'share':
        await _shareProfile(displayName);
        return;
      case 'messages':
        if (mounted) Navigator.pushNamed(context, '/messages');
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
                    color: AppColors.surface,
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
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.35,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Profil işlemleri',
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white70,
                            ),
                            color: AppColors.surfaceAlt,
                            onSelected: (value) => _handleProfileMenu(
                              value,
                              displayName,
                              bio,
                            ),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'stats',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.query_stats_rounded),
                                  title: Text('İstatistikler'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Profili düzenle'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.share_outlined),
                                  title: Text('Profili paylaş'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'messages',
                                child: ListTile(
                                  dense: true,
                                  leading:
                                      Icon(Icons.chat_bubble_outline_rounded),
                                  title: Text('Mesajlar'),
                                ),
                              ),
                              if (_campusEligible(profile))
                                const PopupMenuItem(
                                  value: 'campus',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.school_outlined),
                                    title: Text('Kampüs'),
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'logout',
                                child: ListTile(
                                  dense: true,
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
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
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
                                              photoUrl,
                                              displayName,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding:
                                              EdgeInsets.all(hasStory ? 2.5 : 0),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: hasStory
                                                ? AppColors.accentGradient
                                                : null,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(
                                                hasStory ? 2 : 0),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.background,
                                            ),
                                            child: CircleAvatar(
                                              radius: 41,
                                              backgroundColor:
                                                  AppColors.surfaceStrong,
                                              child: SizedBox(
                                                width: 76,
                                                height: 76,
                                                child: ClipOval(
                                                  child: FirebaseMediaImage(
                                                    imageUrl: photoUrl,
                                                    fallbackStoragePaths:
                                                        FirebaseMediaImage
                                                            .avatarPaths(
                                                                widget.user.uid),
                                                    errorWidget:
                                                        const ColoredBox(
                                                      color: AppColors.surface,
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.person,
                                                          size: 42,
                                                          color: Color(0x75FFFFFF),
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
                                    right: -1,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _editProfile(displayName, bio),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceStrong,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.cyan,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 14,
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat(
                                      '${posts.length}',
                                      'Gönderi',
                                      onTap: _openStatistics,
                                    ),
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
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bio.trim().isEmpty
                                ? 'Profiline bir açıklama ekle'
                                : bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: bio.trim().isEmpty
                                  ? const Color(0x52FFFFFF)
                                  : Colors.white60,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _editProfile(displayName, bio),
                                  icon: const Icon(Icons.edit_outlined, size: 17),
                                  label: const Text('Profili Düzenle'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openStatistics,
                                  icon: const Icon(Icons.query_stats_rounded, size: 17),
                                  label: const Text('İstatistikler'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 84,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.grid_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(height: 7),
                              SizedBox(
                                height: 2,
                                width: 50,
                                child: ColoredBox(color: AppColors.cyan),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (postSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 34,
                                color: Colors.white30,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Henüz gönderin yok',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'İlk fotoğrafını paylaşarak profilini doldur.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreatePostScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('İlk Fotoğrafını Paylaş'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 92),
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
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
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
              18,
              12,
              18,
              MediaQuery.of(context).viewInsets.bottom + 20,
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
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: pick,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: AppColors.surfaceStrong,
                      backgroundImage: photo == null ? null : FileImage(photo!),
                      child: photo == null
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.cyan,
                            )
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: bioController,
                    maxLength: 160,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
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
      color: AppColors.surface,
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
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 10.8),
        ),
      ],
    );
    return onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.all(5), child: child),
          );
  }
}