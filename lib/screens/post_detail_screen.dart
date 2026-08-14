import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  String _dateLabel(dynamic value) {
    if (value is! Timestamp) return '';
    final d = value.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final caption = (post['caption'] ?? '').toString().trim();
    final spot = (post['spotName'] ?? post['locationName'] ?? post['location'] ?? '').toString().trim();
    final userName = (post['userName'] ?? 'Fotoğrafçı').toString();
    final date = _dateLabel(post['createdAt']);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: const Text('Paylaşım'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            color: Colors.black,
            constraints: const BoxConstraints(minHeight: 360, maxHeight: 620),
            child: imageUrl.isEmpty
                ? const Center(child: Icon(Icons.image_outlined, size: 70, color: Colors.white30))
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: true,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 70, color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF202833),
                      child: Icon(Icons.person, size: 18, color: Colors.white54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    if (date.isNotEmpty)
                      Text(date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(caption, style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 15)),
                ],
                if (spot.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 19, color: Color(0xFFFFC107)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(spot, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
