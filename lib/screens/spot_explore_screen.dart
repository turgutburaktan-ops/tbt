import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import 'spot_detail_screen.dart';

class SpotExploreScreen extends StatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  State<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends State<SpotExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PhotoSpot> _spots = const [];
  List<String> _cities = const [];
  List<String> _categories = const [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _city;
  String? _category;
  SpotSort _sort = SpotSort.rating;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        SpotRepository.instance.discover(
          query: SpotDiscoveryQuery(
            text: _search,
            city: _city,
            category: _category,
            sort: _sort,
          ),
        ),
        SpotRepository.instance.availableCities(),
        SpotRepository.instance.availableCategories(),
      ]);

      if (!mounted) return;
      setState(() {
        _spots = results[0] as List<PhotoSpot>;
        _cities = results[1] as List<String>;
        _categories = results[2] as List<String>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Çekim noktaları yüklenemedi.';
      });
    }
  }

  Future<void> _applySearch(String value) async {
    _search = value;
    await _reload();
  }

  void _openFilters() {
    String? draftCity = _city;
    String? draftCategory = _category;
    SpotSort draftSort = _sort;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151A22),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keşfet filtreleri',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String?>(
                      value: draftCity,
                      decoration: const InputDecoration(labelText: 'Şehir'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tüm şehirler')),
                        ..._cities.map((city) => DropdownMenuItem<String?>(value: city, child: Text(city))),
                      ],
                      onChanged: (value) => setSheetState(() => draftCity = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: draftCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tüm kategoriler')),
                        ..._categories.map((category) => DropdownMenuItem<String?>(value: category, child: Text(category))),
                      ],
                      onChanged: (value) => setSheetState(() => draftCategory = value),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<SpotSort>(
                      segments: const [
                        ButtonSegment(value: SpotSort.rating, label: Text('Puana göre'), icon: Icon(Icons.star_rounded)),
                        ButtonSegment(value: SpotSort.name, label: Text('İsme göre'), icon: Icon(Icons.sort_by_alpha_rounded)),
                      ],
                      selected: {draftSort},
                      onSelectionChanged: (value) => setSheetState(() => draftSort = value.first),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              draftCity = null;
                              draftCategory = null;
                              draftSort = SpotSort.rating;
                            });
                          },
                          child: const Text('Temizle'),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            setState(() {
                              _city = draftCity;
                              _category = draftCategory;
                              _sort = draftSort;
                            });
                            _reload();
                          },
                          child: const Text('Uygula'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFFFFC107),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Çekim Noktaları', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Doğru yeri, ışığı ve açıyı keşfet.', style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Filtrele',
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: _searchController,
                onSubmitted: _applySearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Şehir, nokta, gün batımı, mimari...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _applySearch('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
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
          if (_city != null || _category != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_city != null)
                      InputChip(
                        label: Text(_city!),
                        onDeleted: () {
                          setState(() => _city = null);
                          _reload();
                        },
                      ),
                    if (_category != null)
                      InputChip(
                        label: Text(_category!),
                        onDeleted: () {
                          setState(() => _category = null);
                          _reload();
                        },
                      ),
                  ],
                ),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ExploreState(
                icon: Icons.cloud_off_rounded,
                title: _error!,
                actionLabel: 'Tekrar dene',
                onAction: _reload,
              ),
            )
          else if (_spots.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _ExploreState(
                icon: Icons.search_off_rounded,
                title: 'Bu filtrelerde çekim noktası bulunamadı.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  '${_spots.length} çekim noktası',
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _spots.length,
              itemBuilder: (context, index) => _SpotCard(spot: _spots[index]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;

  const _SpotCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        color: const Color(0xFF151A22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: spot.imageUrl.isEmpty
                      ? _fallbackImage()
                      : Image.network(
                          spot.imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackImage(),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${spot.city} • ${spot.category}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                          const SizedBox(width: 3),
                          Text(spot.rating.toStringAsFixed(1)),
                          const SizedBox(width: 12),
                          const Icon(Icons.schedule_rounded, size: 15, color: Colors.white54),
                          const SizedBox(width: 4),
                          Expanded(child: Text(spot.bestTime, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() => Container(
        width: 88,
        height: 88,
        color: const Color(0xFF222831),
        child: const Icon(Icons.photo_camera_back_outlined, color: Colors.white38),
      );
}

class _ExploreState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ExploreState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.white30),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
