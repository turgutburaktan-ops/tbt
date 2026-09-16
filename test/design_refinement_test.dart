import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/categorized_search.dart';
import '../lib/widgets/story_editor_tools.dart';
import '../lib/screens/invite_qr_screen.dart';

void main() {
  testWidgets('exploration becomes categorized search and clearing restores photos', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CategorizedSearch(
      emptyBuilder: (_) => const Text('Keşfet fotoğrafları'),
      resultsBuilder: (_, category, query) => Text('${category.name}: $query'),
    ))));
    expect(find.text('Keşfet fotoğrafları'), findsOneWidget);
    expect(find.text('Mekânlar'), findsNothing);
    await tester.enterText(find.byType(TextField), 'kafe');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Mekânlar'));
    await tester.pump();
    expect(find.text('venues: kafe'), findsOneWidget);
    await tester.tap(find.byTooltip('Temizle'));
    await tester.pump();
    expect(find.text('Keşfet fotoğrafları'), findsOneWidget);
    expect(find.text('Mekânlar'), findsNothing);
  });

  testWidgets('story tools scroll on a narrow screen and preserve disabled actions', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: Builder(
      builder: (context) => TextButton(onPressed: () => showStoryEditorTools(context, [
        StoryEditorTool(Icons.crop, 'Kadraj kapalı', () => selected += 100, enabled: false),
        for (var i = 0; i < 10; i++) StoryEditorTool(Icons.edit, 'Araç $i', () => selected++),
      ]), child: const Text('Araçları aç')),
    ))));
    await tester.tap(find.text('Araçları aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kadraj kapalı'));
    expect(selected, 0);
    await tester.ensureVisible(find.text('Araç 9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Araç 9'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.text('Story araçları'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR invite fits narrow phones and keeps the complete link available', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) await tester.runAsync(() async {
      await (FontLoader('Roboto')..addFont(File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf').readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader('MaterialIcons')..addFont(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView))).load();
    });
    final boundary = GlobalKey();
    final uri = Uri.parse('https://www.trtbt.com/event/a-long-event-invitation-id');
    final base = AppTheme.dark;
    await tester.pumpWidget(MaterialApp(theme: base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: base.appBarTheme.copyWith(titleTextStyle: const TextStyle(fontFamily:'Roboto', fontSize:20)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: base.outlinedButtonTheme.style?.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily:'Roboto'))))),
      home: RepaintBoundary(key: boundary, child: InviteQrScreen(title:'Akşam yürüyüşü', subtitle:'Elazığ • Etkinlik daveti', uri:uri))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/design-review').create(recursive: true);
      await File('build/design-review/invite.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Davet bağlantısını göster'));
    await tester.pumpAndSettle();
    expect(find.text(uri.toString()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
