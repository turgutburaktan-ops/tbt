import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_camera_screen.dart';

class CreatorInviteScreen extends StatefulWidget {
  final String? initialCode;

  const CreatorInviteScreen({super.key, this.initialCode});

  @override
  State<CreatorInviteScreen> createState() => _CreatorInviteScreenState();
}

class _CreatorInviteScreenState extends State<CreatorInviteScreen> {
  late final TextEditingController _codeController;
  bool _loading = false;
  bool _previewLoading = false;
  bool? _valid;
  String _reason = '';
  String _label = '';
  int _remainingUses = 0;
  String? _joinedTier;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if (_codeController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preview());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _code => _codeController.text.trim().toUpperCase();

  Future<void> _preview() async {
    if (_code.isEmpty) return;
    setState(() {
      _previewLoading = true;
      _valid = null;
      _reason = '';
    });
    try {
      final result = await _functions
          .httpsCallable('getCreatorInvitePreview')
          .call(<String, dynamic>{'code': _code});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _valid = data['valid'] == true;
        _reason = (data['reason'] ?? '').toString();
        _label = (data['label'] ?? '').toString();
        _remainingUses = (data['remainingUses'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _valid = false;
        _reason = 'unavailable';
      });
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _redeem() async {
    if (_code.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted || FirebaseAuth.instance.currentUser == null) return;
    }
    setState(() => _loading = true);
    try {
      final result = await _functions
          .httpsCallable('redeemCreatorInvite')
          .call(<String, dynamic>{'code': _code});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() => _joinedTier = (data['tier'] ?? 'creator').toString());
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _message(e.message ?? 'Davet kullanılamadı.');
    } catch (_) {
      if (!mounted) return;
      _message('Davet kullanılamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _invalidMessage() => switch (_reason) {
        'expired' => 'Bu Creator davetinin süresi dolmuş.',
        'used' => 'Bu Creator davetinin kullanım hakkı dolmuş.',
        'inactive' => 'Bu Creator daveti artık aktif değil.',
        'unavailable' => 'Davet servisine şu anda ulaşılamıyor.',
        _ => 'Creator davet kodu geçerli değil.',
      };

  @override
  Widget build(BuildContext context) {
    final joined = _joinedTier != null;
    final founding = _joinedTier == 'founding';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TBT Creator Daveti'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .06),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 38,
                      color: Color(0xFFD7DBDF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    joined
                        ? (founding ? 'Kurucu Creator oldun' : 'TBT Creator oldun')
                        : 'TBT seni Creator olarak davet etti',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    joined
                        ? 'Creator statün profilinde kullanılmak üzere hesabına tanımlandı.'
                        : 'TBT’nin ilk içerik üreticileri arasına katıl ve Creator topluluğunun kurucu döneminde yerini al.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!joined) ...[
              const _Benefit(
                icon: Icons.verified_rounded,
                title: 'Özel Creator statüsü',
                body: 'İlk 100 geçerli davet, Kurucu Creator statüsü kazanır.',
              ),
              const _Benefit(
                icon: Icons.rocket_launch_outlined,
                title: 'Erken dönem topluluğu',
                body: 'Yeni Creator araçları ve iş birliği fırsatları için öncelikli havuzda yer al.',
              ),
              const _Benefit(
                icon: Icons.handshake_outlined,
                title: 'İş birliği ağı',
                body: 'Mekan, etkinlik ve marka iş birlikleri için Creator profilini hazırla.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {
                  _valid = null;
                  _reason = '';
                }),
                decoration: InputDecoration(
                  labelText: 'Creator davet kodu',
                  hintText: 'TBT-XXXXXXXX',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: _previewLoading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Kodu kontrol et',
                          onPressed: _preview,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                ),
              ),
              if (_valid != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _valid == true ? Colors.white24 : Colors.redAccent.withValues(alpha: .5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _valid == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _valid == true ? const Color(0xFFD7DBDF) : Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _valid == true
                              ? '${_label.isEmpty ? 'Creator daveti geçerli.' : _label} $_remainingUses kullanım hakkı kaldı.'
                              : _invalidMessage(),
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _redeem,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    FirebaseAuth.instance.currentUser == null
                        ? 'Giriş yap ve daveti kabul et'
                        : 'Daveti kabul et',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (FirebaseAuth.instance.currentUser == null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Hesabın yoksa giriş ekranından “Kayıt Ol” ile hesabını oluştur. Ardından bu davet bağlantısını tekrar açarak kodu kullanabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ] else ...[
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MainCameraScreen()),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text(
                    'İlk paylaşımını yap',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Benefit({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xFFD7DBDF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(color: Colors.white60, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}
