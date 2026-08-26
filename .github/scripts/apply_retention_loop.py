from pathlib import Path

# Business profiles: surface social proof before tabs so venues feel alive, not like a directory.
p=Path('lib/screens/business_profile_screen.dart')
s=p.read_text()
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
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                                  child: Wrap(spacing: 14, runSpacing: 7, children: [
                                    if (favoriteCount > 0) Text('♥ $favoriteCount TBT kullanıcısının favorilerinde', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    if (postCount > 0) Text('▣ $postCount topluluk paylaşımı', style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                                  ]),
                                );
                              },
                            );
                          },
                        ),
                        if (!verified &&
                            FirebaseAuth.instance.currentUser != null) ...["""
if needle in s and 'favoriteVenueKeys' not in s:
    s=s.replace(needle,insert,1)
p.write_text(s)

# Nearby venues: remove implicit rating-first default. Start with Popular and explain social utility.
p=Path('lib/widgets/nearby_places_view.dart')
s=p.read_text().replace("String _sort = 'rating';", "String _sort = 'popular';")
p.write_text(s)

# Profile favorites component already writes favorites; additionally maintain a flat venue-key array for social proof queries.
p=Path('lib/widgets/profile_favorite_places.dart')
if p.exists():
    s=p.read_text()
    old="""await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      field: value,
    }, SetOptions(merge: true));"""
    new="""final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await ref.set({field: value}, SetOptions(merge: true));
    final fresh = (await ref.get()).data() ?? const <String, dynamic>{};
    final keys = <String>[];
    for (final key in const ['favoriteCafe', 'favoriteDining']) {
      final item = fresh[key];
      if (item is Map) {
        final venueKey = (item['venueKey'] ?? item['id'] ?? '').toString().trim();
        if (venueKey.isNotEmpty) keys.add(venueKey);
      }
    }
    await ref.set({'favoriteVenueKeys': keys.toSet().toList()}, SetOptions(merge: true));"""
    if old in s: s=s.replace(old,new,1)
    p.write_text(s)

# Event participation -> explicit post-event sharing prompt in event detail when user is a participant and event is over.
p=Path('lib/screens/event_deep_link_screen.dart')
if p.exists():
    s=p.read_text()
    if "import 'create_post_screen.dart';" not in s:
        s=s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n\nimport 'create_post_screen.dart';",1)
    marker="""children: ["""
    # Conservative: only patch if the screen exposes event data and no existing prompt.
    if 'Etkinlikten bir anı paylaş' not in s and "final data" in s:
        # Insert near first children list; guarded runtime fields avoid schema assumptions.
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
