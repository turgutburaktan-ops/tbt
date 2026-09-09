import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../widgets/firebase_media_image.dart';

class BroadcastDetailScreen extends StatelessWidget {
  const BroadcastDetailScreen({super.key, required this.item});
  final AppNotificationItem item;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B172A),
    appBar: AppBar(title: const Text('TBT Duyurusu')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (item.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FirebaseMediaImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        const SizedBox(height: 20),
        Text(
          item.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SelectableText(
          item.body,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    ),
  );
}
