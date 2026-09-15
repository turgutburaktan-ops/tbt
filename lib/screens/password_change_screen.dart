import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PasswordChangeScreen extends StatefulWidget {
  final String email;

  const PasswordChangeScreen({super.key, required this.email});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final currentPassword = _current.text;
    final nextPassword = _next.text;
    if (currentPassword.isEmpty) {
      _message('Mevcut şifreni gir.');
      return;
    }
    if (nextPassword.length < 6) {
      _message('Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (nextPassword != _confirm.text) {
      _message('Yeni şifreler aynı değil.');
      return;
    }
    if (nextPassword == currentPassword) {
      _message('Yeni şifren mevcut şifrenden farklı olmalı.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    var success = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _message('Oturumun sona erdi. Tekrar giriş yapıp yeniden dene.');
        return;
      }
      await user
          .reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: widget.email,
              password: currentPassword,
            ),
          )
          .timeout(const Duration(seconds: 20));
      await user
          .updatePassword(nextPassword)
          .timeout(const Duration(seconds: 20));
      success = true;
    } on TimeoutException {
      _message(
        'İşlem zaman aşımına uğradı. Bağlantını kontrol edip tekrar dene.',
      );
    } on FirebaseAuthException catch (e) {
      _message(switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Mevcut şifre yanlış.',
        'weak-password' => 'Yeni şifre çok zayıf.',
        'requires-recent-login' =>
          'Güvenlik için tekrar giriş yapıp yeniden dene.',
        'network-request-failed' =>
          'İnternet bağlantısı kurulamadı. Tekrar dene.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Bir süre sonra tekrar dene.',
        _ => e.message ?? 'Şifre değiştirilemedi.',
      });
    } catch (_) {
      _message('Şifre değiştirilemedi. Tekrar dene.');
    } finally {
      if (mounted && !success) setState(() => _saving = false);
    }

    if (!mounted || !success) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Şifre Değiştir')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          children: [
            const Icon(
              Icons.lock_reset_rounded,
              size: 48,
              color: AppColors.cyan,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hesabını güvende tut',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mevcut şifreni doğruladıktan sonra yeni şifren hemen etkinleşir.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _current,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Mevcut şifre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Yeni şifre',
                helperText: 'En az 6 karakter',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Yeni şifre tekrar'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Değiştiriliyor…' : 'Şifreyi Değiştir'),
            ),
          ],
        ),
      ),
    );
  }
}
