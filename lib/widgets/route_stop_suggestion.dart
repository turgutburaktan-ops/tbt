import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/spot_suggestion_screen.dart';

class RouteStopSuggestion extends StatelessWidget {
  const RouteStopSuggestion({
    super.key,
    required this.routeId,
    required this.city,
    required this.stop,
  });
  final String routeId, city;
  final Map<String, dynamic> stop;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('spot_submissions')
          .where('submittedBy', isEqualTo: uid)
          .snapshots(),
      builder: (_, snapshot) {
        if (snapshot.hasError)
          return const Text('Öneri durumu yüklenemedi. Tekrar dene.');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final matches = snapshot.data!.docs.where(
          (d) =>
              d.data()['sourceRouteId'] == routeId &&
              d.data()['sourceStopId'] == stop['id'],
        );
        final data = matches.isEmpty ? null : matches.first.data();
        final status = data?['status'];
        final label = switch (status) {
          'approved' => 'Onaylandı · Gezi’ye eklendi',
          'duplicate' => 'Bu yer zaten kayıtlı',
          'pending_review' => 'Önerin incelemede',
          'rejected' => 'Önerin reddedildi',
          _ => '',
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty) Text(label),
            if ((data?['reviewReason'] ?? '').toString().isNotEmpty)
              Text(data!['reviewReason'].toString()),
            if (data == null || status == 'rejected')
              TextButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  status == 'rejected'
                      ? 'Düzenle ve yeniden öner'
                      : 'Gezi’ye öner',
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpotSuggestionScreen(
                      sourceRouteId: routeId,
                      initialStop: {
                        ...stop,
                        'city': (stop['city'] ?? '').toString().isEmpty
                            ? city
                            : stop['city'],
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
