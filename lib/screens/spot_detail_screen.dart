import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/favorites_service.dart';
import '../services/invite_link_service.dart';
import '../widgets/spot_experience_sections.dart';
import '../widgets/spot_image.dart';
import '../widgets/spot_presence_section.dart';
import '../widgets/spot_user_posts_gallery.dart';
import 'camera_screen.dart';
import 'route_planner_screen.dart';

class SpotDetailScreen extends StatelessWidget {
  final PhotoSpot spot;

  const SpotDetailScreen({super.key, required this.spot});

  bool get _isAnitkabir {
    final name = spot.name.toLowerCase().replaceAll('ı', 'i');
    return name.contains('anitkabir');
  }

  String get _visitTitle => _isAnitkabir ? 'Neden Ziyaret Etmeli?' : 'Neden Gitmeli?';

  String get _visitDescription {
    if (_isAnitkabir) {
      return 'Anıtkabir, yalnızca ziyaret edilecek bir yer değil; Türkiye Cumhuriyeti’nin kurucusu Gazi Mustafa Kemal Atatürk’e duyulan saygı, minnet ve bağlılığın simgesidir. Cumhuriyetin hangi mücadelelerle kurulduğunu hatırlamak, Atatürk’ün bıraktığı mirası daha yakından hissetmek ve onun aziz hatırası önünde saygıyla durmak için her vatandaşın hayatında en az bir kez ziyaret etmesi gereken çok özel bir yerdir.';
    }
    return spot.description.trim().isEmpty ? 'Bu yer gezi kataloğunda öne çıkan duraklardan biri. Detaylar doğrulandıkça gezi bilgileri genişletilecek.' : spot.description.trim();
  }

  void _openPhoto(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: InteractiveViewer(minScale: 1, maxScale: 5, panEnabled: true, child: Center(child: SpotImage(spot: spot, width: double.infinity, fit: BoxFit.contain, highResolution: true))),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final verified = spot.tags.contains('Doğrulanmış');
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: const Color(0xFF090A0C),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'WhatsApp veya başka uygulamada paylaş',
                onPressed: () => InviteLinkService.instance.shareSpot(spotId: spot.id, spotName: spot.name, city: spot.city, latitude: spot.latitude, longitude: spot.longitude),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              ValueListenableBuilder<List<PhotoSpot>>(
                valueListenable: FavoritesService.savedSpots,
                builder: (context, savedSpots, _) {
                  final saved = savedSpots.any((item) => item.id == spot.id);
                  return IconButton(tooltip: saved ? 'Kaydı kaldır' : 'Kaydet', onPressed: () => FavoritesService.toggle(spot), icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? const Color(0xFFB7BCC2) : Colors.white));
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => _openPhoto(context),
                child: Stack(fit: StackFit.expand, children: [
                  SpotImage(spot: spot, fit: BoxFit.cover, highResolution: true),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE60D1117)]))),
                  if (verified) Positioned(left: 14, bottom: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, size: 16), SizedBox(width: 5), Text('Doğrulanmış')]))),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            sliver: SliverList.list(children: [
              Text(spot.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${spot.city} • ${spot.category} • ⭐ ${spot.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(initialSpot: spot))), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Burada Çek'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoutePlannerScreen(initialSpot: spot))), icon: const Icon(Icons.route_outlined), label: const Text('Rotaya Ekle'))),
              ]),
              const SizedBox(height: 24),
              Text(_visitTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_visitDescription, style: const TextStyle(color: Colors.white70, height: 1.55)),
              const SizedBox(height: 24),
              SpotExperienceSections(spot: spot),
              const SizedBox(height: 24),
              SpotPresenceSection(spot: spot),
              const SizedBox(height: 24),
              SpotUserPostsGallery(spot: spot),
            ]),
          ),
        ],
      ),
    );
  }
}
