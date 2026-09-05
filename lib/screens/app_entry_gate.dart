import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/retention_hub_quick_entry.dart';
import '../widgets/retention_now_overlay.dart';
import '../widgets/daily_goals_prompt.dart';
import 'account_security_gate_v2.dart';
import 'app_onboarding_screen.dart';
import 'home_shell_v3.dart';
import 'student_onboarding_screen.dart';

class AppEntryGate extends StatelessWidget {
  const AppEntryGate({super.key});

  Stream<_EntryGateState> _gateStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => _EntryGateState.from(snapshot.data()))
        .distinct();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return const HomeScreen();

        return StreamBuilder<_EntryGateState>(
          stream: _gateStream(user.uid),
          builder: (context, gateSnapshot) {
            if (gateSnapshot.connectionState == ConnectionState.waiting &&
                !gateSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF090A0C),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final gate = gateSnapshot.data ?? const _EntryGateState();
            Widget next;
            if (!gate.appOnboardingCompleted) {
              next = const AppOnboardingScreen();
            } else if (gate.onboardingRequired && !gate.onboardingCompleted) {
              next = const StudentOnboardingScreen();
            } else {
              next = DailyGoalsPrompt(
                key: ValueKey(user.uid),
                userId: user.uid,
                child: const RetentionHubQuickEntry(
                  child: RetentionNowOverlay(child: HomeScreen()),
                ),
              );
            }

            return AccountSecurityGateV2(
              profile: gate.securityProfile,
              child: next,
            );
          },
        );
      },
    );
  }
}

class _EntryGateState {
  final bool appOnboardingCompleted;
  final bool onboardingRequired;
  final bool onboardingCompleted;
  final bool phoneVerified;
  final bool phoneVerificationDeferred;

  const _EntryGateState({
    this.appOnboardingCompleted = false,
    this.onboardingRequired = false,
    this.onboardingCompleted = false,
    this.phoneVerified = false,
    this.phoneVerificationDeferred = false,
  });

  factory _EntryGateState.from(Map<String, dynamic>? data) {
    return _EntryGateState(
      appOnboardingCompleted: data?['appOnboardingCompleted'] == true,
      onboardingRequired: data?['onboardingRequired'] == true,
      onboardingCompleted: data?['onboardingCompleted'] == true,
      phoneVerified: data?['phoneVerified'] == true,
      phoneVerificationDeferred: data?['phoneVerificationDeferred'] == true,
    );
  }

  Map<String, dynamic> get securityProfile => <String, dynamic>{
    'phoneVerified': phoneVerified,
    'phoneVerificationDeferred': phoneVerificationDeferred,
  };

  @override
  bool operator ==(Object other) {
    return other is _EntryGateState &&
        other.appOnboardingCompleted == appOnboardingCompleted &&
        other.onboardingRequired == onboardingRequired &&
        other.onboardingCompleted == onboardingCompleted &&
        other.phoneVerified == phoneVerified &&
        other.phoneVerificationDeferred == phoneVerificationDeferred;
  }

  @override
  int get hashCode => Object.hash(
    appOnboardingCompleted,
    onboardingRequired,
    onboardingCompleted,
    phoneVerified,
    phoneVerificationDeferred,
  );
}
