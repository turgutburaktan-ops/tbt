import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/home_shell_v3.dart';
import '../lib/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) return;
    final fontRoot = '$sdk/bin/cache/artifacts/material_fonts';
    for (final entry in {
      'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(
          File('$fontRoot/$name')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });
  testWidgets(
    'planning offers three clear actions and retains advanced tools',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark.copyWith(
              textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
            ),
            home: Scaffold(body: PlanningHub(onOpenNearby: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bana plan öner'), findsOneWidget);
      expect(find.text('Kendim rota oluştur'), findsOneWidget);
      expect(find.text('Planlarım'), findsOneWidget);
      expect(find.text('Ayrıntılı rota tercihleri'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/tbt-plan-review.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.text('Diğer planlama araçları'));
      await tester.tap(find.text('Diğer planlama araçları'));
      await tester.pumpAndSettle();
      expect(find.text('Ayrıntılı rota tercihleri'), findsOneWidget);
      expect(find.text('Etkinlik oluştur'), findsOneWidget);
      expect(find.text('Buluşma başlat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
