import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileFavoritePlacesSection extends StatelessWidget {
  final String userId;
  final bool editable;

  const ProfileFavoritePlacesSection({
    super.key,
    required this.userId,
    this.editable = false,
  });

  static const _types = <_FavoriteType>[
    _FavoriteType('cafe', 'Favori Kafe', Icons.local_cafe_outlined),
    _FavoriteType('dining', 'Favori Lezzet Noktası', Icons.restaurant_outlined),
    _FavoriteType('spot', 'Favori Gezilecek Yer', Icons.place_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final raw = snapshot.data?.data()?['favoritePlaces'];
        final favorites = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final hasAny = _types.any((type) => favorites[type.key] is Map);
        if (!editable && !hasAny) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Favori Mekanlar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (editable)
                    const Text(
                      'Profilinde görünür',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ..._types.map((type) {
                final value = favorites[type.key];
                final data = value is Map
                    ? Map<String, dynamic>.from(value)
                    : null;
                if (!editable && data == null) return const SizedBox.shrink();
                final name = (data?['name'] ?? '').toString().trim();
                final subtitle = (data?['subtitle'] ?? '').toString().trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: editable ? () => _pick(context, type) : null,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11141A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF292E38)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F28),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              type.icon,
                              color: const Color(0xFFB8A1FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.label,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  name.isEmpty ? 'Favorini seç' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: name.isEmpty
                                        ? Colors.white38
                                        : Colors.white,
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (editable)
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white38,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
      if (selected.remove) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'favoritePlaces.${type.key}': FieldValue.delete()},
        );
      } else {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'favoritePlaces': {
            type.key: {
              'id': selected.id,
              'name': selected.name,
              'subtitle': selected.subtitle,
              'source': type.key == 'spot' ? 'photo_spots' : 'business_venues',
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favori mekan güncellenemedi.')),
        );
    }
  }
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
      final snap = await FirebaseFirestore.instance
          .collection('photo_spots')
          .where('status', isEqualTo: 'published')
          .limit(500)
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return _PlaceChoice(
          id: doc.id,
          name: (d['name'] ?? 'Gezilecek yer').toString(),
          subtitle: (d['city'] ?? d['district'] ?? '').toString(),
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));
    }
    final snap = await FirebaseFirestore.instance
        .collection('business_venues')
        .where('category', isEqualTo: widget.type.key)
        .limit(500)
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      final city = (d['city'] ?? '').toString().trim();
      final address = (d['address'] ?? '').toString().trim();
      return _PlaceChoice(
        id: doc.id,
        name: (d['venueName'] ?? d['name'] ?? 'Mekan').toString(),
        subtitle: city.isNotEmpty ? city : address,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        title: Text(widget.type.label),
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return const Center(
                    child: Text(
                      'Mekanlar yüklenemedi.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                final q = _search.text.trim().toLowerCase();
                final items = (snapshot.data ?? const <_PlaceChoice>[])
                    .where(
                      (item) =>
                          q.isEmpty ||
                          '${item.name} ${item.subtitle}'
                              .toLowerCase()
                              .contains(q),
                    )
                    .toList();
                if (items.isEmpty)
                  return const Center(
                    child: Text(
                      'Bu kategoride eşleşen mekan yok.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
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
  final String key;
  final String label;
  final IconData icon;
  const _FavoriteType(this.key, this.label, this.icon);
}

class _PlaceChoice {
  final String id;
  final String name;
  final String subtitle;
  final bool remove;
  const _PlaceChoice({
    required this.id,
    required this.name,
    required this.subtitle,
  }) : remove = false;
  const _PlaceChoice.remove()
    : id = '',
      name = '',
      subtitle = '',
      remove = true;
}
