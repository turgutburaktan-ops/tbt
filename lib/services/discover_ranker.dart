import 'dart:math' as math;

class DiscoverCandidate {
  const DiscoverCandidate({
    required this.id,
    required this.author,
    required this.topic,
    required this.video,
    required this.createdAt,
    this.likes = 0,
  });
  final String id, author, topic;
  final bool video;
  final DateTime createdAt;
  final int likes;
}

/// Diversity constraints take precedence over relevance and popularity.
List<DiscoverCandidate> rankDiscover(
  List<DiscoverCandidate> candidates, {
  required DateTime now,
  required int seed,
  Map<String, double> interests = const {},
  Set<String> seen = const {},
}) {
  final remaining = {for (final item in candidates) item.id: item}.values
      .toList();
  final result = <DiscoverCandidate>[];
  double noise(String id) {
    var h = seed & 0x7fffffff;
    for (final c in id.codeUnits) {
      h = ((h * 31) + c) & 0x7fffffff;
    }
    return math.Random(h).nextDouble();
  }

  final random = {for (final c in remaining) c.id: noise(c.id)};
  while (remaining.isNotEmpty) {
    var pool = remaining;
    if (result.isNotEmpty) {
      final different = pool
          .where((c) => c.author != result.last.author)
          .toList();
      if (different.isNotEmpty) pool = different;
    }
    final recent = result.skip(math.max(0, result.length - 9));
    final counts = <String, int>{};
    for (final c in recent) {
      counts[c.author] = (counts[c.author] ?? 0) + 1;
    }
    final underCap = pool.where((c) => (counts[c.author] ?? 0) < 2).toList();
    if (underCap.isNotEmpty) {
      pool = underCap;
    } else {
      final least = pool.map((c) => counts[c.author] ?? 0).reduce(math.min);
      pool = pool.where((c) => (counts[c.author] ?? 0) == least).toList();
    }
    // Approximate 5 relevance / 3 exploration / 2 freshness slots per ten.
    final slot = result.length % 10;
    final explore = [2, 5, 8].contains(slot);
    final fresh = [4, 9].contains(slot);
    double score(DiscoverCandidate c) {
      final age = math.max(0, now.difference(c.createdAt).inHours);
      final freshness = 1 / (1 + age / 72);
      final affinity = ((interests[c.topic] ?? 0) / 10).clamp(0.0, 1.0);
      final popularity = (math.log(1 + math.max(0, c.likes)) / 8).clamp(
        0.0,
        1.0,
      );
      return (fresh ? 3 : .6) * freshness +
          (explore
              ? 1 - affinity
              : fresh
              ? 0
              : 2 * affinity) +
          random[c.id]! * (explore ? 2 : 1) +
          popularity * .2 -
          (seen.contains(c.id) ? 5 : 0) -
          (result.isNotEmpty && result.last.topic == c.topic ? 1.4 : 0) -
          (result.length >= 2 &&
                  result.last.video == c.video &&
                  result[result.length - 2].video == c.video
              ? .5
              : 0);
    }

    pool.sort((a, b) {
      final comparison = score(b).compareTo(score(a));
      return comparison == 0 ? a.id.compareTo(b.id) : comparison;
    });
    final next = pool.first;
    result.add(next);
    remaining.removeWhere((c) => c.id == next.id);
  }
  return result;
}

String discoverTopic(Map<String, dynamic> data) {
  final explicit = '${data['category'] ?? ''} ${data['tags'] ?? ''}';
  final text = '$explicit ${data['caption'] ?? ''} ${data['spotName'] ?? ''}'
      .toLowerCase()
      .replaceAll('ı', 'i');
  const terms = {
    'food': ['yemek', 'lezzet', 'kahve', 'restoran', 'tatli', 'food', 'coffee'],
    'nature': [
      'manzara',
      'doğa',
      'orman',
      'göl',
      'şelale',
      'deniz',
      'nature',
      'sunset',
    ],
    'travel': [
      'gezi',
      'seyahat',
      'rota',
      'tarih',
      'müze',
      'kale',
      'travel',
      'şehir',
    ],
    'sport': ['spor', 'koşu', 'bisiklet', 'yürüyüş', 'fitness', 'sport'],
    'fun': ['eğlence', 'komik', 'mizah', 'dans', 'müzik', 'fun', 'music'],
  };
  for (final entry in terms.entries) {
    if (entry.value.any(text.contains)) return entry.key;
  }
  return 'daily';
}
