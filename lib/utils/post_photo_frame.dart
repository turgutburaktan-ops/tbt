import 'dart:math' as math;
import 'dart:ui';

const postPhotoAspectRatio = 4 / 5;

/// Shares the same contain projection as the normal-photo camera preview.
/// The returned source rectangle is relative to the entire preview image.
class PostPhotoFrame {
  final Rect viewport;
  final Rect source;
  const PostPhotoFrame(this.viewport, this.source);

  static PostPhotoFrame calculate({
    required Size canvas,
    required Size preview,
    double topInset = 0,
    double bottomInset = 0,
  }) {
    final scale = math.min(canvas.width / preview.width, canvas.height / preview.height);
    final projected = Rect.fromCenter(
      center: Offset(canvas.width / 2, canvas.height / 2),
      width: preview.width * scale,
      height: preview.height * scale,
    );
    // Keep the existing top bar and bottom capture/mode controls outside the frame.
    final available = Rect.fromLTRB(0, topInset + 64, canvas.width,
      math.max(topInset + 65, canvas.height - bottomInset - 238));
    var area = projected.intersect(available);
    if (area.width <= 0 || area.height <= 0) area = projected;
    final width = math.min(area.width, area.height * postPhotoAspectRatio);
    final frame = Rect.fromCenter(center: area.center, width: width, height: width / postPhotoAspectRatio);
    return PostPhotoFrame(frame, Rect.fromLTWH(
      (frame.left - projected.left) / projected.width,
      (frame.top - projected.top) / projected.height,
      frame.width / projected.width,
      frame.height / projected.height,
    ));
  }
}
