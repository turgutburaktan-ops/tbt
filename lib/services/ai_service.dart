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
  static const String baseUrl = 'https://tbt-tx25.onrender.com';

  static Future<PhotoAnalysis> analyzePhoto(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) throw Exception('Fotoğraf bulunamadı.');

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await request.send().timeout(const Duration(seconds: 75));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('AI analizi başarısız: ${response.statusCode}\n${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('AI sunucusundan geçersiz yanıt alındı.');
    }
    return PhotoAnalysis.fromJson(decoded);
  }

  static Future<LiveFrameAnalysis> analyzeLiveFrame({
    required String imagePath,
    required String mode,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) throw Exception('Kamera karesi bulunamadı.');

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/live-analyze'));
    request.fields['mode'] = mode;
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Canlı AI başarısız: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Canlı AI geçersiz yanıt verdi.');
    }
    return LiveFrameAnalysis.fromJson(decoded);
  }

  static Future<AiEditResult> editPhoto({
    required String imagePath,
    required String action,
    double? pointX,
    double? pointY,
    String? prompt,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Düzenlenecek fotoğraf bulunamadı.');
    }

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/edit-photo'));
    request.fields['action'] = action;

    if (pointX != null) request.fields['point_x'] = pointX.toStringAsFixed(5);
    if (pointY != null) request.fields['point_y'] = pointY.toStringAsFixed(5);
    if (prompt != null && prompt.trim().isNotEmpty) {
      request.fields['prompt'] = prompt.trim();
    }

    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('AI düzenleme başarısız: ${response.statusCode}\n${response.body}');
    }

    List<int> outputBytes;
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().startsWith('image/')) {
      outputBytes = response.bodyBytes;
    } else {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('AI düzenleme geçersiz yanıt verdi.');
      }
      final imageBase64 = decoded['image_base64']?.toString();
      if (imageBase64 == null || imageBase64.isEmpty) {
        throw Exception('AI düzenleme sonucunda görsel dönmedi.');
      }
      outputBytes = base64Decode(imageBase64);
    }

    final outputPath =
        '${Directory.systemTemp.path}/ai_edit_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final output = File(outputPath);
    await output.writeAsBytes(outputBytes, flush: true);
    return AiEditResult(outputPath: output.path);
  }
}
