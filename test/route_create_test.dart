import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../lib/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/route_create_screen.dart';

void main() {
  testWidgets(
    'route starts with destination duration and company; advanced fields are collapsed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        final font = FontLoader('Roboto');
        for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
          final f = File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/$name',
          );
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
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const RouteCreateScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/route-create-review.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      expect(find.text('Nereye?'), findsOneWidget);
      expect(find.text('Ne kadar süre?'), findsOneWidget);
      expect(find.text('Kimlerle?'), findsOneWidget);
      expect(find.text('Bütçe'), findsNothing);
      await tester.tap(find.text('Diğer tercihler'));
      await tester.pumpAndSettle();
      expect(find.text('Bütçe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
