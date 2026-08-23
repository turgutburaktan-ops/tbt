import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    if (mounted) setState(() => _allowed = token?.claims?['admin'] == true);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true) return const Scaffold(body: Center(child: Text('Yönetici yetkisi gerekli.')));
    return Scaffold(
      appBar: AppBar(title: const Text('TBT Yönetim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminTile(
            icon: Icons.dashboard_outlined,
            title: 'Genel İstatistikler',
            subtitle: 'Kullanıcılar, etkinlikler, paylaşımlar ve işletme başvuruları.',
            onTap: () => Navigator.pushNamed(context, '/admin-dashboard'),
          ),
          _AdminTile(
            icon: Icons.shield_outlined,
            title: 'Moderasyon ve Güvenlik',
            subtitle: 'Şikâyetler, veri silme talepleri ve işletme güven raporları.',
            onTap: () => Navigator.pushNamed(context, '/moderation'),
          ),
          _AdminTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Uygulama Sağlığı',
            subtitle: 'Hata kayıtları, analitik olaylar ve operasyon sinyalleri.',
            onTap: () => Navigator.pushNamed(context, '/admin-insights'),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AdminTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Icon(icon, size: 30),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
