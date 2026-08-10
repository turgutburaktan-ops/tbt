import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/favorites_service.dart';

import 'camera_screen.dart';
import 'map_screen.dart';
import 'profile_page.dart';
import 'spot_detail_screen.dart';

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
      const _ExplorePage(),
      const MapScreen(),
      const _SavedPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
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
        height: 72,
        backgroundColor: const Color(0xFF11151C),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Keşfet',
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

  final List<String> _filters = const [
    'Tümü',
    'Gün Batımı',
    'Gün Doğumu',
    'Şehir',
    'Doğa',
    'Mimari',
    'Manzara',
    'Sokak',
    'Tarih',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _containsTag(PhotoSpot spot, String value) {
    final query = value.toLowerCase();

    return spot.tags.any(
      (tag) => tag.toLowerCase().contains(query),
    );
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
          spot.difficulty.toLowerCase().contains(query) ||
          spot.tags.any(
            (tag) => tag.toLowerCase().contains(query),
          );

      if (!matchesSearch) {
        return false;
      }

      switch (_selectedFilter) {
        case 'Gün Batımı':
          return _containsTag(spot, 'gün batımı') ||
              spot.category.toLowerCase() ==
                  'gün batımı';

        case 'Gün Doğumu':
          return _containsTag(spot, 'gün doğumu');

        case 'Şehir':
          return spot.category.toLowerCase() ==
                  'şehir' ||
              _containsTag(spot, 'şehir');

        case 'Doğa':
          return spot.category.toLowerCase() ==
                  'doğa' ||
              _containsTag(spot, 'doğa');

        case 'Mimari':
          return spot.category.toLowerCase() ==
                  'mimari' ||
              _containsTag(spot, 'mimari');

        case 'Manzara':
          return spot.category.toLowerCase() ==
                  'manzara' ||
              _containsTag(spot, 'manzara');

        case 'Sokak':
          return spot.category.toLowerCase() ==
                  'sokak' ||
              _containsTag(spot, 'sokak');

        case 'Tarih':
          return spot.category.toLowerCase() ==
                  'tarih' ||
              _containsTag(spot, 'tarih');

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
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                4,
              ),
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
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                18,
              ),
              child: Text(
                'Fotoğrafın için doğru yeri, ışığı ve açıyı keşfet.',
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText:
                      'Şehir, nokta, gün batımı, mimari...',
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF171C24),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // FİLTRELER
          SliverToBoxAdapter(
            child: SizedBox(
              height: 62,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
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
                    side: BorderSide.none,
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
                18,
                20,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchQuery.isEmpty &&
                              _selectedFilter == 'Tümü'
                          ? 'Popüler çekim noktaları'
                          : '${spots.length} sonuç bulundu',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_selectedFilter != 'Tümü')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = 'Tümü';
                        });
                      },
                      child: const Text(
                        'Filtreyi temizle',
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (spots.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 58,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Sonuç bulunamadı',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Farklı bir şehir, kategori veya çekim türü deneyin.',
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
                (context, index) {
                  final spot = spots[index];

                  return _ExploreSpotCard(
                    spot: spot,
                  );
                },
                childCount: spots.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

class _ExploreSpotCard extends StatelessWidget {
  final PhotoSpot spot;

  const _ExploreSpotCard({
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
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
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpotDetailScreen(
                  spot: spot,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Image.network(
                    spot.imageUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        width: 88,
                        height: 88,
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

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${spot.city} • ${spot.category}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        '⭐ ${spot.rating}   📸 ${spot.bestTime}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        '📐 ${spot.angle}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              Color(0xFFFFC107),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                ValueListenableBuilder<
                    List<PhotoSpot>>(
                  valueListenable:
                      FavoritesService.savedSpots,
                  builder: (
                    context,
                    savedSpots,
                    _,
                  ) {
                    final isSaved =
                        savedSpots.any(
                      (item) =>
                          item.id == spot.id,
                    );

                    return IconButton(
                      onPressed: () {
                        FavoritesService.toggle(
                          spot,
                        );
                      },
                      icon: Icon(
                        isSaved
                            ? Icons.favorite
                            : Icons
                                .favorite_border,
                        color: isSaved
                            ? const Color(
                                0xFFFFC107,
                              )
                            : Colors.white54,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// KAYDEDİLENLER
// ======================================================

class _SavedPage extends StatelessWidget {
  const _SavedPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<PhotoSpot>>(
        valueListenable:
            FavoritesService.savedSpots,
        builder: (
          context,
          spots,
          _,
        ) {
          if (spots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 66,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz kaydedilen nokta yok',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Keşfet ekranındaki kalp simgesine basarak çekim noktalarını kaydedebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              22,
              20,
              110,
            ),
            children: [
              const Text(
                'Kaydedilenler',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${spots.length} çekim noktası',
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 18),

              ...spots.map(
                (spot) => Card(
                  color: const Color(0xFF151A22),
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child: Image.network(
                        spot.imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return Container(
                            width: 70,
                            height: 70,
                            color: const Color(
                              0xFF222831,
                            ),
                            child: const Icon(
                              Icons.photo,
                              color:
                                  Colors.white38,
                            ),
                          );
                        },
                      ),
                    ),
                    title: Text(
                      spot.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${spot.city} • ⭐ ${spot.rating}\n${spot.category}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Kaydı kaldır',
                      icon: const Icon(
                        Icons.favorite,
                        color:
                            Color(0xFFFFC107),
                      ),
                      onPressed: () {
                        FavoritesService.remove(
                          spot,
                        );
                      },
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
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======================================================
// PROFİL
// ======================================================

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
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFC107),
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
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      color: const Color(0xFF151A22),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107)
                .withOpacity(.12),
            borderRadius:
                BorderRadius.circular(12),
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
