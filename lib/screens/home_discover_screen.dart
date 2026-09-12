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
    resultsBuilder: (context, category, query) => switch (category) {
      SearchCategory.people => _userResults(query),
      SearchCategory.places => _spotResults(query),
      SearchCategory.venues => _venueResults(query),
    },
  );

  Widget _empty(String text) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white60)),
  ));

  Widget _failure(SearchCategory category) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('${category.label} yüklenemedi.', style: const TextStyle(color: Colors.white60)),
      TextButton(onPressed: () => setState(() {
        switch (category) {
          case SearchCategory.people: _userQuery = null;
          case SearchCategory.places: _spotQuery = null;
          case SearchCategory.venues: _venueQuery = null;
        }
      }), child: const Text('Tekrar dene')),
    ],
  ));

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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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
      _venueSearchFuture = FirebaseFirestore.instance.collection('business_venues').limit(80).get();
    }
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('venues:$query'),
      future: _venueSearchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _failure(SearchCategory.venues);
        final needle = _normalize(query);
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return ['venueName', 'name', 'city', 'address'].any((field) => _normalize(data[field]).contains(needle));
        }).take(12).toList();
        if (docs.isEmpty) return _empty('Mekân bulunamadı.');
        return _ResultSection(title: 'Mekânlar', children: docs.map((doc) {
          final data = doc.data();
          final name = (data['venueName'] ?? data['name'] ?? 'Mekân').toString();
          final address = (data['city'] ?? data['address'] ?? '').toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: address.isEmpty ? null : Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => BusinessProfileScreen(venue: venue)));
            },
          );
        }).toList());
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
