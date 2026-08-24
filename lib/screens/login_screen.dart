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
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _busy => _loading || _googleLoading || _appleLoading;

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
      if (!widget.embedded) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_busy) return;
    setState(() => _googleLoading = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (!mounted || credential == null) return;
      if (!widget.embedded) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _appleLogin() async {
    if (_busy) return;
    setState(() => _appleLoading = true);
    try {
      await AuthService.instance.signInWithApple();
      if (!mounted) return;
      if (!widget.embedded) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şifreni sıfırla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hesabına bağlı e-posta adresini yaz. Sıfırlama bağlantısı göndereceğiz.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Bağlantı Gönder'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || !mounted) return;
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) _showMessage('Şifre sıfırlama bağlantısı gönderildi.');
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
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

    final body = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          children: [
            SizedBox(height: widget.embedded ? 34 : 14),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 36, color: accent),
            ),
            const SizedBox(height: 18),
            const Text(
              'TBT’ye hoş geldin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'Keşfet, paylaş ve topluluğa katıl.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _googleLogin,
                icon: _googleLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                label: const Text('Google ile devam et', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _appleLogin,
                icon: _appleLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.apple_rounded, size: 24),
                label: const Text('Apple ile devam et', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(children: [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('veya e-posta', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ]),
            ),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(label: 'E-posta', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _busy ? null : _login(),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(
                label: 'Şifre',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                  icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: const Text('Şifremi unuttum'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                onPressed: _busy ? null : _login,
                child: _loading
                    ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                    : const Text('E-posta ile Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Hesabın yok mu?', style: TextStyle(color: Colors.white54)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Kayıt Ol', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return ColoredBox(color: const Color(0xFF090A0C), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
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
  }) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFB7BCC2)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF121416),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFB7BCC2))),
      );
}
