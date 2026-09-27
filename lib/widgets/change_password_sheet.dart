import '../services/password_policy.dart';
import '../theme/app_theme.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, required this.email});
  final String email;

  static Future<bool?> show(BuildContext context, String email) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (_) => ChangePasswordSheet(email: email),
      );

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_current.text.isEmpty) return _setError('Mevcut şifreni gir.');
    if (!PasswordPolicy.accepts(_next.text))
      return _setError(PasswordPolicy.message);
    if (_next.text != _confirm.text)
      return _setError('Yeni şifreler aynı değil.');
    if (_next.text == _current.text)
      return _setError('Yeni şifren mevcut şifrenden farklı olmalı.');
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Oturum bulunamadı.');
      await user
          .reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: widget.email,
              password: _current.text,
            ),
          )
          .timeout(const Duration(seconds: 20));
      await user
          .updatePassword(_next.text)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimeoutException {
      _setError(
        'İşlem zaman aşımına uğradı. Bağlantını kontrol edip tekrar dene.',
      );
    } on FirebaseAuthException catch (e) {
      _setError(switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Mevcut şifre yanlış.',
        'weak-password' || 'password-does-not-meet-requirements' => PasswordPolicy.message,
        'requires-recent-login' =>
          'Güvenlik için tekrar giriş yapıp yeniden dene.',
        'network-request-failed' => 'İnternet bağlantısı kurulamadı.',
        _ => e.message ?? 'Şifre değiştirilemedi.',
      });
    } catch (_) {
      _setError('Şifre değiştirilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      18,
      18,
      18 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Şifre Değiştir',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _current,
            obscureText: true,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Mevcut şifre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: true,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Yeni şifre',
              helperText: PasswordPolicy.hint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: true,
            enabled: !_saving,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Yeni şifre tekrar'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
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
