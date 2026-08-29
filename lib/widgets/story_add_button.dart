import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StoryAddButton extends StatelessWidget {
  final VoidCallback onSignedIn;
  final Widget child;
  const StoryAddButton({super.key, required this.onSignedIn, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (FirebaseAuth.instance.currentUser != null) {
            onSignedIn();
            return;
          }
          await showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            backgroundColor: const Color(0xFF111318),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            builder: (sheetContext) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 42),
                  const SizedBox(height: 14),
                  const Text('Giriş Yap', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Story eklemek için önce giriş yapmalısın.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Giriş Yap'))),
                ],
              ),
            ),
          );
        },
        child: child,
      );
}
