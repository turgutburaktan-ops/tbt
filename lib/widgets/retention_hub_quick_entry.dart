import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_access.dart';

class RetentionHubQuickEntry extends StatefulWidget {
  final Widget child;
  const RetentionHubQuickEntry({super.key, required this.child});

  @override
  State<RetentionHubQuickEntry> createState() => _RetentionHubQuickEntryState();
}

class _RetentionHubQuickEntryState extends State<RetentionHubQuickEntry> {
  StreamSubscription<User?>? _sub;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _sub = FirebaseAuth.instance.idTokenChanges().listen((_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted && _isAdmin) setState(() => _isAdmin = false);
      return;
    }
    final ownerAccount = AdminAccess.emailMatches(user);
    if (ownerAccount && mounted && !_isAdmin) {
      setState(() => _isAdmin = true);
    }
    try {
      final token = await user
          .getIdTokenResult()
          .timeout(const Duration(seconds: 6));
      // Keep the recovery entry visible for the named owner. The destination
      // and every backend operation still enforce the verified admin claim.
      final next = ownerAccount || AdminAccess.tokenMatches(user, token);
      if (mounted && next != _isAdmin) setState(() => _isAdmin = next);
    } catch (_) {
      if (mounted && !ownerAccount && _isAdmin) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isAdmin)
          Positioned(
            left: 12,
            top: 8,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).pushNamed('/admin'),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60D1118),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x6645E7F2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 15,
                          color: Color(0xFF45E7F2),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
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
