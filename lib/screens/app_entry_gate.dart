import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_security_gate.dart';
import 'app_onboarding_screen.dart';
import 'guest_home_screen.dart';
import 'home_shell_v3.dart';
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
        if (user == null) return const GuestHomeScreen();

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
            Widget next;
            if (!appOnboardingCompleted) {
              next = const AppOnboardingScreen();
            } else {
              final onboardingRequired = data?['onboardingRequired'] == true;
              final onboardingCompleted = data?['onboardingCompleted'] == true;
              if (onboardingRequired && !onboardingCompleted) {
                next = const StudentOnboardingScreen();
              } else {
                next = const HomeScreen();
              }
            }

            return AccountSecurityGate(
              profile: data,
              child: _AdminEntry(child: next),
            );
          },
        );
      },
    );
  }
}

class _AdminEntry extends StatefulWidget {
  final Widget child;
  const _AdminEntry({required this.child});

  @override
  State<_AdminEntry> createState() => _AdminEntryState();
}

class _AdminEntryState extends State<_AdminEntry> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _refreshAdmin();
  }

  Future<void> _refreshAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final result = await user.getIdTokenResult(true);
      if (mounted) {
        setState(() => _isAdmin = result.claims?['admin'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 14,
          bottom: 92,
          child: SafeArea(
            minimum: EdgeInsets.zero,
            child: Material(
              color: const Color(0xFF141821),
              elevation: 10,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.of(context).pushNamed('/admin'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF39DDE8).withValues(alpha: .65)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 18,
                        color: Color(0xFF39DDE8),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'TBT Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
