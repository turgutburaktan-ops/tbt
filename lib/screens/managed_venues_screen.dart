import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'business_hub_screen.dart';
import 'business_profile_editor_screen.dart';

class ManagedVenuesScreen extends StatelessWidget {
  const ManagedVenuesScreen({super.key});

  String _categoryLabel(String value) => switch (value) {
    'cafe' => 'Kafe',
    'dining' => 'Lezzet',
    'hotel' => 'Otel / Konaklama',
    _ => 'Mekan',
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Bu alan için giriş yapmalısın.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yönettiğim Mekanlar')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('business_venues')
            .where('ownerUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Mekanların yüklenemedi. Daha sonra tekrar dene.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snapshot.data!.docs
                  .where((doc) => doc.data()['verified'] == true)
                  .toList()
                ..sort(
                  (a, b) => (a.data()['venueName'] ?? '').toString().compareTo(
                    (b.data()['venueName'] ?? '').toString(),
                  ),
                );

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 54,
                      color: Colors.white30,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Henüz yönettiğin doğrulanmış bir mekan yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Mekanlar bölümünden işletmeni bul. Mekan profiline girip “Bu işletmeyi yönetiyor musunuz?” seçeneğiyle sahiplik doğrulaması yap.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('Mekanlara dön'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final venueName = (data['venueName'] ?? data['name'] ?? 'Mekan')
                  .toString();
              final category = (data['category'] ?? '').toString();
              final venueId = (data['venueId'] ?? '').toString();
              final logoUrl = (data['logoUrl'] ?? '').toString().trim();

              void openManager() {
                if (venueId.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessHubScreen(
                      initialCategory: category,
                      initialVenueId: venueId,
                      initialVenueName: venueName,
                    ),
                  ),
                );
              }

              void openEditor() {
                if (venueId.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessProfileEditorScreen(
                      category: category,
                      venueId: venueId,
                      venueName: venueName,
                    ),
                  ),
                );
              }

              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.surfaceStrong,
                        backgroundImage: logoUrl.isEmpty
                            ? null
                            : NetworkImage(logoUrl),
                        child: logoUrl.isEmpty
                            ? const Icon(
                                Icons.storefront_outlined,
                                color: AppColors.cyan,
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              venueName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            size: 17,
                            color: AppColors.cyan,
                          ),
                        ],
                      ),
                      subtitle: Text(_categoryLabel(category)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: openManager,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: venueId.isEmpty ? null : openEditor,
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Profili Düzenle'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: venueId.isEmpty ? null : openManager,
                              icon: const Icon(
                                Icons.dashboard_customize_outlined,
                                size: 17,
                              ),
                              label: const Text('Yönetim'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
