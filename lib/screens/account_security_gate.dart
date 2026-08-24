import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/biometric_auth_service.dart';
import '../theme/app_theme.dart';

class AccountSecurityGate extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic>? profile;

  const AccountSecurityGate({
    super.key,
    required this.child,
    required this.profile,
  });

  @override
  State<AccountSecurityGate> createState() => _AccountSecurityGateState();
}

class _AccountSecurityGateState extends State<AccountSecurityGate> {
  bool _checking = true;
  bool _unlocked = false;
  bool _biometricAvailable = false;

  bool get _phoneVerified => widget.profile?['phoneVerified'] == true;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void didUpdateWidget(covariant AccountSecurityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?['phoneVerified'] !=
        widget.profile?['phoneVerified']) {
      _evaluate();
    }
  }

  Future<void> _evaluate() async {
    if (!_phoneVerified) {
      if (mounted) {
        setState(() {
          _checking = false;
          _unlocked = false;
        });
      }
      return;
    }
    final available = await BiometricAuthService.instance.canUseBiometrics();
    final enabled = await BiometricAuthService.instance.enabled;
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _checking = false;
      _unlocked = !available || !enabled;
    });
    if (available && enabled) {
      await _unlockWithBiometric();
    }
  }

  Future<void> _unlockWithBiometric() async {
    final ok = await BiometricAuthService.instance.authenticate();
    if (!mounted) return;
    setState(() => _unlocked = ok);
  }

  Future<void> _enableBiometric() async {
    final ok = await BiometricAuthService.instance.authenticate();
    if (!ok) return;
    await BiometricAuthService.instance.setEnabled(true);
    if (mounted) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const EmailSecuritySetupScreen();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const EmailSecuritySetupScreen();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const EmailSecuritySetupScreen();
    }

    if (!_phoneVerified) {
      return const PhoneSecuritySetupScreen();
    }

    if (!_unlocked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 72,
                    color: AppColors.violetBright,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'TBT kilitli',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hesabını açmak için parmak izi veya cihaz biyometrisini kullan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Parmak iziyle aç'),
                  ),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Başka hesapla giriş yap'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_biometricAvailable) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 6,
            child: FutureBuilder<bool>(
              future: BiometricAuthService.instance.enabled,
              builder: (context, snapshot) {
                if (snapshot.data == true) return const SizedBox.shrink();
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _enableBiometric,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint_rounded, size: 17),
                          SizedBox(width: 5),
                          Text(
                            'Biyometriyi aç',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}

class EmailSecuritySetupScreen extends StatefulWidget {
  const EmailSecuritySetupScreen({super.key});

  @override
  State<EmailSecuritySetupScreen> createState() =>
      _EmailSecuritySetupScreenState();
}

class _EmailSecuritySetupScreenState extends State<EmailSecuritySetupScreen> {
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
      if (mounted) {
        setState(() => _message = 'Doğrulama e-postası yeniden gönderildi.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _message = e.message ?? 'E-posta gönderilemedi.');
      }
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
        if (mounted) {
          setState(
            () => _message =
                'E-posta doğrulandı. Telefon güvenliği adımına geçiliyor.',
          );
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshed!.uid)
            .set({
              'emailVerified': true,
              'emailVerifiedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
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
              '$email adresine gönderilen bağlantıya dokun. E-posta doğrulanmadan telefon güvenliği ve hesap erişimi açılmaz.',
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

class PhoneSecuritySetupScreen extends StatefulWidget {
  const PhoneSecuritySetupScreen({super.key});

  @override
  State<PhoneSecuritySetupScreen> createState() =>
      _PhoneSecuritySetupScreenState();
}

class _PhoneSecuritySetupScreenState extends State<PhoneSecuritySetupScreen> {
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

  String _friendlyPhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Telefon numarası geçersiz. Ülke koduyla birlikte kontrol et. (kod: ${e.code})';
      case 'too-many-requests':
        return 'Çok fazla SMS denemesi yapıldı. Bir süre bekleyip tekrar dene. (kod: ${e.code})';
      case 'quota-exceeded':
        return 'Firebase SMS kotası aşıldı. Daha sonra tekrar dene. (kod: ${e.code})';
      case 'missing-client-identifier':
      case 'missing-app-credential':
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return 'Android uygulama doğrulaması başarısız. APK imzasının SHA-1/SHA-256 değerleri Firebase Android uygulamasına eklenmeli ve Play Integrity/reCAPTCHA yapılandırması kontrol edilmeli. (kod: ${e.code})';
      case 'operation-not-allowed':
        return 'Firebase isteği operation-not-allowed ile reddetti. Phone sağlayıcısı açık olduğuna göre Android uygulama kimliği, proje eşleşmesi ve uygulama doğrulamasını kontrol etmeliyiz. (kod: ${e.code})';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Bağlantıyı kontrol edip tekrar dene. (kod: ${e.code})';
      default:
        final detail = (e.message ?? '').trim();
        return detail.isEmpty
            ? 'SMS doğrulama başlatılamadı. Firebase hata kodu: ${e.code}'
            : '$detail (Firebase kodu: ${e.code})';
    }
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
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _finishVerification(credential, phone);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = _friendlyPhoneError(e);
          });
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _busy = false;
            _error = null;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _busy = false;
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyPhoneError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kod gönderilemedi: ${e.runtimeType}: $e';
      });
    }
  }

  Future<void> _confirmCode() async {
    final id = _verificationId;
    final sms = _code.text.trim();
    if (id == null || sms.length < 4) return;
    final credential = PhoneAuthProvider.credential(
      verificationId: id,
      smsCode: sms,
    );
    await _finishVerification(
      credential,
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
      final alreadyLinked = user.providerData.any(
        (p) => p.providerId == PhoneAuthProvider.PROVIDER_ID,
      );
      if (!alreadyLinked) {
        await user.linkWithCredential(credential);
      } else {
        await user.reauthenticateWithCredential(credential);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': phone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _busy = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
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
              'İki adımlı doğrulama',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'İkinci güvenlik katmanı olarak telefon numaranı SMS koduyla doğrula. Numaran yalnızca hesap güvenliği, kötüye kullanım önleme ve hesap kurtarma için kullanılır. Sonraki açılışlarda cihaz destekliyorsa parmak izi veya yüz tanıma kullanabilirsin.',
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
            if (codeSent)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _verificationId = null;
                        _code.clear();
                        _error = null;
                      }),
                child: const Text('Telefon numarasını değiştir'),
              ),
          ],
        ),
      ),
    );
  }
}
