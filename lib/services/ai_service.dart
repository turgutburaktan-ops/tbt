import 'dart:io';
import 'package:http/http.dart' as http;

class AiAnalysis {
  final String summary;
  final List<String> suggestions;

  const AiAnalysis({
    required this.summary,
    required this.suggestions,
  });
}

class AiService {
  // Production'da bu URL kendi güvenli backend endpoint'in olmalı.
  // API anahtarlarını mobil uygulamaya koyma.
  static const String endpoint = 'https://YOUR-BACKEND.example.com/analyze';

  static Future<AiAnalysis> analyze(File image) async {
    // Backend hazır olduğunda multipart POST burada yapılabilir:
    //
    // final request = http.MultipartRequest('POST', Uri.parse(endpoint));
    // request.files.add(await http.MultipartFile.fromPath('image', image.path));
    // final response = await request.send();
    //
    // Şimdilik uygulamanın uçtan uca kamera akışını test edebilmek için
    // örnek analiz döndürüyoruz.
    await Future<void>.delayed(const Duration(seconds: 1));

    return const AiAnalysis(
      summary: 'Kadraj iyi, ancak ana konu biraz aşağıda kalmış.',
      suggestions: [
        '10-15 metre sola geçmeyi dene.',
        'Kamerayı yaklaşık 5° yukarı kaldır.',
        'Ana konuyu üst üçte birlik çizgiye yaklaştır.',
        'Işık daha yumuşakken tekrar çekmek daha iyi sonuç verebilir.',
      ],
    );
  }
}
