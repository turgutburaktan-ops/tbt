import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../l10n/app_strings.dart';
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

  bool get _busy => _loading;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage(AppStrings.of(context).text('fillLogin'));
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

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.of(context).text('resetPassword')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.of(context).text('resetBody'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).text('email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.of(context).text('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(AppStrings.of(context).text('sendLink')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || !mounted) return;
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) _showMessage(AppStrings.of(context).text('resetSent'));
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
    final strings = AppStrings.of(context);

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
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 36,
                color: accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.text('welcome'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              strings.text('welcomeBody'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(
                label: strings.text('identifier'),
                icon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _busy ? null : _login(),
              style: const TextStyle(color: Colors.white),
              decoration: _decoration(
                label: strings.text('password'),
                icon: Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _hidePassword ? strings.text('showPassword') : strings.text('hidePassword'),
                  icon: Icon(
                    _hidePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: Text(strings.text('forgotPassword')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: _busy ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        strings.text('login'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  strings.text('noAccount'),
                  style: const TextStyle(color: Colors.white54),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                  child: Text(
                    strings.text('register'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.embedded)
      return ColoredBox(color: const Color(0xFF090A0C), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: Text(strings.text('login')),
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
