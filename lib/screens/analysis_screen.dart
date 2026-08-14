import 'dart:io';

import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/ai_service.dart';

class AnalysisScreen extends StatefulWidget {
  final File image;
  final double? latitude;
  final double? longitude;
  final PhotoSpot? spot;

  const AnalysisScreen({
    super.key,
    required this.image,
    this.latitude,
    this.longitude,
    this.spot,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool analyzing = false;
  PhotoAnalysis? result;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    if (analyzing) return;

    setState(() {
      analyzing = true;
      errorMessage = null;
    });

    try {
      final data = await AiService.analyzePhoto(
        widget.image.path,
      );

      if (!mounted) return;

      setState(() {
        result = data;
        analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
        errorMessage = e.toString();
      });
    }
  }

  Widget _scoreRow(
    String title,
    int value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '$value/10',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = result;

    return Scaffold(
      backgroundColor: const Color(0xFF090D13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D13),
        foregroundColor: Colors.white,
        title: const Text(
          'Fotoğraf Analizi',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              widget.image,
              height: 320,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 22),
          if (analyzing)
            const Card(
              color: Color(0xFF11181D),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF16B8A6),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Fotoğraf AI tarafından analiz ediliyor...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (errorMessage != null && !analyzing)
            Card(
              color: const Color(0xFF11181D),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Analiz yapılamadı',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (analysis != null && !analyzing) ...[
            Card(
              color: const Color(0xFF11181D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      '${analysis.score}/100',
                      style: const TextStyle(
                        color: Color(0xFF16B8A6),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fotoğraf Skoru',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _scoreRow(
                      'Kompozisyon',
                      analysis.composition,
                    ),
                    _scoreRow(
                      'Işık',
                      analysis.lighting,
                    ),
                    _scoreRow(
                      'Perspektif',
                      analysis.perspective,
                    ),
                    _scoreRow(
                      'Netlik',
                      analysis.sharpness,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Değerlendirmesi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF11181D),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  analysis.summary,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fotoğrafı İyileştirmek İçin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...analysis.suggestions.map(
              (suggestion) => Card(
                color: const Color(0xFF11181D),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF16B8A6),
                  ),
                  title: Text(
                    suggestion,
                    style: const TextStyle(
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16B8A6),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(17),
            ),
            onPressed: analyzing ? null : _analyze,
            icon: const Icon(
              Icons.auto_awesome,
            ),
            label: Text(
              analyzing ? 'Analiz Ediliyor...' : 'Tekrar Analiz Et',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Kaydetme özelliği yakında aktif olacak.',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.favorite_border,
            ),
            label: const Text(
              'Kaydet',
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
