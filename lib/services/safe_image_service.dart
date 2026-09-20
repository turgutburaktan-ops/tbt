import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Read dimensions from the encoded header, and decode only preview-sized pixels.
/// Originals are left untouched; large images are never decoded by Dart on the UI isolate.
class SafeImageService {
  static Future<ui.Size> dimensions(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<Uint8List?> thumbnail(String path, {int maxDimension = 400}) async {
    if (maxDimension < 1) throw ArgumentError.value(maxDimension);
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height ? descriptor.width : descriptor.height;
      final scale = longest > maxDimension ? maxDimension / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, maxDimension),
        targetHeight: (descriptor.height * scale).round().clamp(1, maxDimension),
      );
      image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      // Encode only the already downsampled preview off the UI isolate.
      return await compute(_previewJpeg, bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

Uint8List _previewJpeg(Uint8List bytes) {
  final image = img.decodePng(bytes);
  if (image == null) throw const FormatException('Önizleme oluşturulamadı.');
  return Uint8List.fromList(img.encodeJpg(image, quality: 75));
}
