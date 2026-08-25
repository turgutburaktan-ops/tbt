import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
  int _filter = 0;

  static const _filters = ['Tümü', 'Kişiler', 'İçerikler', 'Mekanlar', 'Etkinlikler'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(Object? value) => (value ?? '').toString().trim().toLowerCase();

  bool _matches(Map<String, dynamic> data, Iterable<String> keys) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    for (final key in keys) {
      if (_normalize(data[key]).contains(needle)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Kişi, mekan, etkinlik veya içerik ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ChoiceChip(
                label: Text(_filters[index]),
                selected: _filter == index,
                onSelected: (_) => setState(() => _filter = index),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _query.isEmpty ? _buildExploreGrid() : _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildExploreGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').limit(120).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Keşfet içerikleri yüklenemedi.', style: TextStyle(color: Colors.white60)));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final av = a.data()['createdAt'];
            final bv = b.data()['createdAt'];
            final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
            final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
            return bt.compareTo(at);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('Keşfet için henüz içerik yok.', style: TextStyle(color: Colors.white60)));
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
            final imageUrl = (data['imageUrl'] ?? data['mediaUrl'] ?? '').toString().trim();
            final isVideo = videoUrl.isNotEmpty || (data['mediaType'] ?? '').toString() == 'video';
            final thumb = (data['thumbnailUrl'] ?? data['coverUrl'] ?? imageUrl).toString().trim();

            return InkWell(
              onTap: () {
                if (isVideo) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsScreen()));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...data, 'id': doc.id})),
                  );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.surface,
                    child: thumb.isEmpty
                        ? Icon(isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined, color: Colors.white30, size: 34)
                        : Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined, color: Colors.white30, size: 34),
                          ),
                  ),
                  if (isVideo)
                    const Positioned(
                      left: 7,
                      bottom: 7,
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 21),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final children = <Widget>[];
    if (_filter == 0 || _filter == 1) children.add(_userResults());
    if (_filter == 0 || _filter == 2) children.add(_postResults());
    if (_filter == 0 || _filter == 3) children.add(_genericResults('businesses', 'Mekanlar', const ['name', 'title', 'businessName', 'city', 'address'], Icons.storefront_outlined));
    if (_filter == 0 || _filter == 4) children.add(_genericResults('events', 'Etkinlikler', const ['title', 'name', 'locationName', 'city'], Icons.event_outlined));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: children,
    );
  }

  Widget _userResults() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(80).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          return _matches(data, const ['displayName', 'name', 'username', 'userName', 'city']);
        }).take(12).toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return _ResultSection(
          title: 'Kişiler',
          children: docs.map((doc) {
            final data = doc.data();
            final name = (data['displayName'] ?? data['name'] ?? data['userName'] ?? 'Kullanıcı').toString();
            final username = (data['username'] ?? data['userName'] ?? '').toString();
            final photo = (data['photoUrl'] ?? data['photoURL'] ?? data['profilePhotoUrl'] ?? '').toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceStrong,
                backgroundImage: photo.trim().isEmpty ? null : NetworkImage(photo),
                child: photo.trim().isEmpty ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()) : null,
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: username.trim().isEmpty ? null : Text(username.startsWith('@') ? username : '@$username'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: doc.id))),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _postResults() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          return _matches(data, const ['caption', 'userName', 'spotName', 'city', 'locationName']);
        }).take(16).toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return _ResultSection(
          title: 'İçerikler',
          children: docs.map((doc) {
            final data = doc.data();
            final caption = (data['caption'] ?? 'Gönderi').toString();
            final user = (data['userName'] ?? 'Kullanıcı').toString();
            final isVideo = (data['videoUrl'] ?? '').toString().trim().isNotEmpty || (data['mediaType'] ?? '').toString() == 'video';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined),
              title: Text(caption.isEmpty ? 'Gönderi' : caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(user, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                if (isVideo) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...data, 'id': doc.id})));
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _genericResults(String collection, String title, List<String> keys, IconData icon) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).limit(80).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs.where((doc) => _matches(doc.data(), keys)).take(12).toList();
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
            final city = (data['city'] ?? data['locationName'] ?? data['address'] ?? '').toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(primary.isEmpty ? title : primary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: city.trim().isEmpty ? null : Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        );
      },
    );
  }
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
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );
}
