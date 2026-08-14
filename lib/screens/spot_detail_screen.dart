import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/favorites_service.dart';
import '../widgets/spot_experience_sections.dart';
import '../widgets/spot_image.dart';
import '../widgets/spot_presence_section.dart';
import 'camera_screen.dart';

class SpotDetailScreen extends StatelessWidget {
  final PhotoSpot spot;

  const SpotDetailScreen({super.key, required this.spot});

  void _openPhoto(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            panEnabled: true,
            child: Center(
              child: SpotImage(
                spot: spot,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                  final saved = savedSpots.any((item) => item.id == spot.id);
                  return IconButton(
                    tooltip: saved ? 'Kaydı kaldır' : 'Kaydet',
                    onPressed: () => FavoritesService.toggle(spot),
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? const Color(0xFFFFC107) : Colors.white),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => _openPhoto(context),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SpotImage(spot: spot, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC0D1117)],
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 14,
                      bottom: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(spot.city, style: const TextStyle(color: Colors.white60))),
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
                  const SizedBox(height: 20),
                  _SocialActionButtons(spot: spot),
                  const SizedBox(height: 16),
                  _CompactShootingGuide(spot: spot),
                  const SizedBox(height: 24),
                  const _SectionTitle(icon: Icons.schedule, title: 'En İyi Çekim Zamanı'),
                  const SizedBox(height: 8),
                  _InfoCard(text: spot.bestTime),
                  const SizedBox(height: 20),
                  const _SectionTitle(icon: Icons.architecture, title: 'Önerilen Çekim Açısı'),
                  const SizedBox(height: 8),
                  _InfoCard(text: spot.angle),
                  if (spot.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(icon: Icons.info_outline, title: 'Bu Nokta Hakkında'),
                    const SizedBox(height: 8),
                    Text(spot.description, style: const TextStyle(color: Colors.white70, height: 1.55, fontSize: 15)),
                  ],
                  if (spot.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(icon: Icons.sell_outlined, title: 'Etiketler'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spot.tags.map((tag) => Chip(label: Text(tag), backgroundColor: const Color(0xFF171C24), side: BorderSide.none)).toList(),
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
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Bu Noktada Fotoğraf Çek', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _SocialActionButtons extends StatelessWidget {
  final PhotoSpot spot;
  const _SocialActionButtons({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionButton(
            icon: Icons.location_on_outlined,
            label: 'Buradayım',
            onPressed: () => _openActionSheet(context, title: 'Buradayım', child: SpotPresenceSection(spot: spot)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrimaryActionButton(
            icon: Icons.groups_2_outlined,
            label: 'Buluşalım',
            onPressed: () => _openActionSheet(context, title: 'Buluşalım', child: TogetherGoSection(spot: spot)),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PrimaryActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: Icon(icon, size: 21),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _CompactShootingGuide extends StatelessWidget {
  final PhotoSpot spot;
  const _CompactShootingGuide({required this.spot});

  @override
  Widget build(BuildContext context) {
    final angleSummary = spot.angle.trim().isEmpty ? 'Çekim rehberini aç' : spot.angle.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF151A22), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.auto_awesome, size: 20, color: Color(0xFFFFC107)), SizedBox(width: 8), Text('Nasıl Çekilir?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 9),
          Text('${spot.bestTime} • ${spot.recommendedLens}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(angleSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, height: 1.35, fontSize: 13)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openActionSheet(context, title: 'Nasıl Çekilir?', child: ShootingGuideSection(spot: spot)),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Rehberi Aç'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openActionSheet(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF0D1117),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), child: child)),
        ],
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFF171C24), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: const Color(0xFFFFC107)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]),
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 21, color: const Color(0xFFFFC107)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))]);
}

class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF151A22), borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
      );
}
