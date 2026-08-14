import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/favorites_service.dart';
import '../widgets/spot_image.dart';
import 'camera_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'profile_page.dart';
import 'social_events_screen.dart';
import 'spot_detail_screen.dart';
import 'spot_explore_screen.dart';

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
      const _SavedSpotsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
        },
        child: const Icon(Icons.camera_alt_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFF11151C),
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
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
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
                  tooltip: 'Mesajlar',
                  onPressed: () => Navigator.pushNamed(context, '/messages'),
                  icon: const Badge(
                    smallSize: 7,
                    child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFC107)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF151A22),
                borderRadius: BorderRadius.circular(17),
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
                      icon: Icons.photo_camera_back_outlined,
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
      color: selected ? const Color(0xFFFFC107) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.black : Colors.white60),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
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

class _SavedSpotsPage extends StatelessWidget {
  const _SavedSpotsPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<PhotoSpot>>(
        valueListenable: FavoritesService.savedSpots,
        builder: (context, spots, _) {
          if (spots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 60, color: Colors.white30),
                    SizedBox(height: 14),
                    Text('Henüz kaydettiğin bir nokta yok', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'Beğendiğin çekim noktalarını detay ekranından kaydedebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            itemCount: spots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final spot = spots[index];
              return Card(
                color: const Color(0xFF151A22),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: SpotImage(
                    spot: spot,
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${spot.city} • ⭐ ${spot.rating}'),
                  trailing: IconButton(
                    tooltip: 'Kaydı kaldır',
                    onPressed: () => FavoritesService.toggle(spot),
                    icon: const Icon(Icons.favorite, color: Color(0xFFFFC107)),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
