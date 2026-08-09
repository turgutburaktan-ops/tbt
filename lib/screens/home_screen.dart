import '../services/favorites_service.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';
import 'map_screen.dart';

import '../models/photo_spot.dart';
import 'spot_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ExplorePage(),
      const MapScreen(),
      const _SavedPage(),
      const _ProfilePage(),
    ];

    return Scaffold(
      body: pages[index],

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CameraScreen(),
            ),
          );
        },
        child: const Icon(
          Icons.camera_alt_rounded,
          size: 28,
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF11151C),
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Harita',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Kaydedilenler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'Tümü';

  final List<String> _filters = [
    'Tümü',
    'Gün Batımı',
    'Gün Doğumu',
    'Şehir',
    'Doğa',
    'Mimari',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PhotoSpot> get _filteredSpots {
    final query = _searchQuery.trim().toLowerCase();

    return demoSpots.where((spot) {
      final matchesSearch = query.isEmpty ||
    spot.name.toLowerCase().contains(query) ||
    spot.city.toLowerCase().contains(query) ||
    spot.category.toLowerCase().contains(query) ||
    spot.description.toLowerCase().contains(query) ||
    spot.bestTime.toLowerCase().contains(query) ||
    spot.angle.toLowerCase().contains(query) ||
    spot.recommendedLens.toLowerCase().contains(query) ||
    spot.tags.any(
      (tag) => tag.toLowerCase().contains(query),
    );

      if (!matchesSearch) {
        return false;
      }

      switch (_selectedFilter) {
        case 'Gün Batımı':
          return spot.bestTime.contains('17') ||
              spot.bestTime.contains('18') ||
              spot.bestTime.contains('19');

        case 'Gün Doğumu':
          return spot.bestTime.contains('05') ||
              spot.bestTime.contains('06') ||
              spot.bestTime.contains('07');

        case 'Şehir':
          return spot.city == 'İstanbul' ||
              spot.city == 'Ankara' ||
              spot.city == 'İzmir';

        case 'Doğa':
          return spot.name.toLowerCase().contains('kapadokya') ||
              spot.name.toLowerCase().contains('doğa');

        case 'Mimari':
          return spot.name.toLowerCase().contains('kule') ||
              spot.name.toLowerCase().contains('camii') ||
              spot.name.toLowerCase().contains('saray');

        default:
          return true;
      }
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final spots = _filteredSpots;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'En İyi Çekim Noktası',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                'Fotoğrafını daha iyi çekmek için doğru noktayı bul.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // ARAMA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Şehir, konum veya çekim noktası ara...',
                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,

                  filled: true,
                  fillColor: const Color(0xFF171C24),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // FİLTRELER
          SliverToBoxAdapter(
            child: SizedBox(
              height: 58,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (, _) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final filter = _filters[i];
                  final selected =
                      filter == _selectedFilter;

                  return ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor:
                        const Color(0xFFFFC107),
                    backgroundColor:
                        const Color(0xFF171C24),
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),
              child: Text(
                _searchQuery.isEmpty
                    ? 'Popüler çekim noktaları'
                    : '${spots.length} sonuç bulundu',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // SONUÇLAR
          if (spots.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 56,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Sonuç bulunamadı',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Farklı bir şehir veya çekim noktası deneyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final spot = spots[i];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      12,
                    ),
                    child: Card(
                      color: const Color(0xFF151A22),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.all(10),

                        leading: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(10),
                          child: Image.network(
                            spot.imageUrl,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (, _, _) {
                              return Container(
                                width: 78,
                                height: 78,
                                color:
                                    const Color(0xFF222831),
                                child: const Icon(
                                  Icons.photo,
                                  color: Colors.white38,
                                ),
                              );
                            },
                          ),
                        ),

                        title: Text(
                          spot.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          '⭐ ${spot.rating} • ${spot.city}\n'
                          '📸 ${spot.bestTime}',
                        ),

                        isThreeLine: true,

                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SpotDetailScreen(
                                spot: spot,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                childCount: spots.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedPage extends StatelessWidget {
  const _SavedPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Kaydedilen çekim noktaların burada görünecek.',
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Profil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // PROFİL FOTOĞRAFI
                  CircleAvatar(
                    radius: 52,
                    backgroundColor:
                        const Color(0xFFFFC107),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          const Color(0xFF171C24),
                      child: const Icon(
                        Icons.person,
                        size: 52,
                        color: Colors.white54,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Fotoğrafçı',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Daha iyi fotoğraflar için doğru noktayı keşfet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // İSTATİSTİKLER
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151A22),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileStat(
                          value: '0',
                          label: 'Çekim',
                        ),
                        _ProfileStat(
                          value: '0',
                          label: 'Kaydedilen',
                        ),
                        _ProfileStat(
                          value: '0',
                          label: 'Favori',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // PROFİL MENÜLERİ
                  _ProfileMenuItem(
                    icon: Icons.favorite_border,
                    title: 'Kaydedilen Noktalar',
                    subtitle:
                        'Favori çekim noktalarını görüntüle',
                    onTap: () {},
                  ),

                  _ProfileMenuItem(
                    icon: Icons.photo_library_outlined,
                    title: 'Çekimlerim',
                    subtitle:
                        'Çektiğin fotoğrafları görüntüle',
                    onTap: () {},
                  ),

                  _ProfileMenuItem(
                    icon: Icons.location_on_outlined,
                    title: 'Konum Tercihleri',
                    subtitle:
                        'Yakındaki çekim noktalarını ayarla',
                    onTap: () {},
                  ),

                  _ProfileMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Ayarlar',
                    subtitle:
                        'Uygulama ve bildirim ayarları',
                    onTap: () {},
                  ),

                  _ProfileMenuItem(
                    icon: Icons.info_outline,
                    title: 'Uygulama Hakkında',
                    subtitle:
                        'En İyi Çekim Noktası',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName:
                            'En İyi Çekim Noktası',
                        applicationVersion:
                            '1.0.0',
                        applicationLegalese:
                            '© 2026',
                      );
                    },
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

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF151A22),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107)
                .withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFC107),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
        ),
        onTap: onTap,
      ),
    );
  }
}
