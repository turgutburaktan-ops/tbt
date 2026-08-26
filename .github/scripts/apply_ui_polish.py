from pathlib import Path

# Mekanlar: "En iyi" etiketi diğer mekanları daha düşük kaliteli gösterdiği için kaldır.
p = Path('lib/widgets/nearby_places_view.dart')
s = p.read_text()
block = """              _SortChip(
                label: 'En iyi',
                selected: _sort == 'rating',
                onTap: () => setState(() => _sort = 'rating'),
              ),
              const SizedBox(width: 7),
"""
s = s.replace(block, '')
p.write_text(s)

# Gezilecek Yerler: Anıtkabir arama yapılmadığı sürece listenin en üstünde sabit kalsın.
p = Path('lib/screens/spot_explore_screen_v2.dart')
s = p.read_text()
old = """    next.sort((a, b) {
      if (_position != null) {
        final distanceOrder = _distance(a).compareTo(_distance(b));
        if (distanceOrder != 0) return distanceOrder;
      }
      final ratingOrder = b.rating.compareTo(a.rating);
      return ratingOrder != 0 ? ratingOrder : a.name.compareTo(b.name);
    });
"""
new = """    next.sort((a, b) {
      if (key.isEmpty) {
        final aPinned = a.name.toLowerCase().replaceAll('ı', 'i').contains('anitkabir');
        final bPinned = b.name.toLowerCase().replaceAll('ı', 'i').contains('anitkabir');
        if (aPinned != bPinned) return aPinned ? -1 : 1;
      }
      if (_position != null) {
        final distanceOrder = _distance(a).compareTo(_distance(b));
        if (distanceOrder != 0) return distanceOrder;
      }
      final ratingOrder = b.rating.compareTo(a.rating);
      return ratingOrder != 0 ? ratingOrder : a.name.compareTo(b.name);
    });
"""
if old in s:
    s = s.replace(old, new, 1)
elif "aPinned" not in s:
    raise SystemExit('Spot sorting target not found')
p.write_text(s)
