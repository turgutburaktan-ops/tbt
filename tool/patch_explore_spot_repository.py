from pathlib import Path


def main() -> None:
    path = Path('lib/screens/home_screen.dart')
    text = path.read_text()

    if "import '../services/spot_repository.dart';" not in text:
        marker = "import '../services/favorites_service.dart';\n"
        if marker not in text:
            raise SystemExit('favorites_service import marker not found')
        text = text.replace(marker, marker + "import '../services/spot_repository.dart';\n", 1)

    state_marker = """  String _searchQuery = '';
  String _selectedFilter = 'Tümü';
"""
    if state_marker in text and "List<PhotoSpot> _spots = List<PhotoSpot>.from(demoSpots);" not in text:
        text = text.replace(
            state_marker,
            state_marker
            + "  List<PhotoSpot> _spots = List<PhotoSpot>.from(demoSpots);\n"
            + "  bool _loadingSpots = true;\n\n",
            1,
        )

    class_start = text.find('class _ExplorePageState extends State<_ExplorePage> {')
    if class_start < 0:
        raise SystemExit('Explore state class not found')

    if 'Future<void> _loadSpots() async' not in text[class_start:]:
        dispose_pos = text.find('  @override\n  void dispose()', class_start)
        if dispose_pos < 0:
            raise SystemExit('Explore dispose marker not found')
        loader = """  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    try {
      final loaded = await SpotRepository.instance.loadSpots();
      if (!mounted) return;
      setState(() {
        _spots = loaded.isEmpty ? List<PhotoSpot>.from(demoSpots) : loaded;
        _loadingSpots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spots = List<PhotoSpot>.from(demoSpots);
        _loadingSpots = false;
      });
    }
  }

"""
        text = text[:dispose_pos] + loader + text[dispose_pos:]

    text = text.replace(
        '    return demoSpots.where((spot) {\n',
        '    return _spots.where((spot) {\n',
        1,
    )

    heading_old = """                  Expanded(
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
"""
    heading_new = """                  Expanded(
                    child: Text(
                      _loadingSpots
                          ? 'Çekim noktaları yükleniyor…'
                          : (_searchQuery.isEmpty && _selectedFilter == 'Tümü'
                              ? '${spots.length} çekim noktası'
                              : '${spots.length} sonuç bulundu'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Noktaları yenile',
                    onPressed: _loadingSpots
                        ? null
                        : () {
                            setState(() => _loadingSpots = true);
                            _loadSpots();
                          },
                    icon: _loadingSpots
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFC107),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
"""
    if heading_old in text:
        text = text.replace(heading_old, heading_new, 1)

    path.write_text(text)
    print('Explore connected to SpotRepository: Firestore + curated spots visible')


if __name__ == '__main__':
    main()
