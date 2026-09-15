import 'dart:io';

import 'package:flutter/services.dart';

/// Memory-safe Android photo preparation used between capture and Studio.
///
/// The native side reads the JPEG from disk, bakes its EXIF orientation and
/// creates the centered 4:5 social-sharing frame without sending a full sensor
/// bitmap through Dart or the Flutter GPU.
class NativePhotoPipeline {
  NativePhotoPipeline._();

  static const MethodChannel _channel = MethodChannel('tbt/photo_pipeline');

  static Future<String> prepareSharePhoto(String inputPath) async {
    final outputPath =
        '${Directory.systemTemp.path}/tbt_share_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await _channel.invokeMethod<String>(
      'prepareSharePhoto',
      <String, Object>{
        'inputPath': inputPath,
        'outputPath': outputPath,
        'portraitWidth': 2160,
        'portraitHeight': 2700,
        'quality': 98,
        'maxDecodeDimension': 4600,
      },
    );
    if (result == null || result.isEmpty || !await File(result).exists()) {
      throw Exception('4:5 fotoğraf çıktısı oluşturulamadı.');
    }
    return result;
  }

  /// Builds only the lightweight Studio preview. [inputPath] remains the
  /// untouched full-resolution source used for sharing/export.
  static Future<String> prepareEditorPreview(String inputPath) async {
    final outputPath =
        '${Directory.systemTemp.path}/tbt_preview_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final result = await _channel.invokeMethod<String>(
      'prepareSharePhoto',
      <String, Object>{
        'inputPath': inputPath,
        'outputPath': outputPath,
        'portraitWidth': 1080,
        'portraitHeight': 1440,
        'quality': 92,
        'maxDecodeDimension': 2400,
      },
    );
    if (result == null || result.isEmpty || !await File(result).exists()) {
      throw Exception('Stüdyo önizlemesi oluşturulamadı.');
    }
    return result;
  }
}
