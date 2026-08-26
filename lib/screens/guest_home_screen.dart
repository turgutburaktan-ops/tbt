import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_video_player.dart';
import '../widgets/firebase_media_image.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'radar_screen.dart';
import 'spot_explore_screen_v2.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressedAt;

  Future<void> _selectDestination(int index) async {
    if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
      return;
    }
    if (mounted) setState(() => _selectedIndex = index);
  }

  void _handleSystemBack(bool keyboardOpen) {
    if (keyboardOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final now = DateTime.now();
    final pressedRecently =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    if (pressedRecently) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Uygulamadan çıkmak için geri tuşuna tekrar bas.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _GuestFeed(),
      SpotExploreScreen(embedded: true),
      SizedBox.shrink(),
      RadarScreen(embedded: true),
      LoginScreen(embedded: true),
    ];
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleSystemBack(keyboardOpen);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _selectedIndex, children: pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: keyboardOpen
            ? null
            : Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                ),
                child: FloatingActionButton(
                  heroTag: 'guest-main-camera',
                  tooltip: 'Kamera',
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: () => _selectDestination(2),
                  child: const Icon(Icons.photo_camera_rounded, size: 24),
                ),
              ),
        bottomNavigationBar: keyboardOpen
            ? null
            : _GuestNavigationBar(
                selectedIndex: _selectedIndex,
                onSelected: _selectDestination,
              ),
      ),
    );
  }
}

class _GuestNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _GuestNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
      (Icons.place_outlined, Icons.place_rounded, 'Mekanlar'),
      (Icons.circle_outlined, Icons.circle, 'Kamera'),
      (Icons.near_me_outlined, Icons.near_me_rounded, 'Çevrende'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    return SafeArea(
      top: false,
      child: BottomAppBar(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        color: const Color(0xFF0B0D12),
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        child: Row(
          children: List.generate(items.length, (index) {
            if (index == 2) {
              return const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Kamera',
                    style: TextStyle(
                      color: Color(0x75FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }
            final item = items[index];
            final selected = index == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.$2 : item.$1,
                        size: 21,
                        color: selected
                            ? Colors.white
                            : const Color(0x75FFFFFF),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0x75FFFFFF),
                          fontSize: 9.5,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GuestFeed extends StatelessWidget {
  const _GuestFeed();

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppColors.accentGradient,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'TBT',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'TBT',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: () => _openLogin(context),
                  child: const Text('Giriş yap'),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF15181B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2A2E33)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keşfetmeye hemen başla',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Kayıt olmadan gezebilirsin. Beğeni, yorum, mesaj ve paylaşım için giriş isteriz.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Giriş yap',
                  onPressed: () => _openLogin(context),
                  icon: const Icon(Icons.login_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .limit(80)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Akış şu anda yüklenemedi.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz paylaşım yok.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      Future<void>.delayed(const Duration(milliseconds: 350)),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 32),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _GuestPostCard(
                        postId: doc.id,
                        data: doc.data(),
                        onAction: () => _openLogin(context),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestPostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final VoidCallback onAction;

  const _GuestPostCard({
    required this.postId,
    required this.data,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final userId = (data['userId'] ?? '').toString();
    final userName = (data['userName'] ?? 'Topluluk üyesi').toString();
    final userPhotoUrl = (data['userPhotoUrl'] ?? data['photoUrl'] ?? '')
        .toString();
    final caption = (data['caption'] ?? '').toString();
    final spotName = (data['spotName'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final storagePath = (data['storagePath'] ?? '').toString();
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = (data['thumbnailUrl'] ?? imageUrl).toString();
    final thumbnailPath = (data['thumbnailStoragePath'] ?? storagePath)
        .toString();
    final isVideo = videoUrl.isNotEmpty || data['mediaType'] == 'video';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF24282D)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: FirebaseMediaImage(
                      imageUrl: userPhotoUrl,
                      fallbackStoragePaths: FirebaseMediaImage.avatarPaths(
                        userId,
                      ),
                      errorWidget: const ColoredBox(
                        color: Color(0xFF22262A),
                        child: Center(child: Icon(Icons.person_outline)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (spotName.isNotEmpty)
                        Text(
                          spotName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: isVideo
                ? AppVideoPlayer.network(
                    url: videoUrl,
                    autoplay: true,
                    muted: true,
                    loop: true,
                    showControls: true,
                    fit: BoxFit.cover,
                    loading: FirebaseMediaImage(
                      imageUrl: thumbnailUrl,
                      storagePath: thumbnailPath,
                      fit: BoxFit.cover,
                    ),
                  )
                : FirebaseMediaImage(
                    imageUrl: imageUrl,
                    storagePath: storagePath,
                    fallbackStoragePaths: FirebaseMediaImage.postPaths(
                      userId,
                      postId,
                    ),
                    fit: BoxFit.cover,
                    errorWidget: const ColoredBox(
                      color: Color(0xFF1A1D20),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white30,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Beğen',
                  onPressed: onAction,
                  icon: const Icon(Icons.favorite_border_rounded),
                ),
                IconButton(
                  tooltip: 'Yorum yap',
                  onPressed: onAction,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Gönder',
                  onPressed: onAction,
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
          if (caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$userName ',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: caption,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
