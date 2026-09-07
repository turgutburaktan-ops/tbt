import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/trust_safety_service.dart';

class FrozenAccountScreen extends StatefulWidget {
  const FrozenAccountScreen({super.key});

  @override
  State<FrozenAccountScreen> createState() => _FrozenAccountScreenState();
}

class _FrozenAccountScreenState extends State<FrozenAccountScreen> {
  bool _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await TrustSafetyService.instance.unfreezeAccount();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF090A0C),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ac_unit_rounded, size: 58, color: Colors.white70),
              const SizedBox(height: 18),
              const Text(
                'Hesabın donduruldu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hesabın süre sınırı olmadan dondurulmuş durumda. İstediğin zaman yeniden etkinleştirebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(_busy ? 'Açılıyor…' : 'Hesabımı yeniden aç'),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(),
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
