import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/content_engagement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';
import 'post_detail_screen.dart';
import 'reels_screen.dart';
import 'user_profile_screen.dart';

class HomeDiscoverScreen extends StatefulWidget {
  const HomeDiscoverScreen({super.key});

  @override
  State<HomeDiscoverScreen> createState() => _HomeDiscoverScreenState();
}

class _HomeDiscoverScreenState extends State<HomeDiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _userSearchFuture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  bool _matches(Map<String, dynamic> data, Iterable<String> keys) {
    if (_query.isEmpty) return true;
    final needle = _normalize(_query);
    return keys.any((key) => _normalize(data[key]).contains(needle));
  }

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
        for (final doc in snap.docs) {
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
      for (final doc in fallback.docs) {
        if (_userMatchScore(doc, typed) > 0) byId[doc.id] = doc;
      }
    } catch (_) {}

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

  void _onSearchChanged(String value) {
    final next = value.trim();
    setState(() {
      _query = next;
      _userSearchFuture = next.length < 2 ? null : _findUsers(next);
    });
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

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Kişi, kullanıcı adı, mekan veya etkinlik ara...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.cyan),
              ),
            ),
          ),
        ),
        Expanded(
          child: _query.isEmpty ? _buildExploreGrid() : _buildSearchResults(),
        ),
      ],
    ),
  );

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
                  .where((doc) => _hasMediaCandidate(doc.data()))
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
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: .78,
            ),
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
                onTap: () => isVideo
                    ? Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReelsScreen()),
                      )
                    : Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PostDetailScreen(post: {...data, 'id': doc.id}),
                        ),
                      ),
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

  Widget _buildSearchResults() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
    children: [
      _userResults(),
      _postResults(),
      _genericResults('businesses', 'Mekanlar', const [
        'name',
        'title',
        'businessName',
        'city',
        'address',
      ], Icons.storefront_outlined),
      _genericResults('events', 'Etkinlikler', const [
        'title',
        'name',
        'locationName',
        'city',
      ], Icons.event_outlined),
    ],
  );

  Widget _userResults() {
    final future = _userSearchFuture;
    if (_query.length < 2 || future == null) return const SizedBox.shrink();

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();
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
                backgroundColor: AppColors.surfaceStrong,
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

  Widget _postResults() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('posts')
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final docs = snapshot.data!.docs
          .where(
            (d) => _matches(d.data(), const [
              'caption',
              'spotName',
              'city',
              'locationName',
            ]),
          )
          .take(16)
          .toList();
      if (docs.isEmpty) return const SizedBox.shrink();
      return _ResultSection(
        title: 'İçerikler',
        children: docs.map((doc) {
          final data = doc.data();
          final caption = (data['caption'] ?? 'Gönderi').toString();
          final user = (data['userName'] ?? 'Kullanıcı').toString();
          final isVideo =
              (data['videoUrl'] ?? '').toString().trim().isNotEmpty ||
              (data['mediaType'] ?? '').toString() == 'video';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isVideo
                  ? Icons.play_circle_outline_rounded
                  : Icons.image_outlined,
            ),
            title: Text(
              caption.isEmpty ? 'Gönderi' : caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(user, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => isVideo
                ? Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReelsScreen()),
                  )
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostDetailScreen(post: {...data, 'id': doc.id}),
                    ),
                  ),
          );
        }).toList(),
      );
    },
  );

  Widget _genericResults(
    String collection,
    String title,
    List<String> keys,
    IconData icon,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection(collection)
        .limit(80)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final docs = snapshot.data!.docs
          .where((d) => _matches(d.data(), keys))
          .take(12)
          .toList();
      if (docs.isEmpty) return const SizedBox.shrink();
      return _ResultSection(
        title: title,
        children: docs.map((doc) {
          final data = doc.data();
          String primary = '';
          for (final key in keys) {
            final value = (data[key] ?? '').toString().trim();
            if (value.isNotEmpty) {
              primary = value;
              break;
            }
          }
          final city =
              (data['city'] ?? data['locationName'] ?? data['address'] ?? '')
                  .toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(
              primary.isEmpty ? title : primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: city.trim().isEmpty
                ? null
                : Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      );
    },
  );
}

class _ResultSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ResultSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    ),
  );
}
