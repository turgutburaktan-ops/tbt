import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/screens/post_photo_crop_screen.dart';
import '../lib/services/post_photo_capture_service.dart';

void main() {
  test('pan and zoom stay inside portrait, landscape and square originals', () {
    for (final size in [const Size(120, 200), const Size(200, 120), const Size(200, 200)]) {
      for (final width in [0.001, .2, .5, 1.0, 8.0]) {
        for (final center in [const Offset(-2, -2), const Offset(.5, .5), const Offset(3, 3)]) {
          final crop = photoCropRect(size, width, center);
          expect(crop.left, greaterThanOrEqualTo(-1e-12));
          expect(crop.top, greaterThanOrEqualTo(-1e-12));
          expect(crop.right, lessThanOrEqualTo(1 + 1e-12));
          expect(crop.bottom, lessThanOrEqualTo(1 + 1e-12));
          expect(crop.width * size.width / (crop.height * size.height), closeTo(.8, 1e-10));
        }
      }
    }
  });

  test('selected off-center rectangle exports the same source pixels', () {
    final original = img.Image(width: 120, height: 200);
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x < 120; x++) { original.setPixelRgb(x, y, x, y, 0); }
    }
    final crop = photoCropRect(const Size(120, 200), .4, const Offset(.7, .65));
    final result = cropPostPhoto(original, [crop.left, crop.top, crop.width, crop.height], 0);
    expect(result.width, 48);
    expect(result.height, 60);
    expect(result.getPixel(0, 0).r, 60);
    expect(result.getPixel(0, 0).g, 100);
    expect(original.width, 120);
  });

  testWidgets('editor drag, reset and confirm retain the initial camera frame', (tester) async {
    late Directory temp;
    late File file;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('tbt_crop_');
      file = File('${temp.path}/original.jpg');
      await file.writeAsBytes(img.encodeJpg(img.Image(width: 120, height: 200)));
    });
    addTearDown(() => temp.delete(recursive: true));
    Rect? selected;
    const initial = Rect.fromLTWH(.1, .2, .8, .6);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        selected = await Navigator.push<Rect>(context, MaterialPageRoute(builder: (_) =>
          PostPhotoCropScreen(original: file, initialCrop: initial, resetCrop: initial)));
      }, child: const Text('Aç')),
    ))));
    await tester.runAsync(() async {
      await tester.tap(find.text('Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final beforeDrag = tester.getTopLeft(find.byType(Image)).dy;
    await tester.drag(find.byType(Image), const Offset(0, 80));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(Image)).dy, greaterThan(beforeDrag));
    await tester.tap(find.text('Sıfırla'));
    await tester.pump();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(selected, isNotNull);
    expect(selected!.left, closeTo(initial.left, 1e-10));
    expect(selected!.top, closeTo(initial.top, 1e-10));
    expect(selected!.width, closeTo(initial.width, 1e-10));
  });
}
