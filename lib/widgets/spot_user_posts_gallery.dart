import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../screens/post_detail_screen.dart';
import '../services/post_service.dart';
import 'firebase_media_image.dart';
import 'venue_reviews_section.dart';

class SpotUserPostsGallery extends StatelessWidget {
  final PhotoSpot spot;
  const SpotUserPostsGallery({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: PostService.instance.allPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Shell(
                child: SizedBox(
                  height: 92,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFB7BCC2),
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            final matches = docs.where((doc) => _matches(doc.data(), spot)).toList()
              ..sort((a, b) => _score(b.data(), spot).compareTo(_score(a.data(), spot)));
            final top = matches.take(9).toList(growable: false);

            if (top.isEmpty) {
              return _Shell(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7BCC2).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFFB7BCC2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Henüz paylaşım yok',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Bu noktadan yapılan kullanıcı paylaşımları burada görünecek.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 21,
                      color: Color(0xFFB7BCC2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu Noktadan Paylaşımlar',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: top.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  itemBuilder: (context, index) {
                    final data = top[index].data();
                    final url = (data['imageUrl'] ?? '').toString();
                    final storagePath = (data['storagePath'] ?? '').toString();
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: data),
                        ),
                      ),
                      child: Hero(
                        tag: 'spot-post-${top[index].id}',
                        child: Container(
                          color: const Color(0xFF121416),
                          child: url.isEmpty && storagePath.isEmpty
                              ? const Icon(Icons.image_outlined, color: Colors.white30)
                              : FirebaseMediaImage(
                                  imageUrl: url,
                                  storagePath: storagePath,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.low,
                                  errorWidget: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Row(
          children: [
            Icon(Icons.rate_review_outlined, size: 21, color: Color(0xFFB7BCC2)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Puanlar ve Yorumlar',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        VenueReviewsSection(
          category: 'spot',
          venueId: spot.id,
          venueName: spot.name,
        ),
      ],
    );
  }

  static double _score(Map<String, dynamic> post, PhotoSpot spot) {
    final likes = (post['likesCount'] as num?)?.toDouble() ?? 0;
    final comments = (post['commentsCount'] as num?)?.toDouble() ?? 0;
    final createdAt = post['createdAt'];
    var score = likes * 3.0 + comments * 5.0;

    if (createdAt is Timestamp) {
      final ageDays = DateTime.now().difference(createdAt.toDate()).inHours / 24.0;
      score += 12.0 / (1.0 + (ageDays / 14.0));
    }

    final postName = _normalize(
      (post['spotName'] ?? post['locationName'] ?? post['location'] ?? '').toString(),
    );
    final spotName = _normalize(spot.name);
    if (postName == spotName && postName.isNotEmpty) {
      score += 20;
    } else if (postName.isNotEmpty &&
        spotName.isNotEmpty &&
        (postName.contains(spotName) || spotName.contains(postName))) {
      score += 12;
    }

    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final distance = _distanceMeters(lat, lng, spot.latitude, spot.longitude);
      if (distance <= 100) {
        score += 18;
      } else if (distance <= 250) {
        score += 12;
      } else if (distance <= 500) {
        score += 6;
      }
    }
    return score;
  }

  static bool _matches(Map<String, dynamic> post, PhotoSpot spot) {
    final postName = _normalize(
      (post['spotName'] ?? post['locationName'] ?? post['location'] ?? '').toString(),
    );
    final spotName = _normalize(spot.name);

    if (postName.isNotEmpty && spotName.isNotEmpty) {
      if (postName == spotName ||
          postName.contains(spotName) ||
          spotName.contains(postName)) {
        return true;
      }
      final postTokens = postName.split(' ').where((e) => e.length > 2).toSet();
      final spotTokens = spotName.split(' ').where((e) => e.length > 2).toSet();
      if (postTokens.intersection(spotTokens).length >= math.min(2, spotTokens.length)) {
        return true;
      }
    }

    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;
    return _distanceMeters(lat, lng, spot.latitude, spot.longitude) <= 500;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double value) => value * math.pi / 180;
}

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF121416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
}
