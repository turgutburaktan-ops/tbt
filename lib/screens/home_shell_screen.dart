import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import 'camera_screen.dart';
import 'events_hub_screen.dart';
import 'feed_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_page_v2.dart';
import 'radar_screen.dart';
import 'spot_explore_screen_v2.dart';

class _Neon {
  static const bg = Color(0xFF06070B);
  static const panel = Color(0xFF101218);
  static const cyan = Color(0xFF42F5E9);
  static const violet = Color(0xFF8B5CF6);
  static const border = Color(0xFF292D38);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _FeedHub(),
      _ExploreHub(),
      SizedBox.shrink(),
      _NearbyHub(),
      _ProfileGate(),
    ];
    return Scaffold(
      backgroundColor: _Neon.bg,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [_Neon.cyan, _Neon.violet]),
        ),
        child: FloatingActionButton(
          heroTag: 'main-camera',
          tooltip: 'Kamera',
          elevation: 0,
          backgroundColor: _Neon.panel,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => _selectDestination(2),
          child: const Icon(Icons.photo_camera_rounded, size: 27),
        ),
      ),
      bottomNavigationBar: _SimpleNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectDestination,
      ),
    );
  }
}

class _SimpleNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SimpleNavigationBar({
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
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        color: const Color(0xFF0C0E13),
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == selectedIndex;
            if (index == 2) {
              return const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Kamera',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GradientIcon(
                        icon: selected ? item.$2 : item.$1,
                        active: selected,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
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

class _ProfileGate extends StatelessWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == null
              ? const LoginScreen(embedded: true)
              : const ProfilePage();
        },
      );
}

class _NearbyHub extends StatefulWidget {
  const _NearbyHub();

  @override
  State<_NearbyHub> createState() => _NearbyHubState();
}

class _NearbyHubState extends State<_NearbyHub> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Neon.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _GradientIcon(icon: Icons.near_me_rounded, size: 25),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Çevrende',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Yakındaki hareketleri ve etkinlikleri gör.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _Neon.panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _Neon.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeedTab(
                        label: 'Radar',
                        selected: _section == 0,
                        onTap: () => setState(() => _section = 0),
                      ),
                    ),
                    Expanded(
                      child: _FeedTab(
                        label: 'Etkinlikler',
                        selected: _section == 1,
                        onTap: () => setState(() => _section = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _section,
                children: const [
                  RadarScreen(embedded: true),
                  EventsHubScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthAwareFeed extends StatelessWidget {
  final FeedMode mode;

  const _AuthAwareFeed({required this.mode});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) => FeedScreen(
          key: ValueKey('${mode.name}-${snapshot.data?.uid ?? 'signed-out'}'),
          mode: mode,
          embedded: true,
          includeEvents: false,
        ),
      );
}

class _FeedHub extends StatefulWidget {
  const _FeedHub();

  @override
  State<_FeedHub> createState() => _FeedHubState();
}

class _FeedHubState extends State<_FeedHub> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Neon.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _HomeHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _Neon.panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _Neon.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _FeedTab(
                        label: 'Sana Özel',
                        selected: _section == 0,
                        onTap: () => setState(() => _section = 0),
                      ),
                    ),
                    Expanded(
                      child: _FeedTab(
                        label: 'Takip',
                        selected: _section == 1,
                        onTap: () => setState(() => _section = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _section,
                children: const [
                  _AuthAwareFeed(mode: FeedMode.forYou),
                  _AuthAwareFeed(mode: FeedMode.following),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [_Neon.cyan, _Neon.violet],
                ),
              ),
              child: const Text(
                'TBT',
                style: TextStyle(
                  color: Color(0xFF08090D),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'TBT',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            StreamBuilder<int>(
              stream: AppNotificationService.instance.unreadCount(),
              builder: (_, snapshot) => _HeaderAction(
                tooltip: 'Bildirimler',
                icon: Icons.notifications_none_rounded,
                count: snapshot.data ?? 0,
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ),
            StreamBuilder<int>(
              stream: AppNotificationService.instance.unreadMessageCount(),
              builder: (_, snapshot) => _HeaderAction(
                tooltip: 'Mesajlar',
                icon: Icons.chat_bubble_outline_rounded,
                count: snapshot.data ?? 0,
                onTap: () => Navigator.pushNamed(context, '/messages'),
              ),
            ),
          ],
        ),
      );
}

class _ExploreHub extends StatefulWidget {
  const _ExploreHub();

  @override
  State<_ExploreHub> createState() => _ExploreHubState();
}

class _ExploreHubState extends State<_ExploreHub> {
  String _category = 'Gezilecek Yerler';

  void _openMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _Neon.bg,
          appBar: AppBar(
            backgroundColor: _Neon.bg,
            title: const Text('Harita'),
          ),
          body: const MapScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const categories = <(IconData, String)>[
      (Icons.restaurant_outlined, 'Yeme-İçme'),
      (Icons.local_cafe_outlined, 'Kafeler'),
      (Icons.hotel_outlined, 'Oteller'),
      (Icons.landscape_outlined, 'Gezilecek Yerler'),
    ];
    return ColoredBox(
      color: _Neon.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mekanlar',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Haritayı aç',
                    onPressed: () => _openMap(context),
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Text(
                'Yeme-içme, kahve, konaklama ve gezilecek yerler.',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 7),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _ActivityChip(
                    icon: category.$1,
                    label: category.$2,
                    selected: _category == category.$2,
                    onTap: () => setState(() => _category = category.$2),
                  );
                },
              ),
            ),
            Expanded(
              child: _category == 'Gezilecek Yerler'
                  ? const SpotExploreScreen(embedded: true)
                  : _VenueCategoryPlaceholder(
                      category: _category,
                      onOpenMap: () => _openMap(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCategoryPlaceholder extends StatelessWidget {
  final String category;
  final VoidCallback onOpenMap;

  const _VenueCategoryPlaceholder({
    required this.category,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GradientIcon(icon: Icons.map_outlined, size: 42),
              const SizedBox(height: 14),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Bu kategori gerçek mekan verisiyle haritaya eklenecek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Haritayı Aç'),
              ),
            ],
          ),
        ),
      );
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int count;

  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Badge(
            isLabelVisible: count > 0,
            backgroundColor: _Neon.violet,
            label: Text(count > 99 ? '99+' : '$count'),
            child: Icon(icon, color: Colors.white70),
          ),
        ),
      );
}

class _FeedTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1C2027) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityChip({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF20242A) : _Neon.panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? _Neon.cyan.withValues(alpha: .55) : _Neon.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? _Neon.cyan : Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final double size;

  const _GradientIcon({
    required this.icon,
    this.active = true,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: active
              ? const [_Neon.cyan, _Neon.violet]
              : const [Colors.white54, Colors.white54],
        ).createShader(bounds),
        child: Icon(icon, size: size),
      );
}
