import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/profile_business_coupons.dart';
import '../widgets/profile_reservations.dart';

class ProfileHistoryScreen extends StatelessWidget {
  const ProfileHistoryScreen({super.key, required this.coupons});
  final bool coupons;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(coupons ? 'Geçmiş kuponlar' : 'Geçmiş rezervasyonlar'),
    ),
    body: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final uid = snapshot.data?.uid;
        if (uid == null)
          return const Center(child: Text('Geçmişini görmek için giriş yap.'));
        return SingleChildScrollView(
          child: coupons
              ? ProfileBusinessCoupons(
                  key: ValueKey(uid),
                  userId: uid,
                  history: true,
                  initiallyExpanded: true,
                )
              : ProfileReservations(
                  key: ValueKey(uid),
                  userId: uid,
                  history: true,
                  initiallyExpanded: true,
                ),
        );
      },
    ),
  );
}
