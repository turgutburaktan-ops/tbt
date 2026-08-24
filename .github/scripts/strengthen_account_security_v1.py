from pathlib import Path

# 1) Register: send email verification immediately after account creation.
p = Path('lib/screens/register_screen.dart')
s = p.read_text()
needle = """      await AuthService.instance.register(email: email, password: password);
      accountCreated = true;
      await AuthService.instance.updateDisplayName(username);
"""
replacement = """      await AuthService.instance.register(email: email, password: password);
      accountCreated = true;
      await AuthService.instance.updateDisplayName(username);
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
"""
if needle in s and 'sendEmailVerification();' not in s:
    s = s.replace(needle, replacement, 1)
p.write_text(s)

# 2) Security gate: email verification must happen before phone verification.
p = Path('lib/screens/account_security_gate.dart')
s = p.read_text()
s = s.replace(
    """    if (!_phoneVerified) {
      return const PhoneSecuritySetupScreen();
    }
""",
    """    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && !user.emailVerified) {
      return const EmailSecuritySetupScreen();
    }

    if (!_phoneVerified) {
      return const PhoneSecuritySetupScreen();
    }
""",
    1,
)

if 'class EmailSecuritySetupScreen' not in s:
    insert_at = s.index('class PhoneSecuritySetupScreen extends StatefulWidget')
    email_screen = r'''class EmailSecuritySetupScreen extends StatefulWidget {
  const EmailSecuritySetupScreen({super.key});

  @override
  State<EmailSecuritySetupScreen> createState() => _EmailSecuritySetupScreenState();
}

class _EmailSecuritySetupScreenState extends State<EmailSecuritySetupScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _sendAgain() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    setState(() { _busy = true; _message = null; });
    try {
      await user.sendEmailVerification();
      if (mounted) setState(() => _message = 'Doğrulama e-postası yeniden gönderildi.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _message = e.message ?? 'E-posta gönderilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _busy = true; _message = null; });
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        if (mounted) setState(() => _message = 'E-posta doğrulandı. Telefon güvenliği adımına geçiliyor.');
        await FirebaseFirestore.instance.collection('users').doc(refreshed!.uid).set({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (mounted) {
        setState(() => _message = 'E-posta henüz doğrulanmamış. Gelen kutunu ve spam klasörünü kontrol et.');
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
          TextButton(onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(), child: const Text('Çıkış')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 68, color: AppColors.violetBright),
            const SizedBox(height: 18),
            const Text('Önce e-postanı doğrula', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('$email adresine gönderilen bağlantıya dokun. E-posta doğrulanmadan telefon güvenliği ve hesap erişimi açılmaz.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.45)),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _busy ? null : _check, icon: const Icon(Icons.verified_outlined), label: const Text('Doğruladım, kontrol et')),
            TextButton(onPressed: _busy ? null : _sendAgain, child: const Text('Doğrulama e-postasını yeniden gönder')),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}

'''
    s = s[:insert_at] + email_screen + s[insert_at:]

# Explain the next security layer clearly and capture consent before SMS.
s = s.replace(
    "'Hesabını korumak için telefon numaranı bir kez SMS koduyla doğrula. Sonraki açılışlarda cihaz destekliyorsa parmak izi kullanabilirsin.'",
    "'İkinci güvenlik katmanı olarak telefon numaranı SMS koduyla doğrula. Numaran yalnızca hesap güvenliği, kötüye kullanım önleme ve hesap kurtarma için kullanılır. Sonraki açılışlarda cihaz destekliyorsa parmak izi veya yüz tanıma kullanabilirsin.'",
)
p.write_text(s)

# Marker
