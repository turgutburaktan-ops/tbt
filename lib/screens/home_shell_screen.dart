import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
        },
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
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Harita',
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen(embedded: true);
        }
        return const ProfilePage();
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
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'En İyi Çekim Noktası',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
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
                        child: const Icon(Icons.notifications_none_rounded, size: 22),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 2),
                StreamBuilder<int>(
                  stream: AppNotificationService.instance.unreadMessageCount(),
                  builder: (_, snapshot) {
                    final count = snapshot.data ?? 0;
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF34383D)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/messages'),
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                      ),
                      label: const Text(
                        'Mesajlar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF25292E)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _HubButton(
                      icon: Icons.people_alt_outlined,
                      label: 'Takip',
                      selected: _section == 0,
                      onTap: () => setState(() => _section = 0),
                    ),
                  ),
                  Expanded(
                    child: _HubButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Noktalar',
                      selected: _section == 1,
                      onTap: () => setState(() => _section = 1),
                    ),
                  ),
                  Expanded(
                    child: _HubButton(
                      icon: Icons.groups_2_outlined,
                      label: 'Etkinlikler',
                      selected: _section == 2,
                      onTap: () => setState(() => _section = 2),
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
                FeedScreen(),
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

class _HubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HubButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF34383D) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.white54),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
