import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/profile_favorite_places_section.dart';
import 'camera_screen.dart';
import 'create_post_screen.dart';
import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';
import 'user_statistics_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: AuthService.instance.authStateChanges,
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
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

class _ProfileBody extends StatefulWidget {
  final User user;
  const _ProfileBody({required this.user});
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  String _contentTab = 'all';
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    SocialService.instance.ensureUserProfile();
  }

  String _typeLabel(String type) => switch (type) {
    'creator' => 'İçerik Üreticisi',
    'business_owner' => 'İşletme Sahibi',
    'venue_manager' => 'Mekan Yöneticisi',
    'organizer' => 'Organizatör',
    _ => 'Kişisel',
  };

  IconData _typeIcon(String type) => switch (type) {
    'creator' => Icons.auto_awesome_outlined,
    'business_owner' => Icons.business_center_outlined,
    'venue_manager' => Icons.storefront_outlined,
    'organizer' => Icons.event_available_outlined,
    _ => Icons.person_outline_rounded,
  };

  void _openFollowList(bool followers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowListScreen(userId: widget.user.uid, followers: followers),
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

  Future<void> _shareProfile(String displayName, String username) async {
    final handle = username.trim().isNotEmpty
        ? username.trim()
        : displayName.trim();
    await Clipboard.setData(
      ClipboardData(text: handle.startsWith('@') ? handle : '@$handle'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil kullanıcı adı kopyalandı.')),
    );
  }

  Future<void> _menu(String value, Map<String, dynamic> profile) async {
    switch (value) {
      case 'settings':
        if (mounted) Navigator.pushNamed(context, '/settings');
        return;
      case 'stats':
        _openStatistics();
        return;
      case 'messages':
        if (mounted) Navigator.pushNamed(context, '/messages');
        return;
      case 'search':
        if (mounted) Navigator.pushNamed(context, '/search');
        return;
      case 'business':
        if (mounted) Navigator.pushNamed(context, '/business');
        return;
      case 'safety':
        if (mounted) Navigator.pushNamed(context, '/safety-privacy');
        return;
      case 'share':
        await _shareProfile(
          (profile['displayName'] ?? widget.user.displayName ?? '').toString(),
          (profile['username'] ?? '').toString(),
        );
        return;
      case 'logout':
        await AuthService.instance.logout();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SocialService.instance.userProfile(widget.user.uid),
        builder: (context, profileSnapshot) {
          final profile =
              profileSnapshot.data?.data() ?? const <String, dynamic>{};
          final name =
              (profile['displayName'] ??
                      widget.user.displayName ??
                      'TBT Kullanıcısı')
                  .toString();
          final username = (profile['username'] ?? '').toString();
          final bio = (profile['bio'] ?? '').toString();
          final photo = (profile['photoUrl'] ?? widget.user.photoURL ?? '')
              .toString();
          final type = (profile['profileType'] ?? 'personal').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: SocialService.instance.userPosts(widget.user.uid),
            builder: (context, postSnapshot) {
              final posts = [
                ...(postSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
              ];
              posts.sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];
                if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                return 0;
              });
              final visiblePosts = posts.where((post) {
                final data = post.data();
                final isVideo =
                    (data['mediaType'] ?? '').toString() == 'video' ||
                    (data['videoUrl'] ?? '').toString().isNotEmpty;
                if (_contentTab == 'photos') return !isVideo;
                if (_contentTab == 'videos') return isVideo;
                return true;
              }).toList();
              final visible = posts.where((doc) {
                final data = doc.data();
                final isVideo =
                    (data['mediaType'] ?? '').toString() == 'video' ||
                    (data['videoUrl'] ?? '').toString().isNotEmpty;
                if (_tab == 'photos') return !isVideo;
                if (_tab == 'videos') return isVideo;
                return true;
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _topBar(name, profile, type)),
                  SliverToBoxAdapter(
                    child: _identity(
                      name,
                      username,
                      bio,
                      photo,
                      type,
                      posts.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: _typeModule(type)),
                  SliverToBoxAdapter(
                    child: ProfileFavoritePlacesSection(
                      userId: widget.user.uid,
                      editable: true,
                    ),
                  ),
                  SliverToBoxAdapter(child: _contentTabs()),
                  if (postSnapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _empty())
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
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = visible[index];
                          final data = doc.data();
                          final imageUrl =
                              (data['imageUrl'] ??
                                      data['thumbnailUrl'] ??
                                      data['coverUrl'] ??
                                      '')
                                  .toString();
                          final storagePath = (data['storagePath'] ?? '')
                              .toString();
                          final isVideo =
                              (data['mediaType'] ?? '').toString() == 'video' ||
                              (data['videoUrl'] ?? '').toString().isNotEmpty;
                          return _PostTile(
                            imageUrl: imageUrl,
                            storagePath: storagePath,
                            fallbackStoragePaths: FirebaseMediaImage.postPaths(
                              widget.user.uid,
                              doc.id,
                            ),
                            isVideo: isVideo,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(
                                  post: {...data, 'id': doc.id},
                                ),
                              ),
                            ),
                          );
                        }, childCount: visible.length),
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

  Widget _topBar(String name, Map<String, dynamic> profile, String type) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ayarlar',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            ),
            PopupMenuButton<String>(
              tooltip: 'Profil işlemleri',
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
              color: AppColors.surfaceAlt,
              onSelected: (v) => _menu(v, profile),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Ayarlar'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.query_stats_rounded),
                    title: Text('İstatistikler'),
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
                    leading: Icon(Icons.chat_bubble_outline_rounded),
                    title: Text('Mesajlar'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.search_rounded),
                    title: Text('TBT’de Ara'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'safety',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Gizlilik ve Güvenlik'),
                  ),
                ),
                if (type == 'business_owner' || type == 'venue_manager')
                  const PopupMenuItem(
                    value: 'business',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.storefront_outlined),
                      title: Text('Yönettiğim Mekanlar'),
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
      );

  Widget _identity(
    String name,
    String username,
    String bio,
    String photo,
    String type,
    int postCount,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: AppColors.surfaceStrong,
                  child: ClipOval(
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: FirebaseMediaImage(
                        imageUrl: photo,
                        fallbackStoragePaths: FirebaseMediaImage.avatarPaths(
                          widget.user.uid,
                        ),
                        fit: BoxFit.cover,
                        errorWidget: const ColoredBox(
                          color: AppColors.surface,
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: 42,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: 0,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CameraScreen(storyMode: true),
                      ),
                    ),
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceStrong,
                        border: Border.all(color: AppColors.cyan),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 18,
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('$postCount', 'Gönderi', onTap: _openStatistics),
                  StreamBuilder<int>(
                    stream: SocialService.instance.followersCount(
                      widget.user.uid,
                    ),
                    builder: (_, s) => _Stat(
                      '${s.data ?? 0}',
                      'Takipçi',
                      onTap: () => _openFollowList(true),
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: SocialService.instance.followingCount(
                      widget.user.uid,
                    ),
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
        const SizedBox(height: 13),
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_typeIcon(type), size: 12, color: AppColors.cyan),
                  const SizedBox(width: 4),
                  Text(
                    _typeLabel(type),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (username.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            username.startsWith('@') ? username : '@$username',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          bio.trim().isEmpty ? 'Profiline bir açıklama ekle' : bio,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: bio.trim().isEmpty ? Colors.white30 : Colors.white70,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editProfile(name, bio),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Profili Düzenle'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: const Icon(Icons.settings_outlined, size: 17),
                label: const Text('Ayarlar'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _typeModule(String type) {
    if (type == 'business_owner' || type == 'venue_manager') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: _ModuleCard(
          icon: Icons.storefront_outlined,
          title: 'Yönettiğim Mekanlar',
          subtitle: 'Mekan profilleri, menü, kampanya ve etkinlik yönetimi',
          onTap: () => Navigator.pushNamed(context, '/business'),
        ),
      );
    }
    if (type == 'organizer') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: _ModuleCard(
          icon: Icons.event_available_outlined,
          title: 'Organizatör Profili',
          subtitle: 'Etkinliklerin ve içeriklerin profilinde öne çıkar',
          onTap: _openStatistics,
        ),
      );
    }
    if (type == 'creator') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: _ModuleCard(
          icon: Icons.auto_awesome_outlined,
          title: 'İçerik Üreticisi',
          subtitle: 'İçerik performansını ve büyümeni takip et',
          onTap: _openStatistics,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _contentTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'all',
          icon: Icon(Icons.grid_on_rounded),
          label: Text('Tümü'),
        ),
        ButtonSegment(
          value: 'photos',
          icon: Icon(Icons.photo_outlined),
          label: Text('Fotoğraf'),
        ),
        ButtonSegment(
          value: 'videos',
          icon: Icon(Icons.play_circle_outline_rounded),
          label: Text('Video'),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (v) => setState(() => _tab = v.first),
    ),
  );

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 38,
            color: Colors.white24,
          ),
          const SizedBox(height: 10),
          const Text(
            'Henüz içerik yok',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Fotoğraf veya video paylaşarak profilini oluşturmaya başla.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('İçerik Paylaş'),
          ),
        ],
      ),
    ),
  );

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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          Future<void> pick() async {
            final image = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
              maxWidth: 1200,
            );
            if (image != null) setSheet(() => photo = File(image.path));
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: pick,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.surfaceStrong,
                        backgroundImage: photo == null
                            ? null
                            : FileImage(photo!),
                        child: photo == null
                            ? const Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.cyan,
                              )
                            : null,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: pick,
                    child: const Text('Profil fotoğrafı seç'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad / kullanıcı adı',
                    ),
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
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await ProfileService.instance.updateProfile(
                                displayName: nameController.text,
                                bio: bioController.text,
                                photo: photo,
                              );
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext);
                            } catch (_) {
                              setSheet(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
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

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceStrong,
        child: Icon(icon, color: AppColors.cyan),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _PostTile extends StatelessWidget {
  final String imageUrl;
  final String storagePath;
  final List<String> fallbackStoragePaths;
  final bool isVideo;
  final VoidCallback onTap;
  const _PostTile({
    required this.imageUrl,
    required this.storagePath,
    required this.fallbackStoragePaths,
    required this.isVideo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FirebaseMediaImage(
            imageUrl: imageUrl,
            storagePath: storagePath,
            fallbackStoragePaths: fallbackStoragePaths,
            fit: BoxFit.cover,
            errorWidget: const Center(
              child: Icon(Icons.image_outlined, color: Colors.white30),
            ),
          ),
          if (isVideo)
            const Positioned(
              right: 6,
              top: 6,
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
        ],
      ),
    ),
  );
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
          style: const TextStyle(color: Colors.white54, fontSize: 10.8),
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
