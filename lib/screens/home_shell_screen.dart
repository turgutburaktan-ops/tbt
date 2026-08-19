import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import 'activity_demand_screen.dart';
import 'camera_screen.dart';
import 'feed_screen.dart';
import 'library_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_page_v2.dart';
import 'social_events_screen.dart';
import 'spot_explore_screen_v2.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _CommunityHub(),
      const MapScreen(),
      const LibraryScreen(),
      const _ProfileGate(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF090A0C),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Kamera',
        backgroundColor: const Color(0xFF1A1D20),
        foregroundColor: Colors.white,
        elevation: 1,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFF4A4F55), width: 1.2),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        ),
        child: const Icon(Icons.photo_camera_outlined, size: 22),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFF0F1113),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Kaydedilenler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const SafeArea(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) return const LoginScreen(embedded: true);
        return const ProfilePage();
      },
    );
  }
}

class _AuthAwareFeed extends StatelessWidget {
  final FeedMode mode;
  const _AuthAwareFeed({required this.mode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        return FeedScreen(
          key: ValueKey('${mode.name}-${snapshot.data?.uid ?? 'signed-out'}'),
          mode: mode,
          embedded: true,
        );
      },
    );
  }
}

class _CommunityHub extends StatefulWidget {
  const _CommunityHub();

  @override
  State<_CommunityHub> createState() => _CommunityHubState();
}

class _CommunityHubState extends State<_CommunityHub> {
  int _section = 0;
  static const _accent = Color(0xFFB7BCC2);

  void _openActivity(String label) {
    if (label == 'Keşfet') {
      setState(() => _section = 2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDemandScreen(initialActivity: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDailyHeader = _section <= 1;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bugün ne yapıyoruz?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('İnsanları, anları ve yakınındaki hayatı keşfet.',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Kampüs',
                  onPressed: () {
                    if (FirebaseAuth.instance.currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kampüs alanı için giriş yapmalısın.')),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, '/campus');
                  },
                  icon: const Icon(Icons.school_outlined),
                ),
                IconButton(
                  tooltip: 'Bildirimler',
                  onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  icon: StreamBuilder<int>(
                    stream: AppNotificationService.instance.unreadCount(),
                    builder: (_, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.notifications_none_rounded),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Mesajlar',
                  onPressed: () => Navigator.pushNamed(context, '/messages'),
                  icon: StreamBuilder<int>(
                    stream: AppNotificationService.instance.unreadMessageCount(),
                    builder: (_, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (showDailyHeader)
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                children: [
                  _ActivityChip(icon: Icons.photo_camera_outlined, label: 'Fotoğraf', onTap: () => _openActivity('Fotoğraf')),
                  _ActivityChip(icon: Icons.local_cafe_outlined, label: 'Kahve', onTap: () => _openActivity('Kahve')),
                  _ActivityChip(icon: Icons.directions_walk_rounded, label: 'Yürüyüş', onTap: () => _openActivity('Yürüyüş')),
                  _ActivityChip(icon: Icons.terrain_outlined, label: 'Kamp', onTap: () => _openActivity('Kamp')),
                  _ActivityChip(icon: Icons.sports_basketball_outlined, label: 'Spor', onTap: () => _openActivity('Spor')),
                  _ActivityChip(icon: Icons.sports_esports_outlined, label: 'Oyun', onTap: () => _openActivity('Oyun')),
                  _ActivityChip(icon: Icons.place_outlined, label: 'Keşfet', onTap: () => _openActivity('Keşfet')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF25292E)),
              ),
              child: Row(
                children: [
                  Expanded(child: _HubButton(label: 'Sana Özel', selected: _section == 0, onTap: () => setState(() => _section = 0))),
                  Expanded(child: _HubButton(label: 'Takip', selected: _section == 1, onTap: () => setState(() => _section = 1))),
                  Expanded(child: _HubButton(label: 'Noktalar', selected: _section == 2, onTap: () => setState(() => _section = 2))),
                  Expanded(child: _HubButton(label: 'Etkinlik', selected: _section == 3, onTap: () => setState(() => _section = 3))),
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
                SpotExploreScreen(),
                SocialEventsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActivityChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: const Color(0xFF15181B),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 82,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF262B30)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21, color: _CommunityHubState._accent),
                  const SizedBox(height: 5),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _HubButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HubButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF34383D) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}
