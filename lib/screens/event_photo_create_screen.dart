import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../theme/app_theme.dart';
import 'event_create_screen_v2.dart';

class EventPhotoCreateScreen extends StatelessWidget {
  const EventPhotoCreateScreen({super.key});

  static const _templates = <_EventTemplate>[
    _EventTemplate(
      'Kahve içelim',
      'Yakında buluş, kahve iç, sohbet et',
      Icons.local_cafe_outlined,
      SocialEventType.foodDrink,
      6,
      Duration(hours: 1),
    ),
    _EventTemplate(
      'Fotoğraf çekelim',
      'Birlikte çekim için hızlı plan oluştur',
      Icons.photo_camera_outlined,
      SocialEventType.photography,
      8,
      Duration(hours: 2),
    ),
    _EventTemplate(
      'Yürüyüşe çıkalım',
      'Kısa bir yürüyüş planı başlat',
      Icons.directions_walk_rounded,
      SocialEventType.walking,
      10,
      Duration(hours: 1),
    ),
    _EventTemplate(
      'Birlikte gezelim',
      'Yeni bir yer keşfetmek için ekip kur',
      Icons.route_outlined,
      SocialEventType.trip,
      8,
      Duration(hours: 3),
    ),
    _EventTemplate(
      'Kampa gidelim',
      'Kamp planını birkaç dokunuşla başlat',
      Icons.cabin_outlined,
      SocialEventType.camping,
      8,
      Duration(days: 1),
    ),
    _EventTemplate(
      'Koşuya çıkalım',
      'Yakındaki koşucularla plan yap',
      Icons.directions_run_rounded,
      SocialEventType.running,
      10,
      Duration(hours: 1),
    ),
  ];

  void _open(BuildContext context, _EventTemplate template) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreateScreenV2(
          initialTitle: template.title,
          initialDescription: template.subtitle,
          initialCapacity: template.capacity,
          initialStartsAt: DateTime.now().add(template.startsAfter),
          initialType: template.type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Plan Başlat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const Text(
            'Bugün ne yapmak istersin?',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bir şablon seç. Başlık, tür, saat ve kişi sayısını hazırlayalım; sen sadece konumu ve kapak fotoğrafını tamamla.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _templates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final template = _templates[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _open(context, template),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(template.icon, color: AppColors.cyan),
                      ),
                      const Spacer(),
                      Text(
                        template.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        template.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const EventCreateScreenV2()),
            ),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Detaylı etkinlik oluştur'),
          ),
        ],
      ),
    );
  }
}

class _EventTemplate {
  final String title;
  final String subtitle;
  final IconData icon;
  final SocialEventType type;
  final int capacity;
  final Duration startsAfter;
  const _EventTemplate(
    this.title,
    this.subtitle,
    this.icon,
    this.type,
    this.capacity,
    this.startsAfter,
  );
}
