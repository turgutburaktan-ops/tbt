import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import 'activity_demand_screen.dart';
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
      _ProfileGate(),
    ];
    return Scaffold(
      backgroundColor: _Neon.bg,
      body: IndexedStack(index: _selectedIndex, children: pages),
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
      (Icons.explore_outlined, Icons.explore_rounded, 'Keşfet'),
      (Icons.photo_camera_outlined, Icons.photo_camera_rounded, 'Kamera'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Color(0xFF0C0E13),
          border: Border(top: BorderSide(color: _Neon.border)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == selectedIndex;
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
                        active: selected || index == 2,
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

class _ExploreHub extends StatelessWidget {
  const _ExploreHub();

  void _openDestination(
    BuildContext context,
    String title,
    Widget screen,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _Neon.bg,
          appBar: AppBar(
            backgroundColor: _Neon.bg,
            title: Text(title),
          ),
          body: screen,
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    const activities = <(IconData, String)>[
      (Icons.photo_camera_outlined, 'Fotoğraf'),
      (Icons.local_cafe_outlined, 'Kahve'),
      (Icons.directions_walk_rounded, 'Yürüyüş'),
      (Icons.terrain_outlined, 'Kamp'),
      (Icons.sports_basketball_outlined, 'Spor'),
      (Icons.sports_esports_outlined, 'Oyun'),
    ];
    return ColoredBox(
      color: _Neon.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Text(
                'Keşfet',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                'Yerleri, etkinlikleri ve çevrendeki insanları bul.',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _ExploreAction(
                      icon: Icons.map_outlined,
                      label: 'Harita',
                      onTap: () => _openDestination(
                        context,
                        'Harita',
                        const MapScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExploreAction(
                      icon: Icons.radar_rounded,
                      label: 'Radar',
                      onTap: () => _openDestination(
                        context,
                        'Radar',
                        const RadarScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExploreAction(
                      icon: Icons.event_outlined,
                      label: 'Etkinlik',
                      onTap: () => _openDestination(
                        context,
                        'Etkinlikler',
                        const EventsHubScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 7),
                itemCount: activities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _ActivityChip(
                    icon: activity.$1,
                    label: activity.$2,
                    onTap: () => _open(
                      context,
                      ActivityDemandScreen(initialActivity: activity.$2),
                    ),
                  );
                },
              ),
            ),
            const Expanded(child: SpotExploreScreen(embedded: true)),
          ],
        ),
      ),
    );
  }
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

class _ExploreAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExploreAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: _Neon.panel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Neon.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GradientIcon(icon: icon, size: 20),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActivityChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: _Neon.panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _Neon.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: Colors.white60),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
