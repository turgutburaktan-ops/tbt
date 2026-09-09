import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/full_name_validator.dart';
import '../services/username_service.dart';
import '../theme/app_theme.dart';

class CreatorRegisterScreen extends StatefulWidget {
  final String inviteCode;

  const CreatorRegisterScreen({super.key, required this.inviteCode});

  @override
  State<CreatorRegisterScreen> createState() => _CreatorRegisterScreenState();
}

class _CreatorRegisterScreenState extends State<CreatorRegisterScreen> {
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  bool get _strongPassword {
    final value = _password.text;
    return value.length >= 10 &&
        RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(value) &&
        RegExp(r'[a-zçğıöşü]').hasMatch(value) &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9çÇğĞıİöÖşŞüÜ]').hasMatch(value);
  }

  Future<void> _register() async {
    final fullName = _fullName.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (!validFullName(fullName)) {
      _message('Ad ve soyadını eksiksiz gir.');
      return;
    }
    final usernameError = UsernameService.instance.validate(username);
    if (usernameError != null) {
      _message(usernameError);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _message('Geçerli bir e-posta adresi gir.');
      return;
    }
    if (!_strongPassword) {
      _message('Şifre en az 10 karakter; büyük/küçük harf, rakam ve özel karakter içermeli.');
      return;
    }
    if (password != _passwordAgain.text) {
      _message('Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _loading = true);
    var accountCreated = false;
    try {
      final available = await UsernameService.instance.isAvailable(username);
      if (!available) throw Exception('Bu kullanıcı adı zaten alınmış.');
      await AuthService.instance.register(email: email, password: password);
      accountCreated = true;
      await AuthService.instance.updateDisplayName(fullName);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Hesap oluşturulamadı.');
      final parts = fullName.split(' ').where((e) => e.isNotEmpty).toList();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': fullName,
        'fullName': fullName,
        'firstName': parts.first,
        'lastName': parts.skip(1).join(' '),
        'email': email,
        'profileType': 'creator',
        'onboardingRequired': true,
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await UsernameService.instance.reserveForCurrentUser(username);

      final result = await _functions.httpsCallable('redeemCreatorInvite').call({
        'code': widget.inviteCode,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final tier = (data['tier'] ?? 'creator').toString();
      try {
        await user.sendEmailVerification().timeout(const Duration(seconds: 12));
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(tier);
    } catch (e) {
      // Once a valid account/profile exists, never delete it just because the
      // invitation or verification service had a temporary failure.
      if (!accountCreated) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await user.delete();
          } catch (_) {}
        }
      }
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Creator hesabını oluştur')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            MediaQuery.viewInsetsOf(context).bottom + 28,
          ),
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 54,
              color: Color(0xFFD7DBDF),
            ),
            const SizedBox(height: 10),
            const Text(
              'TBT Creator olarak katıl',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.inviteCode,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            _field(_fullName, 'Ad Soyad', Icons.badge_outlined,
                keyboardType: TextInputType.name),
            const SizedBox(height: 12),
            _field(_username, 'Kullanıcı adı', Icons.alternate_email_rounded),
            const SizedBox(height: 12),
            _field(_email, 'E-posta', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Şifre',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _strongPassword
                  ? 'Şifre güvenlik koşullarını karşılıyor.'
                  : 'En az 10 karakter; büyük/küçük harf, rakam ve özel karakter.',
              style: TextStyle(
                color: _strongPassword ? const Color(0xFFB7BCC2) : Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordAgain,
              obscureText: _hidePassword,
              decoration: const InputDecoration(
                labelText: 'Şifre tekrar',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _loading ? null : _register,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'Hesabı oluştur ve daveti kabul et',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
