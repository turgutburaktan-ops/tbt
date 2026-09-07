import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/admin_access.dart';

class AdminQuickEntry extends StatefulWidget {
  final Widget child;
  const AdminQuickEntry({super.key, required this.child});

  @override
  State<AdminQuickEntry> createState() => _AdminQuickEntryState();
}

class _AdminQuickEntryState extends State<AdminQuickEntry> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    FirebaseAuth.instance.idTokenChanges().listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }
    final ownerAccount = AdminAccess.emailMatches(user);
    if (ownerAccount && mounted) setState(() => _isAdmin = true);
    try {
      final token = await user
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(
          () => _isAdmin =
              ownerAccount || AdminAccess.tokenMatches(user, token),
        );
      }
    } catch (_) {
      if (mounted && !ownerAccount) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_isAdmin)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed('/admin'),
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE11151B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: .7),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 18,
                        color: AppColors.cyan,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
