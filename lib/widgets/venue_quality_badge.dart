import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/venue_quality_service.dart';

class VenueQualityBadge extends StatelessWidget {
  final String venueKey;
  const VenueQualityBadge({super.key, required this.venueKey});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('venue_quality_public').doc(venueKey).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const SizedBox.shrink();
      final data = snapshot.data?.data();
      final award = (data?['award'] as num? ?? 0).toInt();
      if (award < 1 || award > 3 || data?['suspended'] == true) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF172B43), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBA066))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.workspace_premium, size: 17, color: Color(0xFFFFC857)),
          const SizedBox(width: 6),
          Text(VenueQualityService.labels[award], style: const TextStyle(color: Color(0xFFFFE6AF), fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ));
    },
  );
}
