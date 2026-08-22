import 'dart:io';

import 'package:video_compress/video_compress.dart';

class PreparedVideoMedia {
  final File video;
  final File thumbnail;
  final int durationMs;

  const PreparedVideoMedia({
    required this.video,
    required this.thumbnail,
    required this.durationMs,
  });
}

class VideoMediaService {
  VideoMediaService._();
  static final instance = VideoMediaService._();

  static const int maxSourceBytes = 250 * 1024 * 1024;

  Future<PreparedVideoMedia> prepare(
    File source, {
    required Duration maxDuration,
  }) async {
    if (!await source.exists()) {
      throw Exception('Video dosyası bulunamadı.');
    }
    final bytes = await source.length();
    if (bytes <= 0) throw Exception('Video dosyası boş.');
    if (bytes > maxSourceBytes) {
      throw Exception('Video 250 MB sınırını aşıyor.');
    }

    final sourceInfo = await VideoCompress.getMediaInfo(source.path);
    final rawDuration = sourceInfo.duration ?? 0;
    final durationMs = rawDuration.round();
    if (durationMs <= 0) {
      throw Exception('Video süresi okunamadı.');
    }
    if (durationMs > maxDuration.inMilliseconds + 250) {
      throw Exception(
        'Video en fazla ${maxDuration.inSeconds} saniye olabilir.',
      );
    }

    final compressed = await VideoCompress.compressVideo(
      source.path,
      quality: VideoQuality.Res1280x720Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final compressedPath = compressed?.path;
    if (compressedPath == null || compressedPath.trim().isEmpty) {
      throw Exception('Video sıkıştırılamadı.');
    }
    final compressedFile = File(compressedPath);
    if (!await compressedFile.exists() || await compressedFile.length() <= 0) {
      throw Exception('Sıkıştırılmış video hazırlanamadı.');
    }

    final thumbnail = await VideoCompress.getFileThumbnail(
      compressedPath,
      quality: 78,
      position: 500,
    );
    if (!await thumbnail.exists() || await thumbnail.length() <= 0) {
      throw Exception('Video önizlemesi hazırlanamadı.');
    }

    return PreparedVideoMedia(
      video: compressedFile,
      thumbnail: thumbnail,
      durationMs: durationMs,
    );
  }
}
