import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<bool> requireStorySignIn(BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  if (!context.mounted) return false;
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
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          const Icon(Icons.lock_outline_rounded, size: 42),
          const SizedBox(height: 14),
          const Text(
            'Story paylaşmak için giriş yap',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Story eklemek ve paylaşmak için önce hesabına giriş yapmalısın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Giriş Yap'),
            ),
          ),
        ],
      ),
    ),
  );
  return false;
}
