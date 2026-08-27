import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phone = TextEditingController(text: '+90');
  final _code = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _resetSession({bool keepPhone = true}) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _seconds = 0;
      _verificationId = null;
      _resendToken = null;
      _sending = false;
      _verifying = false;
      _code.clear();
      if (!keepPhone) _phone.text = '+90';
    });
  }

  String _authError(FirebaseAuthException error, {bool sending = false}) {
    return switch (error.code) {
      'invalid-phone-number' => 'Telefon numarası geçersiz.',
      'too-many-requests' =>
        'Çok fazla deneme yapıldı. Bir süre sonra tekrar dene.',
      'quota-exceeded' => 'SMS kotası geçici olarak dolu.',
      'app-not-authorized' ||
      'captcha-check-failed' ||
      'missing-client-identifier' ||
      'invalid-app-credential' => 'Uygulama güvenlik sertifikası doğrulanamadı. TBT’yi güncelleyip tekrar dene.',
      _ =>
        error.message ??
            (sending ? 'SMS gönderilemedi.' : 'Telefon doğrulanamadı.'),
    };
  }

  String _normalize(String raw) {
    var value = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (value.startsWith('0')) value = '+90${value.substring(1)}';
    if (!value.startsWith('+')) value = '+$value';
    return value;
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_sending) return;
    final phone = _normalize(_phone.text.trim());
    if (phone.length < 10) {
      _message('Geçerli bir telefon numarası gir.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance
          .verifyPhoneNumber(
            phoneNumber: phone,
            forceResendingToken: resend ? _resendToken : null,
            verificationCompleted: (credential) async =>
                _applyCredential(credential),
            verificationFailed: (error) {
              _message(_authError(error, sending: true));
              if (mounted) setState(() => _sending = false);
            },
            codeSent: (verificationId, resendToken) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _resendToken = resendToken;
                _sending = false;
              });
              _startTimer();
              _message('Doğrulama kodu SMS ile gönderildi.');
            },
            codeAutoRetrievalTimeout: (verificationId) {
              if (mounted) setState(() => _verificationId = verificationId);
            },
            timeout: const Duration(seconds: 60),
          )
          .timeout(const Duration(seconds: 75));
    } on TimeoutException {
      _resetSession();
      _message('Doğrulama isteği zaman aşımına uğradı. Tekrar dene.');
    } on FirebaseAuthException catch (error) {
      _message(_authError(error, sending: true));
      if (mounted) setState(() => _sending = false);
    } catch (_) {
      _message(
        'SMS gönderilemedi. İnternet bağlantını kontrol edip tekrar dene.',
      );
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_verifying) return;
    final verificationId = _verificationId;
    final code = _code.text.trim();
    if (verificationId == null) {
      _message('Önce SMS kodu gönder.');
      return;
    }
    if (code.length != 6) {
      _message('6 haneli SMS kodunu gir.');
      return;
    }
    setState(() => _verifying = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _applyCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'session-expired') {
        _resetSession();
        _message(
          'Kodun süresi doldu. Oturumu yeniledik; yeni bir SMS kodu iste.',
        );
        return;
      }
      _message(
        error.code == 'invalid-verification-code'
            ? 'SMS kodu yanlış.'
            : _authError(error),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Telefon doğrulamak için tekrar giriş yap.');
      return;
    }
    try {
      if ((user.phoneNumber ?? '').isEmpty) {
        await user.linkWithCredential(credential);
      } else {
        await user.updatePhoneNumber(credential);
      }
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': refreshed?.phoneNumber ?? user.phoneNumber,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'phoneVerificationDeferred': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'session-expired') {
        _resetSession();
        _message(
          'Doğrulama oturumu sona erdi. Oturumu yeniledik; yeni kod iste.',
        );
        return;
      }
      _message(switch (error.code) {
        'credential-already-in-use' =>
          'Bu telefon başka bir TBT hesabına bağlı.',
        'provider-already-linked' => 'Bu hesaba zaten bir telefon bağlı.',
        'requires-recent-login' =>
          'Güvenlik için tekrar giriş yapıp yeniden dene.',
        _ => _authError(error),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _verificationId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Telefonu Doğrula')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const Icon(
                    Icons.phone_android_rounded,
                    size: 54,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Telefon doğrulama',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Telefon numaranı gir. Sana SMS ile 6 haneli bir doğrulama kodu göndereceğiz.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phone,
                    enabled: !sent,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Telefon numarası',
                      hintText: '+90 5xx xxx xx xx',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!sent)
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendCode,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sms_outlined),
                      label: Text(
                        _sending ? 'Gönderiliyor…' : 'SMS Kodu Gönder',
                      ),
                    ),
                  if (sent) ...[
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'SMS doğrulama kodu',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _verifying ? null : _verifyCode,
                      icon: _verifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        _verifying ? 'Doğrulanıyor…' : 'Telefonu Doğrula',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _seconds > 0 || _sending
                          ? null
                          : () => _sendCode(resend: true),
                      child: Text(
                        _seconds > 0
                            ? 'Yeni kod için $_seconds sn'
                            : 'Kodu tekrar gönder',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _resetSession(keepPhone: false),
                      child: const Text('Telefon numarasını değiştir'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'SMS ücretleri operatörüne göre değişebilir. Doğrulama tamamlandığında telefon numarası TBT hesabına bağlanır.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: (_sending || _verifying)
                      ? null
                      : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Şimdi Değil'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
