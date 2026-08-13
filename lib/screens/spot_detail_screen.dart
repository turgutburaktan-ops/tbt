import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/favorites_service.dart';
import '../widgets/spot_experience_sections.dart';
import '../widgets/spot_presence_section.dart';
import 'camera_screen.dart';

class SpotDetailScreen extends StatelessWidget {
  final PhotoSpot spot;

  const SpotDetailScreen({
    super.key,
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D1117),
            foregroundColor: Colors.white,
            actions: [
              ValueListenableBuilder<List<PhotoSpot>>(
                valueListenable: FavoritesService.savedSpots,
                builder: (context, savedSpots, _) {
                  final isSaved = savedSpots.any((item) => item.id == spot.id);
                  return IconButton(
                    tooltip: isSaved ? 'Kaydı kaldır' : 'Kaydet',
                    onPressed: () {
                      FavoritesService.toggle(spot);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isSaved
                                ? 'Kaydedilenlerden kaldırıldı.'
                                : 'Çekim noktası kaydedildi.',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? const Color(0xFFFFC107) : Colors.white,
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    spot.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: const Color(0xFF222831),
                        child: const Center(
                          child: Icon(Icons.photo, size: 70, color: Colors.white38),
                        ),
                      );
                    },
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0D1117)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(spot.city, style: const TextStyle(color: Colors.white60)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, size: 18, color: Color(0xFFFFC107)),
                      const SizedBox(width: 4),
                      Text(spot.rating.toString()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(icon: Icons.category_outlined, label: spot.category),
                      _InfoChip(icon: Icons.camera_alt_outlined, label: spot.recommendedLens),
                      _InfoChip(icon: Icons.route_outlined, label: spot.difficulty),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const _SectionTitle(icon: Icons.schedule, title: 'En İyi Çekim Zamanı'),
                  const SizedBox(height: 8),
                  _InfoCard(text: spot.bestTime),
                  const SizedBox(height: 20),
                  const _SectionTitle(icon: Icons.architecture, title: 'Önerilen Çekim Açısı'),
                  const SizedBox(height: 8),
                  _InfoCard(text: spot.angle),

                  const SizedBox(height: 24),
                  ShootingGuideSection(spot: spot),

                  const SizedBox(height: 18),
                  TogetherGoSection(spot: spot),

                  const SizedBox(height: 18),
                  SpotPresenceSection(spot: spot),

                  if (spot.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(icon: Icons.info_outline, title: 'Bu Nokta Hakkında'),
                    const SizedBox(height: 8),
                    Text(
                      spot.description,
                      style: const TextStyle(color: Colors.white70, height: 1.55, fontSize: 15),
                    ),
                  ],
                  if (spot.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(icon: Icons.sell_outlined, title: 'Etiketler'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spot.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor: const Color(0xFF171C24),
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraScreen()),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text(
                        'Bu Noktada Fotoğraf Çek',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFFFC107)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: const Color(0xFFFFC107)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
    );
  }
}
