from pathlib import Path

p=Path('lib/screens/business_profile_screen.dart')
s=p.read_text()
if "import 'create_post_screen.dart';" not in s:
    s=s.replace("import 'business_hub_screen.dart';", "import 'business_hub_screen.dart';\nimport 'create_post_screen.dart';")

needle="""                        if (!verified &&
                            FirebaseAuth.instance.currentUser != null) ...["""
insert="""                        const SizedBox(height: 14),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('posts').where('venueKey', isEqualTo: _key).limit(20).snapshots(),
                          builder: (context, postSnap) {
                            final postCount = postSnap.data?.docs.length ?? 0;
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance.collection('users').where('favoriteVenueKeys', arrayContains: _key).limit(20).snapshots(),
                              builder: (context, favSnap) {
                                final favoriteCount = favSnap.data?.docs.length ?? 0;
                                if (postCount == 0 && favoriteCount == 0) return const SizedBox.shrink();
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('TBT’de bu mekan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 14, runSpacing: 7, children: [
                                      if (favoriteCount > 0) Text('♥ $favoriteCount kişinin favorilerinde', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                      if (postCount > 0) Text('▣ $postCount paylaşım', style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                                    ]),
                                  ]),
                                );
                              },
                            );
                          },
                        ),
                        if (FirebaseAuth.instance.currentUser != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(businessVenueKey: _key, businessVenueName: venue.name))),
                              icon: const Icon(Icons.place_outlined),
                              label: const Text('Buradaydım • Fotoğraf / Video Paylaş'),
                            ),
                          ),
                        ],
                        if (!verified &&
                            FirebaseAuth.instance.currentUser != null) ...["""
if needle in s and "Buradaydım • Fotoğraf / Video Paylaş" not in s:
    s=s.replace(needle,insert,1)
p.write_text(s)

p=Path('lib/widgets/nearby_places_view.dart')
s=p.read_text().replace("String _sort = 'rating';", "String _sort = 'popular';")
p.write_text(s)

p=Path('lib/widgets/profile_favorite_places_section.dart')
if p.exists():
    s=p.read_text()
    # Maintain query-friendly venue keys whenever favorite venue maps are saved.
    old="""await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({field: value}, SetOptions(merge: true));"""
    new="""final ref = FirebaseFirestore.instance.collection('users').doc(widget.userId);\n    await ref.set({field: value}, SetOptions(merge: true));\n    final fresh = (await ref.get()).data() ?? const <String, dynamic>{};\n    final keys = <String>[];\n    for (final key in const ['favoriteCafe', 'favoriteDining']) {\n      final item = fresh[key];\n      if (item is Map) {\n        final venueKey = (item['venueKey'] ?? item['id'] ?? '').toString().trim();\n        if (venueKey.isNotEmpty) keys.add(venueKey);\n      }\n    }\n    await ref.set({'favoriteVenueKeys': keys.toSet().toList()}, SetOptions(merge: true));"""
    if old in s: s=s.replace(old,new,1)
    p.write_text(s)

# Event participation -> post-event sharing prompt.
p=Path('lib/screens/event_deep_link_screen.dart')
if p.exists():
    s=p.read_text()
    if "import 'create_post_screen.dart';" not in s:
        s=s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n\nimport 'create_post_screen.dart';",1)
    marker="""children: ["""
    if 'Etkinlikten bir anı paylaş' not in s and "final data" in s:
        block="""children: [
              if (() {
                final raw = data['startsAt'];
                return raw is Timestamp && raw.toDate().isBefore(DateTime.now()) && FirebaseAuth.instance.currentUser != null;
              })()
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Etkinlikten bir anı paylaş'),
                  ),
                ),"""
        s=s.replace(marker,block,1)
        if "package:cloud_firestore/cloud_firestore.dart" not in s:
            s="import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';\n"+s
    p.write_text(s)
