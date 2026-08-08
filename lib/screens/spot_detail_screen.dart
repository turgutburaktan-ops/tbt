import 'package:flutter/material.dart';
import '../models/photo_spot.dart';
import 'camera_screen.dart';

class SpotDetailScreen extends StatelessWidget {
  final PhotoSpot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(spot.name),
              background: Image.network(spot.imageUrl, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⭐ ${spot.rating}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 18),
                  _InfoCard(
                    icon: Icons.wb_sunny_outlined,
                    title: 'En iyi çekim zamanı',
                    value: spot.bestTime,
                  ),
                  _InfoCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Önerilen açı',
                    value: spot.angle,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraScreen(spot: spot),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Bu Noktada Fotoğraf Çek'),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151A22),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFFC107)),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
