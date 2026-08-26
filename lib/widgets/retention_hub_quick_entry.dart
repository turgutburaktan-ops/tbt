import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      if (mounted) setState(() => _isAdmin = false);
      return;
    }
    try {
      final token = await user.getIdTokenResult(true);
      if (mounted) setState(() => _isAdmin = token.claims?['admin'] == true);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Stack(
      children: [
        widget.child,
        if (uid != null)
          Positioned(
            right: 12,
            bottom: 122,
            child: SafeArea(
              top: false,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() ?? const <String, dynamic>{};
                  final xp = (data['xp'] as num?)?.toInt() ?? 0;
                  final level = (data['levelTitle'] ?? 'Gezgin').toString();
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(context).pushNamed('/rewards'),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE60D1118),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFFD166)),
                            const SizedBox(width: 5),
                            Text('$xp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 88),
                              child: Text(level, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (_isAdmin)
          Positioned(
            left: 12,
            bottom: 122,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).pushNamed('/admin'),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xE60D1118),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x8845E7F2)),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF45E7F2)),
                        SizedBox(width: 6),
                        Text('Admin Paneli', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: -.1)),
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
