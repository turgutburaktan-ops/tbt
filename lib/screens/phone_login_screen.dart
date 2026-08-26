import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController(text: '+90');
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.replaceAll(' ', '').trim();
    if (!phone.startsWith('+') || phone.length < 10) {
      _message('Telefon numarasını ülke koduyla yaz. Örn. +905xxxxxxxxx');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.verifyPhoneNumber(
        phoneNumber: phone,
        codeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _loading = false;
          });
          _message('Doğrulama kodu gönderildi.');
        },
        failed: (message) {
          if (!mounted) return;
          setState(() => _loading = false);
          _message(message);
        },
        autoVerified: (_) {
          if (!mounted) return;
          Navigator.pop(context);
        },
      );
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && _verificationId == null) setState(() => _loading = false);
    }
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (verificationId == null || code.length != 6) {
      _message('6 haneli doğrulama kodunu gir.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: code,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final waitingForCode = _verificationId != null;
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: const Text('Telefon ile giriş'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 64,
                color: Color(0xFFB7BCC2),
              ),
              const SizedBox(height: 18),
              Text(
                waitingForCode
                    ? 'Kodunu doğrula'
                    : 'Telefon numaranla devam et',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                waitingForCode ? 'SMS ile gelen 6 haneli kodu gir.' : 'Numaran yalnızca giriş ve hesap güvenliği için kullanılır.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 30),
              if (!waitingForCode)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    'Telefon numarası',
                    Icons.phone_outlined,
                  ),
                )
              else
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: _decoration(
                    'Doğrulama kodu',
                    Icons.verified_user_outlined,
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB7BCC2),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _loading
                      ? null
                      : waitingForCode
                      ? _confirmCode
                      : _sendCode,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          waitingForCode
                              ? 'Doğrula ve Giriş Yap'
                              : 'Kod Gönder',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              if (waitingForCode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _verificationId = null;
                          _codeController.clear();
                        }),
                  child: const Text('Telefon numarasını değiştir'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFB7BCC2)),
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
