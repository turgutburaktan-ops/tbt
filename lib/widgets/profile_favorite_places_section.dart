import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/curated_photo_spots.dart';
import '../data/curated_photo_spots_cities.dart';
import '../data/curated_photo_spots_extra.dart';
import '../data/curated_photo_spots_official_bulk.dart';
import '../data/curated_photo_spots_official_complete.dart';
import '../data/curated_photo_spots_official_routes.dart';
import '../data/curated_photo_spots_regions.dart';
import '../data/curated_photo_spots_verified_expansion.dart';
import '../models/nearby_venue.dart';
import '../models/photo_spot.dart';
import '../screens/retention_hub_screen.dart';
import '../screens/rewards_hub_screen.dart';
import '../services/location_service.dart';
import '../services/nationwide_candidate_spot_resolver.dart';
import '../services/nearby_venue_service.dart';

class ProfileFavoritePlacesSection extends StatelessWidget {
  final String userId;
  final bool editable;

  const ProfileFavoritePlacesSection({
    super.key,
    required this.userId,
    this.editable = false,
  });

  static const _types = <_FavoriteType>[
    _FavoriteType('cafe', 'Kafe', Icons.local_cafe_outlined),
    _FavoriteType('dining', 'Lezzet', Icons.restaurant_outlined),
    _FavoriteType('spot', 'Gezilecek', Icons.place_outlined),
  ];

  String _levelName(int xp) {
    if (xp >= 6000) return 'Türkiye Kaşifi';
    if (xp >= 3000) return 'Usta Kaşif';
    if (xp >= 1500) return 'Şehir Rehberi';
    if (xp >= 600) return 'Fotoğraf Avcısı';
    if (xp >= 200) return 'Kaşif';
    return 'Gezgin';
  }

  int _nextLevelXp(int xp) {
    if (xp < 200) return 200;
    if (xp < 600) return 600;
    if (xp < 1500) return 1500;
    if (xp < 3000) return 3000;
    if (xp < 6000) return 6000;
    return 6000;
  }

  int _levelFloor(int xp) {
    if (xp >= 6000) return 6000;
    if (xp >= 3000) return 3000;
    if (xp >= 1500) return 1500;
    if (xp >= 600) return 600;
    if (xp >= 200) return 200;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final raw = profile['favoritePlaces'];
        final favorites = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final hasAny = _types.any((type) => favorites[type.key] is Map);
        final xp = (profile['xp'] as num?)?.toInt() ?? 0;

        if (!editable && !hasAny && xp <= 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (editable || xp > 0) ...[
                _ProgressCard(
                  profile: profile,
                  userId: userId,
                  xp: xp,
                  level: _levelName(xp),
                  nextLevelXp: _nextLevelXp(xp),
                  levelFloor: _levelFloor(xp),
                  favoritesReady: hasAny,
                  editable: editable,
                ),
                const SizedBox(height: 14),
              ],
              if (editable || hasAny) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Favori Mekanlarım',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (editable)
                      const Text(
                        'Düzenle',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: _types.map((type) {
                    final value = favorites[type.key];
                    final data = value is Map
                        ? Map<String, dynamic>.from(value)
                        : null;
                    final name = (data?['name'] ?? '').toString().trim();
                    if (!editable && data == null)
                      return const SizedBox.shrink();
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: type == _types.last ? 0 : 6,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: editable ? () => _pick(context, type) : null,
                          child: Container(
                            height: 86,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11141A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF292E38),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  type.icon,
                                  size: 22,
                                  color: const Color(0xFFB8A1FF),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  type.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  name.isEmpty ? 'Seç' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: name.isEmpty
                                        ? Colors.white38
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, _FavoriteType type) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid != userId) return;
    final selected = await Navigator.push<_PlaceChoice>(
      context,
      MaterialPageRoute(builder: (_) => _FavoritePlacePicker(type: type)),
    );
    if (selected == null || !context.mounted) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(userId);
      if (selected.remove) {
        await ref.update({'favoritePlaces.${type.key}': FieldValue.delete()});
      } else {
        await ref.set({
          'favoritePlaces': {
            type.key: {
              'id': selected.id,
              'name': selected.name,
              'subtitle': selected.subtitle,
              'source': selected.source,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favori mekan güncellenemedi.')),
        );
      }
    }
  }
}

class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String userId;
  final int xp;
  final String level;
  final int nextLevelXp;
  final int levelFloor;
  final bool favoritesReady;
  final bool editable;

  const _ProgressCard({
    required this.profile,
    required this.userId,
    required this.xp,
    required this.level,
    required this.nextLevelXp,
    required this.levelFloor,
    required this.favoritesReady,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSelf = currentUser?.uid == userId;
    final settings = profile['settings'] is Map
        ? Map<String, dynamic>.from(profile['settings'] as Map)
        : const <String, dynamic>{};
    final interests = settings['interests'] is List
        ? settings['interests'] as List
        : const [];
    final displayName = (profile['displayName'] ?? '').toString().trim();
    final bio = (profile['bio'] ?? '').toString().trim();
    final photo = (profile['photoUrl'] ?? currentUser?.photoURL ?? '')
        .toString()
        .trim();
    final profileReady =
        displayName.length >= 2 && (bio.isNotEmpty || photo.isNotEmpty);
    final phoneReady = isSelf && (currentUser?.phoneNumber ?? '').isNotEmpty;
    final emailReady = isSelf && (currentUser?.emailVerified ?? false);
    final completed = [
      profileReady,
      interests.isNotEmpty,
      favoritesReady,
      phoneReady,
      emailReady,
    ].where((value) => value).length;

    final target = nextLevelXp == levelFloor ? 1 : nextLevelXp - levelFloor;
    final progress = nextLevelXp == levelFloor
        ? 1.0
        : ((xp - levelFloor) / target).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13161C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C3240)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8A1FF).withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFB8A1FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$xp XP • Başlangıç $completed/5',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (editable)
                IconButton(
                  tooltip: 'Görevler ve ödüller',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RewardsHubScreen()),
                  ),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: progress, minHeight: 7),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (profileReady)
                const _Badge(icon: Icons.person_rounded, label: 'Profil Hazır'),
              if (favoritesReady)
                const _Badge(icon: Icons.place_rounded, label: 'Mekan Kaşifi'),
              if (interests.isNotEmpty)
                const _Badge(
                  icon: Icons.auto_awesome_rounded,
                  label: 'İlgi Alanları',
                ),
              if (emailReady)
                const _Badge(
                  icon: Icons.verified_outlined,
                  label: 'E-posta Doğrulandı',
                ),
              if (phoneReady)
                const _Badge(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Telefon Doğrulandı',
                ),
              if (profile['badges'] is Map &&
                  (profile['badges'] as Map)['first1000'] == true)
                const _Badge(
                  icon: Icons.emoji_events_rounded,
                  label: 'TBT İlk 1000',
                ),
            ],
          ),
          if (editable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RewardsHubScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Görevler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RetentionHubScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                    ),
                    label: const Text('Bugün TBT'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFFB8A1FF)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _FavoritePlacePicker extends StatefulWidget {
  final _FavoriteType type;
  const _FavoritePlacePicker({required this.type});
  @override
  State<_FavoritePlacePicker> createState() => _FavoritePlacePickerState();
}

