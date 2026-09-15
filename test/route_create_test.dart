import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../lib/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/route_create_screen.dart';

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
  testWidgets(
    'route creation shows transport and stops without a questionnaire',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
            appBarTheme: AppTheme.dark.appBarTheme.copyWith(
              titleTextStyle: AppTheme.dark.appBarTheme.titleTextStyle
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: AppTheme.dark.filledButtonTheme.style?.copyWith(
                textStyle: WidgetStatePropertyAll(
                  AppTheme.dark.filledButtonTheme.style?.textStyle
                          ?.resolve({})
                          ?.copyWith(fontFamily: 'Roboto') ??
                      const TextStyle(fontFamily: 'Roboto'),
                ),
              ),
            ),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const RouteCreateScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/route-create-review.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(find.text('Rotan burada şekillenecek'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'ela');
      await tester.pumpAndSettle();
      expect(find.text('Elazığ'), findsOneWidget);
      await tester.tap(find.text('Elazığ'));
      await tester.pumpAndSettle();

      expect(find.text('Araç'), findsOneWidget);
      expect(find.text('Yürüyüş'), findsOneWidget);
      expect(find.text('Bisiklet'), findsOneWidget);
      expect(find.text('Kimlerle?'), findsNothing);
      expect(find.text('Ne kadar süre?'), findsNothing);
      final create = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Rotayı oluştur'),
      );
      expect(create.onPressed, isNull);
      await tester.tap(find.text('Bisiklet'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'Bisiklet'},
      );
      await tester.scrollUntilVisible(
        find.text('Tarih ve saat'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Kimler katılabilir?'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Kimler katılabilir?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Herkes'));
      await tester.pumpAndSettle();
      expect(find.text('Herkes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Buluşma noktası'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Buluşma noktası'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small screen and enlarged text keep trip controls reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const RouteCreateScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Buluşma noktası'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Buluşma noktası'));
    await tester.pumpAndSettle();
    expect(find.text('Mekân ara'), findsOneWidget);
    expect(find.text('Haritadan seç'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
