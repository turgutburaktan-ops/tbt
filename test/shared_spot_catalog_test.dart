import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/published_spot_catalog.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/shared_spots.json').readAsStringSync()) as List;
  final base = Map<String, dynamic>.from(cases.first['data'] as Map);

  test('web and mobile accept the same shared publication fixtures', () {
    for (final fixture in cases) {
      final result = PublishedSpotCatalog.decode(fixture['id'],
          Map<String, dynamic>.from(fixture['data'] as Map));
      expect(result != null, fixture['accepted'], reason: fixture['id']);
      if (result != null) expect(result.id, fixture['id']);
    }
  });

  test('global names and neighbors across grid boundaries are rejected', () {
    final a = PublishedSpotCatalog.decode('a', {...base, 'latitude': 38.00099})!;
    final near = PublishedSpotCatalog.decode('b', {...base, 'name': 'Başka ad', 'latitude': 38.00101})!;
    final name = PublishedSpotCatalog.decode('c', {...base, 'name': 'PERTEK KALESİ', 'latitude': 39.0})!;
    final far = PublishedSpotCatalog.decode('d', {...base, 'name': 'Uzak yer', 'latitude': 39.1})!;
    expect(PublishedSpotCatalog.filter([far, name, near, a]).map((s) => s.id), ['a','d']);
  });

  test('loads beyond 2000 in bounded pages, including the final partial page', () async {
    final docs = List.generate(2501, (i) => i);
    var requests = 0;
    final result = await PublishedSpotCatalog.collectPages<int>((cursor, size) async {
      requests++;
      return docs.skip(cursor == null ? 0 : cursor + 1).take(size).toList();
    });
    expect(result, docs);
    expect(requests, 6);
  });

  test('empty publication stays empty and a failed page rejects the whole load', () async {
    expect(await PublishedSpotCatalog.collectPages<int>((_, __) async => []), isEmpty);
    await expectLater(PublishedSpotCatalog.collectPages<int>((cursor, size) async {
      if (cursor != null) throw StateError('network');
      return List.generate(size, (i) => i);
    }), throwsStateError);
  });
}
