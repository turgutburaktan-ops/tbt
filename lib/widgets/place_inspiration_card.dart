import '../services/nearby_venue_service.dart';

import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../theme/app_theme.dart';
import '../screens/spot_detail_screen.dart';
import 'spot_image.dart';

/// Uses only the published catalog; unavailable photos never get invented.
class PlaceInspirationCard extends StatefulWidget {
  const PlaceInspirationCard({super.key});
  @override
  State<PlaceInspirationCard> createState() => _PlaceInspirationCardState();
}

class _PlaceInspirationCardState extends State<PlaceInspirationCard> {
  late final Future<List<PhotoSpot>> _places = _load();
  Future<List<PhotoSpot>> _load() async {
    try {
      return await SpotRepository.instance
          .discover(
            query: SpotDiscoveryQuery(
              city: NearbyVenueService.instance.selectedCityName,
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PhotoSpot>>(
    future: _places,
    builder: (context, snapshot) {
      final spots = snapshot.data ?? const <PhotoSpot>[];
      if (spots.isEmpty)
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Yeni bir sokak, güzel bir manzara, birlikte bir kahve. İlk durağı seçelim.',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        );
      final spot = spots[DateTime.now().day % spots.length];
      return Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 120, child: SpotImage(spot: spot)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${spot.name} · ${spot.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
