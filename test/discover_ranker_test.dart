import 'package:flutter_test/flutter_test.dart';

import '../lib/services/discover_ranker.dart';

void main() {
  final now = DateTime(2026, 9, 13);
  DiscoverCandidate item(
    String id,
    String author, {
    String topic = 'travel',
    int age = 0,
    int likes = 0,
    bool video = false,
  }) => DiscoverCandidate(
    id: id,
    author: author,
    topic: topic,
    video: video,
    createdAt: now.subtract(Duration(hours: age)),
    likes: likes,
  );

  test('eight newest TBT photos cannot dominate first ten', () {
    final input = [
      for (var i = 0; i < 8; i++) item('tbt$i', 'tbt'),
      for (var a = 0; a < 8; a++)
        for (var i = 0; i < 3; i++)
          item(
            '$a-$i',
            'user$a',
            age: 72,
            topic: a.isEven ? 'food' : 'sport',
            video: a.isEven,
          ),
    ];
    final ranked = rankDiscover(input, now: now, seed: 1);
    expect(
      ranked.take(10).where((c) => c.author == 'tbt').length,
      lessThanOrEqualTo(2),
    );
    expect(ranked.map((c) => c.id).toSet().length, input.length);
    for (var i = 1; i < 10; i++)
      expect(ranked[i].author, isNot(ranked[i - 1].author));
    expect(ranked.take(10).map((c) => c.topic).toSet().length, greaterThan(1));
  });
  test(
    'sparse inventory relaxes fairly without dropping or duplicating posts',
    () {
      final input = [for (var i = 0; i < 8; i++) item('$i', 'tbt')];
      expect(rankDiscover(input, now: now, seed: 2).length, 8);
      expect(rankDiscover([], now: now, seed: 1), isEmpty);
    },
  );
  test('seen and popular posts do not bury unseen posts', () {
    final input = [
      item('seen', 'a', likes: 100000000),
      item('fresh', 'b', age: 50),
    ];
    expect(
      rankDiscover(input, now: now, seed: 1, seen: {'seen'}).first.id,
      'fresh',
    );
  });
  test('stable per session, refresh varies the ordering', () {
    final input = [for (var i = 0; i < 30; i++) item('$i', 'u$i')];
    List<String> ids(int seed) =>
        rankDiscover(input, now: now, seed: seed).map((c) => c.id).toList();
    expect(ids(5), ids(5));
    expect(ids(5), isNot(ids(6)));
  });
  test('interests affect relevance while other topics still appear', () {
    final input = [
      for (var i = 0; i < 20; i++)
        item('$i', 'u$i', topic: i.isEven ? 'food' : 'sport'),
    ];
    final result = rankDiscover(
      input,
      now: now,
      seed: 7,
      interests: {'sport': 20},
    );
    expect(result.first.topic, 'sport');
    expect(result.take(10).any((c) => c.topic == 'food'), isTrue);
  });
  test(
    'missing tags are supported and Turkish descriptions classify basic topics',
    () {
      expect(discoverTopic({'caption': 'Kahve ve tatlı'}), 'food');
      expect(discoverTopic({'caption': 'Ormanda yürüyüş'}), 'nature');
      expect(discoverTopic({}), 'daily');
    },
  );
}
