import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/screens/route_filters_screen.dart';
import '../lib/screens/route_poll_create_screen.dart';
import '../lib/theme/app_theme.dart';

void main() {
  testWidgets('route screens render at phone size', (tester) async {
    tester.view.physicalSize = const Size(390,844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screens = <String,Widget>{
      'create': RouteCreateScreen(loadCatalog: (_) async => []),
      'filters': const RouteFiltersScreen(value: RouteFilters(),cities:['Elazığ','İstanbul']),
      'poll': const RoutePollCreateScreen(),
    };
    for(final entry in screens.entries) {
      final key=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(theme:AppTheme.dark,home:entry.value)));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,reason:entry.key);
      final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image=await boundary.toImage(pixelRatio:2);
        final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
        final file=File('build/route_previews/${entry.key}.png');
        await file.parent.create(recursive:true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
