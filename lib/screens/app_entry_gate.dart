import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_onboarding_screen.dart';
import 'home_shell_screen.dart';
import 'student_onboarding_screen.dart';

class AppEntryGate extends StatelessWidget {
  const AppEntryGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return const HomeScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF090A0C),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = profileSnapshot.data?.data();
            final appOnboardingCompleted = data?['appOnboardingCompleted'] == true;
            if (!appOnboardingCompleted) {
              return const AppOnboardingScreen();
            }

            final onboardingRequired = data?['onboardingRequired'] == true;
            final onboardingCompleted = data?['onboardingCompleted'] == true;
            if (onboardingRequired && !onboardingCompleted) {
              return const StudentOnboardingScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}
