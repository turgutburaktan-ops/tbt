import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Crops only new normal-camera photos. Originals and gallery files are retained.
class PostPhotoCaptureService {
  static Future<File> prepare(File input, Rect source, int previewQuarterTurns) async {
    final output = '${input.parent.path}/post_4x5_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await compute(_prepare, <String, Object>{
      'input': input.path, 'output': output,
      'rect': <double>[source.left, source.top, source.width, source.height],
      'turns': previewQuarterTurns,
    });
    return File(output);
  }
}

void _prepare(Map<String, Object> args) {
  final source = File(args['input'] as String);
  final decoded = img.decodeImage(source.readAsBytesSync());
  if (decoded == null) throw const FormatException('Çekilen fotoğraf okunamadı.');
  final result = cropPostPhoto(decoded, args['rect'] as List<double>, args['turns'] as int);
  final output = File(args['output'] as String);
  try {
    output.writeAsBytesSync(img.encodeJpg(result, quality: 98), flush: true);
  } catch (_) {
    if (output.existsSync()) output.deleteSync();
    rethrow;
  }
}

/// EXIF is baked once, including mirrored front-camera orientations. The device
/// rotation is then undone to match the portrait-locked preview coordinates.
@visibleForTesting
img.Image cropPostPhoto(img.Image decoded, List<double> rect, int previewQuarterTurns) {
  if (rect.length != 4 || rect.any((v) => !v.isFinite) ||
      rect[0] < 0 || rect[1] < 0 || rect[2] <= 0 || rect[3] <= 0 ||
      rect[0] + rect[2] > 1.000001 || rect[1] + rect[3] > 1.000001) {
    throw const FormatException('Fotoğraf kadrajı geçersiz.');
  }
  var oriented = img.bakeOrientation(decoded);
  final turns = previewQuarterTurns % 4;
  if (turns != 0) oriented = img.copyRotate(oriented, angle: turns * 90);
  // Rect.width/height subtraction can turn an exact pixel boundary into
  // 11.999999999999998. Ignore only that floating-point roundoff.
  final units = math.min(
      (math.min(oriented.width * rect[2] / 4,
          oriented.height * rect[3] / 5) + 1e-8).floor(),
      math.min(oriented.width ~/ 4, oriented.height ~/ 5));
  if (units < 1) throw const FormatException('Fotoğraf boyutu yetersiz.');
  final width = units * 4, height = units * 5;
  final x = ((rect[0] + rect[2] / 2) * oriented.width - width / 2)
      .round().clamp(0, oriented.width - width).toInt();
  final y = ((rect[1] + rect[3] / 2) * oriented.height - height / 2)
      .round().clamp(0, oriented.height - height).toInt();
  // No rescaling: retain every pixel inside the selected frame.
  return img.copyCrop(oriented, x: x, y: y, width: width, height: height);
}
