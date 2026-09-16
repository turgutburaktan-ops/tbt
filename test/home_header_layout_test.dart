import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/home_header_layout.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('camera stays centred and all actions work at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final taps = [0, 0, 0, 0];
      final boundary = GlobalKey();
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root != null) await tester.runAsync(() async {
        await (FontLoader('Roboto')..addFont(File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf').readAsBytes().then(ByteData.sublistView))).load();
        await (FontLoader('MaterialIcons')..addFont(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView))).load();
      });
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark.copyWith(textTheme: AppTheme.dark.textTheme.apply(fontFamily:'Roboto')),
        home: RepaintBoundary(key: boundary, child: Scaffold(body: MediaQuery(
          data: MediaQueryData(size: Size(width, 240), textScaler: const TextScaler.linear(1.5)),
          child: HomeHeaderLayout(
            leading: const Text('TBT', style: TextStyle(fontSize:19, fontWeight:FontWeight.w900)),
            onCreate: () => taps[0]++,
            actions: [for (var i = 0; i < 3; i++) HomeHeaderAction(
              tooltip: 'action-$i',
              onTap: () => taps[i + 1]++,
              count: i > 0 ? 199 : 0,
              icon: [Icons.search_rounded, Icons.notifications_none_rounded, Icons.send_outlined][i],
            )],
          ),
        )))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final camera = find.byIcon(Icons.camera_alt_rounded);
      expect(tester.getCenter(camera).dx, closeTo(width / 2, .01));
      final cameraButton = find.ancestor(of:camera, matching:find.byType(InkWell));
      expect(tester.getSize(cameraButton), const Size(52,52));
      expect(tester.getRect(cameraButton).right, lessThanOrEqualTo(tester.getRect(find.byTooltip('action-0')).left));
      for (final label in find.text('99+').evaluate()) {
        final box = label.renderObject! as RenderBox;
        expect(box.localToGlobal(Offset(box.size.width, 0)).dx, lessThanOrEqualTo(width));
      }
      await tester.tap(camera);
      for (var i = 0; i < 3; i++) await tester.tap(find.byTooltip('action-$i'));
      expect(taps, [1,1,1,1]);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
        await Directory('build/camera-header-review').create(recursive:true);
        await File('build/camera-header-review/header-${width.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
