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

  factory PhotoAnalysis.fromJson(
    Map<String, dynamic> json,
  ) {
    return PhotoAnalysis(
      score: (json['score'] as num? ?? 0).toInt(),
      composition:
          (json['composition'] as num? ?? 0).toInt(),
      lighting:
          (json['lighting'] as num? ?? 0).toInt(),
      perspective:
          (json['perspective'] as num? ?? 0).toInt(),
      sharpness:
          (json['sharpness'] as num? ?? 0).toInt(),
      summary: json['summary']?.toString() ?? '',
      suggestions:
          (json['suggestions'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
    );
  }
}

class AiService {
  static const String baseUrl =
      'https://tbt-tx25.onrender.com';

  static Future<PhotoAnalysis> analyzePhoto(
    String imagePath,
  ) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Fotoğraf bulunamadı.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/analyze'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imagePath,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'AI analizi başarısız: '
        '${response.statusCode}\n'
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'AI sunucusundan geçersiz yanıt alındı.',
      );
    }

    return PhotoAnalysis.fromJson(decoded);
  }
}
