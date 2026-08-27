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
      if (mounted && _isAdmin) setState(() => _isAdmin = false);
      return;
    }
    try {
      // Never force-refresh a token from inside idTokenChanges. A forced token
      // refresh can itself emit idTokenChanges and create a needless loop.
      final token = await user
          .getIdTokenResult()
          .timeout(const Duration(seconds: 6));
      final next = token.claims?['admin'] == true;
      if (mounted && next != _isAdmin) setState(() => _isAdmin = next);
    } catch (_) {
      if (mounted && _isAdmin) setState(() => _isAdmin = false);
    }
  }

  Stream<_RewardSummary> _rewardStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? const <String, dynamic>{};
          return _RewardSummary(
            xp: (data['xp'] as num?)?.toInt() ?? 0,
            level: (data['levelTitle'] ?? 'Gezgin').toString(),
          );
        })
        .distinct();
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
              child: StreamBuilder<_RewardSummary>(
                stream: _rewardStream(uid),
                builder: (context, snapshot) {
                  final reward = snapshot.data ?? const _RewardSummary();
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(context).pushNamed('/rewards'),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60D1118),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Color(0xFFFFD166),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${reward.xp} XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 88),
                              child: Text(
                                reward.level,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60D1118),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x8845E7F2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: Color(0xFF45E7F2),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Admin Paneli',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: -.1,
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

class _RewardSummary {
  final int xp;
  final String level;

  const _RewardSummary({this.xp = 0, this.level = 'Gezgin'});

  @override
  bool operator ==(Object other) =>
      other is _RewardSummary && other.xp == xp && other.level == level;

  @override
  int get hashCode => Object.hash(xp, level);
}
