import 'dart:async';
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
  // Playback files stay below the Storage limit and remain decodable on
  // mid-range Android/iOS devices. The original local file is never deleted.
  static const int maxPreparedBytes = 100 * 1024 * 1024;

  Future<void> _pending = Future<void>.value();

  Future<PreparedVideoMedia> prepare(
    File source, {
    required Duration? maxDuration,
    int? startSeconds,
    int? durationSeconds,
    bool includeAudio = true,
  }) {
    // video_compress owns one native compressor. Serialize uploads from different
    // screens, including callers which stopped waiting after their UI timeout.
    final result = _pending.then((_) => _prepare(source,
      maxDuration: maxDuration, startSeconds: startSeconds,
      durationSeconds: durationSeconds, includeAudio: includeAudio));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<PreparedVideoMedia> _prepare(
    File source, {
    required Duration? maxDuration,
    int? startSeconds,
    int? durationSeconds,
    required bool includeAudio,
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
    final durationMs = durationSeconds != null
        ? durationSeconds * 1000
        : rawDuration.round();
    if ((startSeconds ?? 0) < 0 ||
        ((startSeconds ?? 0) * 1000 + durationMs) > rawDuration + 250)
      throw Exception('Geçersiz video aralığı.');
    if (durationMs <= 0) {
      throw Exception('Video süresi okunamadı.');
    }
    if (maxDuration != null && durationMs > maxDuration.inMilliseconds + 250) {
      throw Exception(
        'Video en fazla ${maxDuration.inSeconds} saniye olabilir.',
      );
    }

    // HighestQuality could leave 4K/HEVC or an unusually high bitrate in the
    // feed. This 1080p profile normalizes the upload to a broadly compatible
    // MP4 playback profile while keeping a visibly good result.
    final compressed = await VideoCompress.compressVideo(
      source.path,
      quality: VideoQuality.Res1920x1080Quality,
      deleteOrigin: false,
      includeAudio: includeAudio,
      startTime: startSeconds ?? 0,
      duration: durationSeconds,
    );
    final compressedPath = compressed?.path;
    if (compressedPath == null || compressedPath.trim().isEmpty) {
      throw Exception('Video sıkıştırılamadı.');
    }
    final compressedFile = File(compressedPath);
    if (!await compressedFile.exists() || await compressedFile.length() <= 0) {
      throw Exception('Sıkıştırılmış video hazırlanamadı.');
    }
    if (await compressedFile.length() > maxPreparedBytes) {
      throw Exception('Video işlenemedi: dosya boyutu çok yüksek.');
    }

    final thumbnail = await VideoCompress.getFileThumbnail(
      compressedPath,
      quality: 92,
      position: durationMs < 500 ? 0 : 500,
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
