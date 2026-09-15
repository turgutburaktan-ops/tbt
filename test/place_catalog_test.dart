import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/services/place_catalog_service.dart';

void main() {
  test('every province has the same partition key as the server', () {
    final provinces = jsonDecode(
      File('functions/catalog/provinces.json').readAsStringSync(),
    ) as List;
    final keys = provinces
        .map((c) => PlaceCatalogService.partition(c as String, 'cafe'))
        .toSet();
    expect(keys.length, 81);
    expect(keys.contains('istanbul_cafe'), isTrue);
    expect(keys.contains('elazig_cafe'), isTrue);
    expect(keys.contains('hakkari_cafe'), isTrue);
    expect(keys.every((k) => RegExp(r'^[a-z_]+$').hasMatch(k)), isTrue);
  });
  test('venue detail identity and route identity remain compatible', () {
    final item = CatalogItem.decode({
      'canonicalId': 'venue:cafe:node-123',
      'legacyId': 'node-123',
      'kind': 'cafe',
      'name': 'Kafe',
      'city': 'Elazığ',
      'latitude': 38.67,
      'longitude': 39.22,
    });
    expect(item!.venue!.id, 'node-123');
    expect(item.spot.id, 'venue:cafe:node-123');
    expect(
      CatalogItem.decode({
        'canonicalId': 'wrong',
        'legacyId': 'node-123',
        'kind': 'cafe',
      }),
      isNull,
    );
  });
}
