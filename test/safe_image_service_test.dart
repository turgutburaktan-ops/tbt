import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/safe_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preview decoding bounds dimensions and preserves original file', () async {
    final dir = await Directory.systemTemp.createTemp('tbt_image_test');
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawPaint(ui.Paint()..color = const ui.Color(0xff204060));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1600, 900);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final file = File('${dir.path}/source.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      final original = await file.readAsBytes();
      expect(await SafeImageService.dimensions(file.path), const ui.Size(1600, 900));
      final thumb = await SafeImageService.thumbnail(file.path);
      final codec = await ui.instantiateImageCodec(thumb!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 400);
      expect(frame.image.height, 225);
      frame.image.dispose();
      codec.dispose();
      expect(await file.readAsBytes(), original);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
