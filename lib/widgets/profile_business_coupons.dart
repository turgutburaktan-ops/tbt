import 'dart:async';

import '../services/profile_record_status.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Personal coupon tokens are only read on the signed-in user's own profile.
class ProfileBusinessCoupons extends StatefulWidget {
  final String userId;
  final bool history, initiallyExpanded;
  const ProfileBusinessCoupons({
    super.key,
    required this.userId,
    this.history = false,
    this.initiallyExpanded = false,
  });
  @override
  State<ProfileBusinessCoupons> createState() => _ProfileBusinessCouponsState();
}

class _ProfileBusinessCouponsState extends State<ProfileBusinessCoupons> {
  Timer? _timer;
  String get userId => widget.userId;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser?.uid != userId) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.confirmation_number_outlined),
        initiallyExpanded: widget.initiallyExpanded,
        title: Text(widget.history ? 'Geçmiş kuponlar' : 'Aktif kuponlar'),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('business_coupons')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Kuponlar yüklenemedi. Bağlantını kontrol edip yeniden aç.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final docs =
                  snapshot.data!.docs
                      .where(
                        (doc) =>
                            isActiveCoupon(doc.data(), DateTime.now()) !=
                            widget.history,
                      )
                      .toList()
                    ..sort((a, b) {
                      final at = a.data()['createdAt'] as Timestamp?;
                      final bt = b.data()['createdAt'] as Timestamp?;
                      return (bt?.millisecondsSinceEpoch ?? 0).compareTo(
                        at?.millisecondsSinceEpoch ?? 0,
                      );
                    });
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.history ? 'Geçmiş kuponun yok.' : 'Aktif kuponun yok. İşletme profilinden kupon alabilirsin.',
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final until = (data['validUntil'] as Timestamp?)?.toDate();
                  final token = (data['token'] ?? '').toString();
                  final used = data['status'] == 'used';
                  final ready =
                      data['status'] == 'ready' &&
                      token.isNotEmpty &&
                      until != null &&
                      until.isAfter(DateTime.now());
                  final status = used
                      ? 'Kullanıldı'
                      : ready
                      ? 'Kullanıma hazır'
                      : 'Geçersiz / süresi doldu';
                  return ExpansionTile(
                    title: Text((data['title'] ?? 'Kupon').toString()),
                    subtitle: Text(
                      '$status${until == null ? '' : ' · ${until.day}.${until.month}.${until.year}'}',
                    ),
                    children: [
                      if (ready) ...[
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(data: token, size: 180),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(token),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'İşletmede QR kodunu veya kupon kodunu göster.',
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(status),
                        ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
