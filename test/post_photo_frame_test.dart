import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/utils/post_photo_frame.dart';

void main() {
  test('frame fits 4:5 between controls on narrow, tall and short screens', () {
    for (final canvas in [const Size(320,568), const Size(400,800), const Size(430,932), const Size(800,600)]) {
      for (final preview in [const Size(900,1600), const Size(1200,1600)]) {
        final result = PostPhotoFrame.calculate(canvas: canvas, preview: preview, topInset:24,bottomInset:24);
        expect(result.viewport.width / result.viewport.height, closeTo(4/5, 1e-10));
        expect(result.viewport.top, greaterThanOrEqualTo(88));
        expect(result.viewport.bottom, lessThanOrEqualTo(canvas.height-262+1e-8));
        expect(result.source.left, greaterThanOrEqualTo(0));
        expect(result.source.top, greaterThanOrEqualTo(0));
        expect(result.source.right, lessThanOrEqualTo(1+1e-8));
        expect(result.source.bottom, lessThanOrEqualTo(1+1e-8));
        // Reverse the normalized mapping and compare every visible edge.
        final scale = (canvas.width/preview.width).clamp(0,canvas.height/preview.height);
        final origin = Offset((canvas.width-preview.width*scale)/2,(canvas.height-preview.height*scale)/2);
        expect(origin.dx+result.source.left*preview.width*scale,closeTo(result.viewport.left,1e-8));
        expect(origin.dy+result.source.top*preview.height*scale,closeTo(result.viewport.top,1e-8));
        expect(result.source.width*preview.width*scale,closeTo(result.viewport.width,1e-8));
        expect(result.source.height*preview.height*scale,closeTo(result.viewport.height,1e-8));
      }
    }
  });
}
