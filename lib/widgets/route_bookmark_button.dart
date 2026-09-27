import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/travel_plan_service.dart';

class RouteBookmarkButton extends StatefulWidget {
  const RouteBookmarkButton({super.key, required this.routeId});
  final String routeId;
  @override
  State<RouteBookmarkButton> createState() => _RouteBookmarkButtonState();
}

class _RouteBookmarkButtonState extends State<RouteBookmarkButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_routes')
          .doc(widget.routeId)
          .snapshots(),
      builder: (_, s) {
        final saved = s.data?.exists == true;
        return TextButton.icon(
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          label: Text(saved ? 'Kaydedildi' : 'Kaydet'),
          onPressed: _busy || !s.hasData || s.hasError
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await TravelPlanService.instance.bookmark(
                      widget.routeId,
                      !saved,
                    );
                  } catch (_) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Kaydetme işlemi tamamlanamadı. Tekrar dene.',
                          ),
                        ),
                      );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        );
      },
    );
  }
}
