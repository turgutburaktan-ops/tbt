import '../lib/widgets/route_editor_map.dart';

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/photo_spot.dart';
import '../lib/models/route_place.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/services/route_selection_service.dart';
import '../lib/services/user_facing_error.dart';
import '../lib/widgets/route_selection_button.dart';

const first = PhotoSpot(
  id: 'a',
  name: 'Harput',
  city: 'Elazığ',
  latitude: 38.7,
  longitude: 39.2,
  rating: 4,
  bestTime: '',
  angle: '',
  imageUrl: '',
  tags: ['FirestoreDoğrulanmış'],
);
const second = PhotoSpot(
  id: 'b',
  name: 'Keban',
  city: 'Elazığ',
  latitude: 38.8,
  longitude: 38.7,
  rating: 4,
  bestTime: '',
  angle: '',
  imageUrl: '',
  tags: ['FirestoreDoğrulanmış'],
);

void main() {
  test(
    'offline, unavailable, permission and timeout have distinct Turkish messages',
    () {
      expect(
        userFacingError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Failed to get document because the client is offline.',
          ),
        ),
        'İnternet bağlantısı yok. Bağlantını kontrol edip tekrar dene.',
      );
      expect(
        userFacingError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        contains('Hizmete şu an ulaşılamıyor'),
      );
      expect(
        userFacingError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        contains('erişim iznin'),
      );
      expect(
        userFacingError(TimeoutException('secret diagnostic')),
        contains('zaman aşımına'),
      );
      expect(
        userFacingError(Exception('Raw backend details')),
        isNot(contains('Raw')),
      );
    },
  );

  testWidgets(
    'selected places open unified route draft with intact stops and no repeated city question',
    (tester) async {
      final selection = RouteSelectionService.instance;
      selection.clear();
      addTearDown(selection.clear);
      for (final spot in [first, second]) {
        selection.toggle(
          RoutePlace(
            id: 'spot:${spot.id}',
            name: spot.name,
            category: spot.category,
            latitude: spot.latitude,
            longitude: spot.longitude,
            spot: spot,
          ),
        );
      }
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RouteSelectionButton())),
      );
      await tester.tap(find.text('Rotaya Git  •  2'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteCreateScreen), findsOneWidget);
      expect(find.text('Şehir veya bölge ara'), findsNothing);
      await tester.tap(find.text('Rotanı oluşturmaya başla'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RouteEditorMap>(find.byType(RouteEditorMap))
            .stops
            .map((s) => s.id),
        ['a', 'b'],
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('a')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ReorderableDragStartListener), findsWidgets);
      await tester.ensureVisible(find.byTooltip('Durağı kaldır').first);
      await tester.tap(find.byTooltip('Durağı kaldır').first);
      await tester.pumpAndSettle();
      expect(find.text('Harput'), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('b')), matching: find.text('Keban')), findsOneWidget);
      expect(tester.widget<RouteEditorMap>(find.byType(RouteEditorMap)).stops.map((s) => s.id), ['b']);
      expect(tester.takeException(), isNull);
    },
  );
}
