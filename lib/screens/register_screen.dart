import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/username_service.dart';
import '../services/full_name_validator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  String _profileType = 'personal';

  static const _profileTypes =
      <({String value, String title, String subtitle, IconData icon})>[
        (
          value: 'personal',
          title: 'Kişisel',
          subtitle:
              'Gez, paylaş, arkadaşlarını takip et ve etkinliklere katıl.',
          icon: Icons.person_outline_rounded,
        ),
        (
          value: 'creator',
          title: 'İçerik Üreticisi',
          subtitle: 'İçeriklerini büyüt, takipçi kitleni ve iş birliklerini geliştir.',
          icon: Icons.auto_awesome_outlined,
        ),
        (
          value: 'business',
          title: 'İşletme Sahibi',
          subtitle: 'Kişisel hesabınla işletme ve marka profillerini yönet.',
          icon: Icons.business_center_outlined,
        ),
        (
          value: 'venue_manager',
          title: 'Mekan Yöneticisi',
          subtitle: 'Kafe, Lezzet veya otel profilini doğrula ve yönet.',
          icon: Icons.storefront_outlined,
        ),
        (
          value: 'organizer',
          title: 'Organizatör',
          subtitle: 'Etkinlik oluştur, topluluk kur ve katılımcılara ulaş.',
          icon: Icons.event_available_outlined,
        ),
      ];

  bool get _hasLength => _passwordController.text.length >= 10;
  bool get _hasUpper =>
      RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(_passwordController.text);
  bool get _hasLower =>
      RegExp(r'[a-zçğıöşü]').hasMatch(_passwordController.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _hasSymbol =>
      RegExp(r'[^A-Za-z0-9çÇğĞıİöÖşŞüÜ]').hasMatch(_passwordController.text);
  bool get _passwordStrong =>
      _hasLength && _hasUpper && _hasLower && _hasDigit && _hasSymbol;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final nameParts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordAgain = _passwordAgainController.text;

    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordAgain.isEmpty) {
      _showMessage('Tüm alanları doldur.');
      return;
    }
    if (!validFullName(fullName)) {
      _showMessage('Ad ve soyadını eksiksiz gir.');
      return;
    }
    final usernameError = UsernameService.instance.validate(username);
    if (usernameError != null) {
      _showMessage(usernameError);
      return;
    }
    if (!_passwordStrong) {
      _showMessage('Şifre güvenlik koşullarının tamamını karşılamalı.');
      return;
    }
    if (password != passwordAgain) {
      _showMessage('Şifreler eşleşmiyor.');
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
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'displayName': fullName,
          'fullName': fullName,
          'firstName': nameParts.first,
          'lastName': nameParts.skip(1).join(' '),
          'email': email,
          'profileType': _profileType,
          'onboardingRequired': true,
          'onboardingCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await UsernameService.instance.reserveForCurrentUser(username);
      }

      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (accountCreated) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .delete();
          } catch (_) {}
          try {
            await user.delete();
          } catch (_) {}
        }
      }
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB7BCC2);
    final passwordMatch =
        _passwordAgainController.text.isEmpty ||
        _passwordController.text == _passwordAgainController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: const Text('Hesap Oluştur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 60,
                color: accent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Topluluğa Katıl',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Hesabını oluştur, TBT’de nasıl yer almak istediğini seç.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 26),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profil türün',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bu seçim yalnızca profil deneyimini kişiselleştirir; doğrulanmış rozet veya özel yetki vermez.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._profileTypes.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: _loading
                        ? null
                        : () => setState(() => _profileType = type.value),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121416),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _profileType == type.value
                              ? accent
                              : Colors.white10,
                          width: _profileType == type.value ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              type.icon,
                              color: _profileType == type.value
                                  ? accent
                                  : Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type.subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _profileType == type.value
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: _profileType == type.value
                                ? accent
                                : Colors.white24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _fullNameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: 80,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Ad Soyad',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Kullanıcı adı (@kullanici)',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.newUsername,
                  AutofillHints.email,
                ],
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'E-posta',
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Şifre',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    tooltip: _hidePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(
                      _hidePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121416),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Şifre gücü',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          _passwordStrong ? 'Güçlü' : 'Geliştir',
                          style: TextStyle(
                            color: _passwordStrong
                                ? const Color(0xFF69E6A6)
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Requirement(ok: _hasLength, text: 'En az 10 karakter'),
                    _Requirement(ok: _hasUpper, text: 'En az 1 büyük harf'),
                    _Requirement(ok: _hasLower, text: 'En az 1 küçük harf'),
                    _Requirement(ok: _hasDigit, text: 'En az 1 rakam'),
                    _Requirement(ok: _hasSymbol, text: 'En az 1 özel karakter'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordAgainController,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(
                  label: 'Şifre tekrar',
                  icon: passwordMatch
                      ? Icons.lock_reset_outlined
                      : Icons.error_outline_rounded,
                  errorText: passwordMatch ? null : 'Şifreler eşleşmiyor',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Hesap Oluştur',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Devam ederek topluluk kurallarını ve hesap güvenliği koşullarını kabul etmiş olursun.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? errorText,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFB7BCC2)),
    suffixIcon: suffix,
    errorText: errorText,
    filled: true,
    fillColor: const Color(0xFF121416),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFB7BCC2)),
    ),
  );
}

class _Requirement extends StatelessWidget {
  final bool ok;
  final String text;
  const _Requirement({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          ok
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: ok ? const Color(0xFF69E6A6) : Colors.white30,
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: ok ? Colors.white70 : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
