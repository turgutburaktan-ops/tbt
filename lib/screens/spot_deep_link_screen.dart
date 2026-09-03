import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import 'spot_detail_screen.dart';

class SpotDeepLinkScreen extends StatelessWidget {
  final String spotId;
  const SpotDeepLinkScreen({super.key, required this.spotId});

  Future<PhotoSpot?> _findSpot() async {
    final spots = await SpotRepository.instance.loadSpots(limit: 3000);
    for (final spot in spots) {
      if (spot.id == spotId) return spot;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gezilecek Yer')),
    body: FutureBuilder<PhotoSpot?>(
      future: _findSpot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final spot = snapshot.data;
        if (spot == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Bu gezilecek yer artık bulunamıyor.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          );
        });
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}