class _FavoritePlacePickerState extends State<_FavoritePlacePicker> {
  final _search = TextEditingController();
  late Future<List<_PlaceChoice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<_PlaceChoice>> _load() async {
    if (widget.type.key == 'spot') {
      final byId = <String, PhotoSpot>{};
      for (final group in <List<PhotoSpot>>[
        demoSpots,
        curatedPhotoSpots,
        curatedPhotoSpotsExtra,
        curatedPhotoSpotsCities,
        curatedPhotoSpotsRegions,
        curatedPhotoSpotsOfficialRoutes,
        curatedPhotoSpotsOfficialBulk,
        curatedPhotoSpotsVerifiedExpansion,
        curatedPhotoSpotsOfficialComplete,
      ]) {
        for (final spot in group) {
          byId[spot.id] = spot;
        }
      }
      final spots = NationwideCandidateSpotResolver.mergeInto(
        byId.values.toList(),
      );
      return spots
          .map(
            (spot) => _PlaceChoice(
              id: spot.id,
              name: spot.name,
              subtitle: spot.city,
              source: 'photo_spots',
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    final category = widget.type.key == 'cafe'
        ? NearbyVenueCategory.cafe
        : NearbyVenueCategory.dining;
    double latitude = 39;
    double longitude = 35;
    try {
      final position = await LocationService.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
      } else if (!NearbyVenueService.instance.hasSelectedCity) {
        throw StateError('Konum alınamadı ve seçili şehir yok.');
      }
    } catch (_) {
      if (!NearbyVenueService.instance.hasSelectedCity) rethrow;
    }

    final venues = await NearbyVenueService.instance
        .nearby(category: category, latitude: latitude, longitude: longitude)
        .timeout(const Duration(seconds: 12));
    return venues
        .map(
          (v) => _PlaceChoice(
            id: '${v.category.name}:${v.id}',
            name: v.name,
            subtitle: v.address,
            source: 'nearby_venues',
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        title: Text('Favori ${widget.type.label}'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _PlaceChoice.remove()),
            child: const Text('Kaldır'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Mekan ara...',
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_PlaceChoice>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 12),
                        Text(
                          'Yakındaki mekanlar hazırlanıyor…',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            'Mekanlar yüklenemedi. Konum iznini veya bağlantını kontrol et.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => setState(() => _future = _load()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  );
                }

                final q = _search.text.trim().toLowerCase();
                final items = (snapshot.data ?? const <_PlaceChoice>[])
                    .where(
                      (i) =>
                          q.isEmpty ||
                          '${i.name} ${i.subtitle}'.toLowerCase().contains(q),
                    )
                    .toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Bu kategoride eşleşen mekan yok.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFF242831)),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Icon(
                        widget.type.icon,
                        color: const Color(0xFFB8A1FF),
                      ),
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.subtitle.isEmpty
                          ? null
                          : Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteType {
  final String key, label;
  final IconData icon;
  const _FavoriteType(this.key, this.label, this.icon);
}

class _PlaceChoice {
  final String id, name, subtitle, source;
  final bool remove;
  const _PlaceChoice({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.source,
  }) : remove = false;
  const _PlaceChoice.remove()
    : id = '',
      name = '',
      subtitle = '',
      source = '',
      remove = true;
}
