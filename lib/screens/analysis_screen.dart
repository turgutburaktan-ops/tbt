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
  AiAnalysis? result;

  Future<void> _analyze() async {
    setState(() => analyzing = true);
    final data = await AiService.analyze(widget.image);
    if (!mounted) return;
    setState(() {
      result = data;
      analyzing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Fotoğraf Analizi')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              widget.image,
              height: 360,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 18),
          if (analyzing)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Fotoğraf analiz ediliyor...'),
                  ],
                ),
              ),
            )
          else if (result != null) ...[
            Card(
              color: const Color(0xFF151A22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Değerlendirmesi',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(result!.summary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...result!.suggestions.map(
              (suggestion) => Card(
                color: const Color(0xFF151A22),
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFFC107),
                  ),
                  title: Text(suggestion),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _analyze,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Tekrar Analiz Et'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
