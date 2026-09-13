import '../widgets/profile_name_link.dart';
import 'reels_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/content_engagement_service.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/discover_content_grid.dart';
import 'post_detail_screen.dart';
import '../widgets/discover_post_feed.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/spot_repository.dart';
import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import '../theme/app_theme.dart';
import '../widgets/categorized_search.dart';
import 'user_profile_screen.dart';
import 'spot_detail_screen.dart';
import 'business_profile_screen.dart';

class HomeDiscoverScreen extends StatefulWidget {
  const HomeDiscoverScreen({super.key});
  @override
  State<HomeDiscoverScreen> createState() => _HomeDiscoverScreenState();
}

class _HomeDiscoverScreenState extends State<HomeDiscoverScreen> {
  String? _userQuery, _spotQuery, _venueQuery;
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _userSearchFuture;
  Future<List<PhotoSpot>>? _spotSearchFuture;
  Future<QuerySnapshot<Map<String, dynamic>>>? _venueSearchFuture;

  @override
  Widget build(BuildContext context) => CategorizedSearch(
    emptyBuilder: (_) => _buildExploreGrid(),
    resultsBuilder: (context, category, query) => switch (category) {
      SearchCategory.people => _userResults(query),
      SearchCategory.places => _spotResults(query),
      SearchCategory.venues => _venueResults(query),
    },
  );

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60),
      ),
    ),
  );

  Widget _failure(SearchCategory category) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${category.label} yüklenemedi.',
          style: const TextStyle(color: Colors.white60),
        ),
        TextButton(
          onPressed: () => setState(() {
            switch (category) {
              case SearchCategory.people:
                _userQuery = null;
              case SearchCategory.places:
                _spotQuery = null;
              case SearchCategory.venues:
                _venueQuery = null;
            }
          }),
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );

  String _normalize(Object? value) =>
      (value ?? '').toString().trim().toLowerCase().replaceAll('ı', 'i');

  String _titleCase(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');

  int _userMatchScore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String query,
  ) {
    final data = doc.data();
    final q = _normalize(query.replaceFirst(RegExp(r'^@'), ''));
    final displayName = _normalize(data['displayName'] ?? data['name']);
    final username = _normalize(data['username'] ?? data['userName'])
        .replaceFirst(RegExp(r'^@'), '');
    final city = _normalize(data['city']);
    final combined = '$displayName $username $city';
    final tokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    if (displayName == q) return 120;
    if (username == q) return 115;
    if (displayName.startsWith(q)) return 105;
    if (username.startsWith(q)) return 100;
    if (tokens.isNotEmpty && tokens.every(combined.contains)) return 85;
    if (displayName.contains(q)) return 75;
    if (username.contains(q)) return 70;
    if (combined.contains(q)) return 60;
    return 0;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findUsers(
    String rawQuery,
  ) async {
    final typed = rawQuery.trim().replaceFirst(RegExp(r'^@'), '');
    if (typed.length < 2) return const [];

    final users = FirebaseFirestore.instance.collection('users');
    var completedQueries = 0;
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final variants = <String>{
      typed,
      typed.toLowerCase(),
      _titleCase(typed),
    }.where((value) => value.trim().isNotEmpty);

    Future<void> addPrefix(String field, String prefix) async {
      try {
        final snap = await users
            .orderBy(field)
            .startAt([prefix])
            .endAt(['$prefix\uf8ff'])
            .limit(24)
            .get();
        completedQueries++;
        for (final doc in snap.docs) {
          if (doc.data()['accountStatus'] == 'frozen') continue;
          byId[doc.id] = doc;
        }
      } catch (_) {
        // Legacy user documents do not all have the same searchable fields.
        // The bounded fallback below still makes name search work for them.
      }
    }

    for (final prefix in variants) {
      await Future.wait([
        addPrefix('displayName', prefix),
        addPrefix('name', prefix),
        addPrefix('username', prefix),
        addPrefix('userName', prefix),
      ]);
    }

    // Backward compatibility for accounts created before normalized search
    // fields existed. This is intentionally bounded, while prefix queries above
    // handle the normal scalable path.
    try {
      final fallback = await users.limit(500).get();
      completedQueries++;
      for (final doc in fallback.docs) {
        if (doc.data()['accountStatus'] == 'frozen') continue;
        if (_userMatchScore(doc, typed) > 0) byId[doc.id] = doc;
      }
    } catch (_) {}

    if (completedQueries == 0) throw StateError('Kişiler yüklenemedi.');

    final ranked =
        byId.values
            .map((doc) => (doc: doc, score: _userMatchScore(doc, typed)))
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            final aName = _normalize(
              a.doc.data()['displayName'] ?? a.doc.data()['name'],
            );
            final bName = _normalize(
              b.doc.data()['displayName'] ?? b.doc.data()['name'],
            );
            return aName.compareTo(bName);
          });

    return ranked.take(12).map((item) => item.doc).toList();
  }

  String _firstMediaValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _hasMediaCandidate(Map<String, dynamic> data) {
    const keys = <String>[
      'thumbnailUrl',
      'coverUrl',
      'imageUrl',
      'mediaUrl',
      'storagePath',
      'thumbnailStoragePath',
      'videoUrl',
      'videoStoragePath',
    ];
    return keys.any((key) => (data[key] ?? '').toString().trim().isNotEmpty);
  }

  Future<void> _likeOnDoubleTap(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Beğenmek için giriş yapmalısın.')),
          );
      }
      return;
    }

    final data = doc.data();
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(doc.id)
          .collection('likes')
          .doc(user.uid);
      final existing = await likeRef.get();
      if (existing.exists) return;

      final caption = (data['caption'] ?? '').toString().trim();
      await ContentEngagementService.instance.toggleLike(
        collection: 'posts',
        id: doc.id,
        ownerId: (data['userId'] ?? '').toString(),
        title: caption.isEmpty ? 'Gönderi' : caption,
        sourceType: 'post',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
      }
    }
  }

  Widget _explorePreview(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    bool isVideo,
  ) {
    final previewUrl = _firstMediaValue(
      data,
      isVideo
          ? const ['thumbnailUrl', 'coverUrl', 'imageUrl', 'mediaUrl']
          : const ['imageUrl', 'mediaUrl', 'thumbnailUrl', 'coverUrl'],
    );
    final storagePath = _firstMediaValue(
      data,
      isVideo
          ? const ['thumbnailStoragePath', 'storagePath']
          : const ['storagePath', 'thumbnailStoragePath'],
    );
    final userId = (data['userId'] ?? '').toString().trim();
    final fallbackPaths = <String>[
      if (isVideo && userId.isNotEmpty)
        'users/$userId/posts/${doc.id}_thumb.jpg',
      ...FirebaseMediaImage.postPaths(userId, doc.id),
    ];

    return FirebaseMediaImage(
      imageUrl: previewUrl,
      storagePath: storagePath,
      fallbackStoragePaths: fallbackPaths,
      fit: BoxFit.cover,
      placeholder: const ColoredBox(color: Color(0xFF171A1F)),
      errorWidget: ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Icon(
            isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined,
            color: Colors.white24,
            size: 30,
          ),
        ),
      ),
    );
  }

  void _openPostFeed(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int selectedIndex,
  ) {
    // Freeze the grid order while this route is open; live grid updates must
    // not replace the post currently being read.
    final posts = docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    final selected = posts[selectedIndex];
    if ((selected['videoUrl'] ?? '').toString().isNotEmpty ||
        selected['mediaType'] == 'video' ||
        (selected['videoStoragePath'] ?? '').toString().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReelsScreen(initialPost: selected),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DiscoverPostFeed(
          itemCount: posts.length,
          initialIndex: selectedIndex,
          itemBuilder: (_, index) => PostDetailScreen(
            key: ValueKey(posts[index]['id']),
            post: posts[index],
            embedded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildExploreGrid() =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .limit(120)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Keşfet içerikleri yüklenemedi.',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }
          if (!snapshot.hasData) {
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: .78,
              ),
              itemCount: 12,
              itemBuilder: (_, __) =>
                  const ColoredBox(color: Color(0xFF171A1F)),
            );
          }
          final docs =
              snapshot.data!.docs
                  .where(
                    (doc) =>
                        doc.data()['accountFrozen'] != true &&
                        _hasMediaCandidate(doc.data()),
                  )
                  .toList()
                ..sort((a, b) {
                  final av = a.data()['createdAt'];
                  final bv = b.data()['createdAt'];
                  final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
                  final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
                  return bt.compareTo(at);
                });
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Keşfet için henüz içerik yok.',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }
          return DiscoverContentGrid(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final videoUrl = (data['videoUrl'] ?? '').toString().trim();
              final isVideo =
                  videoUrl.isNotEmpty ||
                  (data['mediaType'] ?? '').toString() == 'video';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _likeOnDoubleTap(context, doc),
                onTap: () => _openPostFeed(docs, index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _explorePreview(doc, data, isVideo),
                    if (isVideo)
                      const Positioned(
                        left: 7,
                        bottom: 7,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );

  Widget _spotResults(String query) {
    if (_spotQuery != query) {
      _spotQuery = query;
      _spotSearchFuture = SpotRepository.instance.search(query, limit: 3000);
    }
    final future = _spotSearchFuture;
    return FutureBuilder<List<PhotoSpot>>(
      key: ValueKey('places:$query'),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _failure(SearchCategory.places);
        final spots = snapshot.data ?? const <PhotoSpot>[];
        if (spots.isEmpty) return _empty('Yer bulunamadı.');
        return _ResultSection(
          title: 'Gezilecek Yerler',
          children: spots
              .take(12)
              .map(
                (spot) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceStrong,
                    child: Icon(Icons.place_outlined, color: AppColors.cyan),
                  ),
                  title: Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${spot.city} • ${spot.category}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpotDetailScreen(spot: spot),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _userResults(String query) {
    if (_userQuery != query) {
      _userQuery = query;
      _userSearchFuture = _findUsers(query);
    }
    final future = _userSearchFuture;

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      key: ValueKey('people:$query'),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (snapshot.hasError) return _failure(SearchCategory.people);
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) return _empty('Kişi bulunamadı.');
        return _ResultSection(
          title: 'Kişiler',
          children: docs.map((doc) {
            final data = doc.data();
            final name =
                (data['displayName'] ??
                        data['name'] ??
                        data['userName'] ??
                        'Kullanıcı')
                    .toString();
            final username = (data['username'] ?? data['userName'] ?? '')
                .toString();
            final photo =
                (data['photoUrl'] ??
                        data['photoURL'] ??
                        data['profilePhotoUrl'] ??
                        '')
                    .toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0D1B30),
                backgroundImage: photo.trim().isEmpty
                    ? null
                    : NetworkImage(photo),
                child: photo.trim().isEmpty
                    ? Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
                      )
                    : null,
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: username.trim().isEmpty
                  ? null
                  : Text(username.startsWith('@') ? username : '@$username'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: doc.id),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _venueResults(String query) {
    if (_venueQuery != query) {
      _venueQuery = query;
      _venueSearchFuture = FirebaseFirestore.instance
          .collection('business_venues')
          .limit(80)
          .get();
    }
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('venues:$query'),
      future: _venueSearchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _failure(SearchCategory.venues);
        final needle = _normalize(query);
        final docs = (snapshot.data?.docs ?? [])
            .where((doc) {
              final data = doc.data();
              return [
                'venueName',
                'name',
                'city',
                'address',
              ].any((field) => _normalize(data[field]).contains(needle));
            })
            .take(12)
            .toList();
        if (docs.isEmpty) return _empty('Mekân bulunamadı.');
        return _ResultSection(
          title: 'Mekânlar',
          children: docs.map((doc) {
            final data = doc.data();
            final name = (data['venueName'] ?? data['name'] ?? 'Mekân')
                .toString();
            final address = (data['city'] ?? data['address'] ?? '').toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: address.isEmpty
                  ? null
                  : Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final venue = NearbyVenue.fromJson({
                  'id': data['venueId'] ?? doc.id,
                  'category': data['category'] ?? 'dining',
                  'name': name,
                  'latitude': data['latitude'] ?? 0,
                  'longitude': data['longitude'] ?? 0,
                  'address': data['address'] ?? '',
                  'openingHours': data['openingHours'] ?? '',
                  'phone': data['phone'] ?? '',
                  'website': data['website'] ?? '',
                  'imageUrl': data['coverImageUrl'] ?? data['imageUrl'] ?? '',
                  'description': data['description'] ?? '',
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessProfileScreen(venue: venue),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    key: PageStorageKey(title),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
    children: children,
  );
}
