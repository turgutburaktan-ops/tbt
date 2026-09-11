import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class RoleInviteScreen extends StatefulWidget {
  const RoleInviteScreen({super.key, required this.role, required this.code});

  final String role;
  final String code;

  @override
  State<RoleInviteScreen> createState() => _RoleInviteScreenState();
}

class _RoleInviteScreenState extends State<RoleInviteScreen> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  Map<String, dynamic>? _invite;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _functions.httpsCallable('getRoleInvitePreview').call({
        'role': widget.role,
        'code': widget.code,
      });
      final invite = Map<String, dynamic>.from(result.data as Map);
      if (invite['valid'] != true) throw Exception('invalid');
      if (mounted) setState(() => _invite = invite);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Bu özel davet artık kullanılamıyor.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (mounted) _load();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _functions.httpsCallable('redeemRoleInvite').call({
        'role': widget.role,
        'code': widget.code,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data['roleLabel']} hesabın aktif edildi.')),
      );
      Navigator.pushReplacementNamed(context, '/rewards');
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Davet kullanılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData get _icon => switch (widget.role) {
        'creator' => Icons.auto_awesome_rounded,
        'explorer' => Icons.explore_rounded,
        'social' => Icons.groups_rounded,
        'gourmet' => Icons.restaurant_rounded,
        _ => Icons.workspace_premium_rounded,
      };

  String get _description => switch (widget.role) {
        'creator' => 'Özgün gönderilerini, Reels videolarını ve hikâyelerini Creator araçlarıyla büyüt.',
        'explorer' => 'Gezilecek yerleri, rotaları ve konumlu gezi paylaşımlarını TBT topluluğuyla buluştur.',
        'social' => 'Etkinlikler oluştur, gerçek katılımlarla topluluğu bir araya getir.',
        'gourmet' => 'Kafe, restoran ve otel deneyimlerini paylaşarak yeni mekânların keşfedilmesini sağla.',
        _ => 'TBT özel hesap türüne katıl.',
      };

  @override
  Widget build(BuildContext context) {
    final label = (_invite?['roleLabel'] ?? 'TBT özel daveti').toString();
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('TBT özel daveti')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10243D),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2F5378)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF173A59),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, size: 36, color: const Color(0xFF73E4D6)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '$label olmaya davet edildin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB8C7D9), height: 1.5),
                    ),
                    if ((_invite?['label'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${_invite!['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 24),
                    if (_busy) const LinearProgressIndicator(),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy || _error != null ? null : _accept,
                        child: Text(
                          FirebaseAuth.instance.currentUser == null
                              ? 'Hesap oluştur / giriş yap'
                              : 'Daveti kabul et',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bu bağlantı yalnızca davet edilen kişi içindir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
