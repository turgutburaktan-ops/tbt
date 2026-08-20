import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class PhotoAnalysis {
  final int score;
  final int composition;
  final int lighting;
  final int perspective;
  final int sharpness;
  final String summary;
  final List<String> suggestions;

  const PhotoAnalysis({
    required this.score,
    required this.composition,
    required this.lighting,
    required this.perspective,
    required this.sharpness,
    required this.summary,
    required this.suggestions,
  });

  factory PhotoAnalysis.fromJson(Map<String, dynamic> json) {
    return PhotoAnalysis(
      score: (json['score'] as num? ?? 0).toInt(),
      composition: (json['composition'] as num? ?? 0).toInt(),
      lighting: (json['lighting'] as num? ?? 0).toInt(),
      perspective: (json['perspective'] as num? ?? 0).toInt(),
      sharpness: (json['sharpness'] as num? ?? 0).toInt(),
      summary: json['summary']?.toString() ?? '',
      suggestions: (json['suggestions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class LiveFrameAnalysis {
  final String status;
  final String mainTip;
  final String compositionTip;
  final String lightTip;
  final String subjectTip;
  final double recommendedEv;
  final int recommendedIso;
  final int recommendedShutterDenominator;

  const LiveFrameAnalysis({
    required this.status,
    required this.mainTip,
    required this.compositionTip,
    required this.lightTip,
    required this.subjectTip,
    required this.recommendedEv,
    required this.recommendedIso,
    required this.recommendedShutterDenominator,
  });

  factory LiveFrameAnalysis.fromJson(Map<String, dynamic> json) {
    return LiveFrameAnalysis(
      status: json['status']?.toString() ?? 'adjust',
      mainTip: json['main_tip']?.toString() ?? '',
      compositionTip: json['composition_tip']?.toString() ?? '',
      lightTip: json['light_tip']?.toString() ?? '',
      subjectTip: json['subject_tip']?.toString() ?? '',
      recommendedEv: (json['recommended_ev'] as num? ?? 0).toDouble(),
      recommendedIso: (json['recommended_iso'] as num? ?? 100).toInt(),
      recommendedShutterDenominator:
          (json['recommended_shutter_denominator'] as num? ?? 125).toInt(),
    );
  }
}

class AiEditResult {
  final String outputPath;
  const AiEditResult({required this.outputPath});
}

class AiService {
  // A new AI gateway can be supplied at build time. The existing Render
  // service stays in the APK as a hot fallback, so a provider outage, quota
  // error or a failed rollout does not remove the current camera tools.
  static const String _legacyBaseUrl = 'https://tbt-tx25.onrender.com';
  static const String _configuredPrimaryUrl = String.fromEnvironment(
    'TBT_AI_PRIMARY_URL',
    defaultValue: '',
  );

  static List<String> get _baseUrls {
    final primary = _normalizeBaseUrl(_configuredPrimaryUrl);
    final legacy = _normalizeBaseUrl(_legacyBaseUrl);
    return <String>{
      if (primary.isNotEmpty) primary,
      legacy,
    }.toList(growable: false);
  }

  static String _normalizeBaseUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static bool _canFallbackStatus(int statusCode) =>
      statusCode == 401 ||
      statusCode == 403 ||
      statusCode == 404 ||
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      statusCode >= 500;

  static String _shortBody(String value) {
    final clean = value.trim();
    return clean.length <= 800 ? clean : '${clean.substring(0, 800)}…';
  }

  static Future<PhotoAnalysis> analyzePhoto(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) throw Exception('Fotoğraf bulunamadı.');

    Object? lastError;
    final urls = _baseUrls;
    for (var i = 0; i < urls.length; i++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${urls[i]}/analyze'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
        final streamed =
            await request.send().timeout(const Duration(seconds: 75));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode != 200) {
          throw _AiHttpException(
            response.statusCode,
            'AI analizi başarısız: ${response.statusCode}\n'
            '${_shortBody(response.body)}',
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'AI sunucusundan geçersiz yanıt alındı.',
          );
        }
        return PhotoAnalysis.fromJson(decoded);
      } catch (error) {
        lastError = error;
        final canTryLegacy = i < urls.length - 1 &&
            (error is! _AiHttpException ||
                _canFallbackStatus(error.statusCode));
        if (!canTryLegacy) rethrow;
      }
    }
    throw Exception('AI analizi başarısız: $lastError');
  }

  static Future<LiveFrameAnalysis> analyzeLiveFrame({
    required String imagePath,
    required String mode,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) throw Exception('Kamera karesi bulunamadı.');

    Object? lastError;
    final urls = _baseUrls;
    for (var i = 0; i < urls.length; i++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${urls[i]}/live-analyze'),
        );
        request.fields['mode'] = mode;
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
        final streamed =
            await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode != 200) {
          throw _AiHttpException(
            response.statusCode,
            'Canlı AI başarısız: ${response.statusCode}',
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Canlı AI geçersiz yanıt verdi.');
        }
        return LiveFrameAnalysis.fromJson(decoded);
      } catch (error) {
        lastError = error;
        final canTryLegacy = i < urls.length - 1 &&
            (error is! _AiHttpException ||
                _canFallbackStatus(error.statusCode));
        if (!canTryLegacy) rethrow;
      }
    }
    throw Exception('Canlı AI başarısız: $lastError');
  }

  static Future<AiEditResult> editPhoto({
    required String imagePath,
    required String action,
    double? pointX,
    double? pointY,
    String? prompt,
    String? mode,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Düzenlenecek fotoğraf bulunamadı.');
    }

    Object? lastError;
    final urls = _baseUrls;
    for (var i = 0; i < urls.length; i++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${urls[i]}/edit-photo'),
        );
        request.fields['action'] = action;
        if (mode != null && mode.trim().isNotEmpty) {
          request.fields['mode'] = mode.trim();
        }
        if (pointX != null) {
          request.fields['point_x'] = pointX.toStringAsFixed(5);
        }
        if (pointY != null) {
          request.fields['point_y'] = pointY.toStringAsFixed(5);
        }
        if (prompt != null && prompt.trim().isNotEmpty) {
          request.fields['prompt'] = prompt.trim();
        }
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );

        final streamed =
            await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode != 200) {
          throw _AiHttpException(
            response.statusCode,
            'AI düzenleme başarısız: ${response.statusCode}\n'
            '${_shortBody(response.body)}',
          );
        }

        List<int> outputBytes;
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.toLowerCase().startsWith('image/')) {
          outputBytes = response.bodyBytes;
        } else {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException(
              'AI düzenleme geçersiz yanıt verdi.',
            );
          }
          final imageBase64 = decoded['image_base64']?.toString();
          if (imageBase64 == null || imageBase64.isEmpty) {
            throw const FormatException(
              'AI düzenleme sonucunda görsel dönmedi.',
            );
          }
          outputBytes = base64Decode(imageBase64);
        }

        final outputPath =
            '${Directory.systemTemp.path}/ai_edit_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final output = File(outputPath);
        await output.writeAsBytes(outputBytes, flush: true);
        return AiEditResult(outputPath: output.path);
      } catch (error) {
        lastError = error;
        final canTryLegacy = i < urls.length - 1 &&
            (error is! _AiHttpException ||
                _canFallbackStatus(error.statusCode));
        if (!canTryLegacy) rethrow;
      }
    }
    throw Exception('AI düzenleme başarısız: $lastError');
  }
}

class _AiHttpException implements Exception {
  final int statusCode;
  final String message;

  const _AiHttpException(this.statusCode, this.message);

  @override
  String toString() => message;
}
