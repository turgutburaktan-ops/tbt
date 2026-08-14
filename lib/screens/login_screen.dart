import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool embedded;

  const LoginScreen({super.key, this.embedded = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('E-posta ve şifre alanlarını doldur.');
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.instance.login(email: email, password: password);
      if (!mounted) return;

      // Profil sekmesine gömülü kullanıldığında auth stream ekranı doğrudan
      // profil içeriğine çevirir. Ayrı route olarak açıldığında eski davranış
      // korunur ve giriş ekranı kapanır.
      if (!widget.embedded) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Önce e-posta adresini yaz.');
      return;
    }

    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showMessage('Şifre sıfırlama bağlantısı gönderildi.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFC107);

    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: widget.embedded ? 42 : 20),
            const Icon(Icons.camera_alt_rounded, size: 72, color: yellow),
            const SizedBox(height: 20),
            const Text(
              'En İyi Çekim Noktası',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fotoğraf topluluğuna giriş yap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 38),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(label: 'E-posta', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _hidePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(
                label: 'Şifre',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('Şifremi unuttum'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: yellow, foregroundColor: Colors.black),
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
                      )
                    : const Text(
                        'Giriş Yap',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Hesabın yok mu?', style: TextStyle(color: Colors.white54)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Kayıt Ol', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF0D1117), child: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: const Text('Giriş Yap'),
      ),
      body: body,
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFFC107)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF171C24),
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
        borderSide: const BorderSide(color: Color(0xFFFFC107)),
      ),
    );
  }
}
