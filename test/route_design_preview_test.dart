import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/screens/route_filters_screen.dart';
import '../lib/screens/route_poll_create_screen.dart';
import '../lib/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      // Explicit component text styles inherit the test font; provide its real glyphs too.
      final fallback = FontLoader('Ahem');
      fallback.addFont(
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await fallback.load();
      final font = FontLoader('Roboto');
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/$name');
        if (await f.exists())
          font.addFont(
            Future.value(ByteData.sublistView(await f.readAsBytes())),
          );
      }
      await font.load();
      final icon = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icon.exists())
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(await icon.readAsBytes())),
            ))
            .load();
    }
  });

  testWidgets('route screens render at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screens = <String, Widget>{
      'create': RouteCreateScreen(loadCatalog: (_) async => []),
      'filters': const RouteFiltersScreen(
        value: RouteFilters(),
        cities: ['Elazığ', 'İstanbul'],
      ),
      'poll': const RoutePollCreateScreen(),
    };
    for (final entry in screens.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner:false,theme: AppTheme.dark, home: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/route_previews/${entry.key}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
