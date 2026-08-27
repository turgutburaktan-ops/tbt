import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Account security gate without device biometrics.
/// E-mail and SMS verification remain in place; once verified the app opens
/// directly without fingerprint/Face ID prompts.
class AccountSecurityGateV2 extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic>? profile;

  const AccountSecurityGateV2({
    super.key,
    required this.child,
    required this.profile,
  });

  @override
  State<AccountSecurityGateV2> createState() =>
      _AccountSecurityGateV2State();
}

class _AccountSecurityGateV2State extends State<AccountSecurityGateV2> {
  bool _phoneDeferredForSession = false;

  Future<void> _deferPhoneVerification() async {
    if (mounted) setState(() => _phoneDeferredForSession = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneVerificationDeferred': true,
        'phoneVerificationDeferredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // The session-level state still lets the user continue. They can verify
      // later from Settings > Verification even if persistence is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const _EmailVerificationScreen();
    }
    final phoneDeferred =
        _phoneDeferredForSession ||
        widget.profile?['phoneVerificationDeferred'] == true;
    if (widget.profile?['phoneVerified'] != true && !phoneDeferred) {
      return _PhoneVerificationScreen(onSkip: _deferPhoneVerification);
    }
    return widget.child;
  }
}

class _EmailVerificationScreen extends StatefulWidget {
  const _EmailVerificationScreen();
  @override
  State<_EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<_EmailVerificationScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _sendAgain() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await user.sendEmailVerification();
      if (mounted)
        setState(() => _message = 'Doğrulama e-postası yeniden gönderildi.');
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() => _message = e.message ?? 'E-posta gönderilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshed!.uid)
            .set({
              'emailVerified': true,
              'emailVerifiedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        if (mounted)
          setState(
            () => _message =
                'E-posta doğrulandı. Telefon doğrulamasına geçiliyor.',
          );
      } else if (mounted) {
        setState(
          () => _message = 'E-posta henüz doğrulanmamış. Gelen kutunu ve spam klasörünü kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('E-posta doğrulama'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(),
            child: const Text('Çıkış'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 68,
              color: AppColors.violetBright,
            ),
            const SizedBox(height: 18),
            const Text(
              'Önce e-postanı doğrula',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '$email adresine gönderilen bağlantıya dokun. E-posta doğrulanmadan hesap erişimi açılmaz.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _check,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Doğruladım, kontrol et'),
            ),
            TextButton(
              onPressed: _busy ? null : _sendAgain,
              child: const Text('Doğrulama e-postasını yeniden gönder'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneVerificationScreen extends StatefulWidget {
  final Future<void> Function() onSkip;

  const _PhoneVerificationScreen({required this.onSkip});
  @override
  State<_PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<_PhoneVerificationScreen> {
  final _phone = TextEditingController(text: '+90');
  final _code = TextEditingController();
  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.replaceAll(' ', '').trim();
    if (!phone.startsWith('+') || phone.length < 10) {
      setState(
        () => _error = 'Telefon numarasını ülke koduyla gir. Örn: +905...',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) =>
          _finishVerification(credential, phone),
      verificationFailed: (e) {
        if (mounted)
          setState(() {
            _busy = false;
            _error =
                '${e.message ?? 'SMS gönderilemedi.'} (Firebase kodu: ${e.code})';
          });
      },
      codeSent: (id, _) {
        if (mounted)
          setState(() {
            _verificationId = id;
            _busy = false;
          });
      },
      codeAutoRetrievalTimeout: (id) {
        if (mounted)
          setState(() {
            _verificationId = id;
            _busy = false;
          });
      },
    );
  }

  Future<void> _confirmCode() async {
    final id = _verificationId;
    if (id == null || _code.text.trim().length < 4) return;
    await _finishVerification(
      PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: _code.text.trim(),
      ),
      _phone.text.replaceAll(' ', '').trim(),
    );
  }

  Future<void> _finishVerification(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final linked = user.providerData.any(
        (p) => p.providerId == PhoneAuthProvider.PROVIDER_ID,
      );
      if (linked) {
        await user.reauthenticateWithCredential(credential);
      } else {
        await user.linkWithCredential(credential);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': phone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'phoneVerificationDeferred': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => _busy = false);
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = e.code == 'credential-already-in-use'
              ? 'Bu telefon numarası başka bir hesapta kullanılıyor.'
              : '${e.message ?? 'Telefon doğrulanamadı.'} (Firebase kodu: ${e.code})';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hesap güvenliği'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(),
            child: const Text('Çıkış'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 68,
              color: AppColors.violetBright,
            ),
            const SizedBox(height: 18),
            const Text(
              'Telefonunu doğrula',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hesap güvenliği ve kötüye kullanım önleme için telefon numaranı SMS koduyla doğrula. Doğrulamadan sonra TBT doğrudan açılır; parmak izi veya yüz tanıma istenmez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _phone,
              enabled: !codeSent && !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon numarası',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SMS doğrulama kodu',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : (codeSent ? _confirmCode : _sendCode),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      codeSent ? Icons.verified_outlined : Icons.sms_outlined,
                    ),
              label: Text(codeSent ? 'Kodu doğrula' : 'Kod gönder'),
            ),
            TextButton(
              onPressed: _busy ? null : widget.onSkip,
              child: const Text('Şimdi Değil / Atla'),
            ),
          ],
        ),
      ),
    );
  }
}
