import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'admin_business_preview_screen.dart';
import 'admin_business_sandbox_screen.dart';
import 'admin_businesses_v2_screen.dart';

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

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _demoBusiness() => _open(
    const AdminBusinessSandboxScreen(
      venueName: 'TBT Demo İşletme',
      category: 'cafe',
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_allowed != true) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TBT Yönetim Merkezi'),
        actions: [
          IconButton(
            onPressed: _check,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10242A),
                  Color(0xFF171523),
                  Color(0xFF101116),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.cyan.withValues(alpha: .4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: AppColors.cyan, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Operasyon Merkezi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    ),
                    _AdminPill(),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  'İşletmeleri, kullanıcı katkılarını ve moderasyon işlemlerini tek yerden yönet.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('İşletme Yönetimi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _HeroAction(
            icon: Icons.storefront_rounded,
            title: 'İşletmeler',
            subtitle: 'Bir işletmeye dokun ve gerçek veriye dokunmadan işletme sahibi gibi test et.',
            button: 'İşletmeleri Aç',
            onTap: () => _open(const AdminBusinessesV2Screen()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactAction(
                  icon: Icons.visibility_rounded,
                  title: 'Panel Testi',
                  subtitle: 'Kayıtlı işletmeyi seç, menü ve etkinlik dahil paneli dene.',
                  onTap: () => _open(const AdminBusinessPreviewScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactAction(
                  icon: Icons.science_outlined,
                  title: 'Demo İşletme',
                  subtitle: 'Hiçbir şey kaydetmeden tüm işletme işlemlerini dene.',
                  onTap: _demoBusiness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _RouteTile(Icons.workspace_premium_rounded, 'Business Pro', 'İşletmeye Premium/Pro ver veya geri al.', '/admin-business-premium', accent: true),
          const SizedBox(height: 22),
          const Text('Topluluk Katkıları', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          const _RouteTile(Icons.add_location_alt_rounded, 'Yeni Yer Önerileri', 'Kullanıcıların eklediği gezilecek yerleri onayla, reddet veya mükerrer işaretle.', '/admin-spot-submissions', accent: true),
          const SizedBox(height: 22),
          const Text('Operasyon', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          const _RouteTile(Icons.dashboard_rounded, 'Genel Bakış', 'Bekleyen işlemler ve sistem özeti.', '/admin-dashboard'),
          const _RouteTile(Icons.manage_accounts_rounded, 'Kullanıcı Yönetimi', 'Kullanıcı ara ve hesabı incele.', '/admin-users'),
          const _RouteTile(Icons.shield_rounded, 'Moderasyon', 'Şikâyetler ve güvenlik işlemleri.', '/moderation'),
          const _RouteTile(Icons.trending_up_rounded, 'Büyüme', 'Şehir, kullanım ve dönüşüm sinyalleri.', '/admin-growth'),
          const _RouteTile(Icons.monitor_heart_rounded, 'Sistem Sağlığı', 'Hata ve operasyon kayıtları.', '/admin-insights'),
          const SizedBox(height: 22),
          const Text('Uygulama Testleri', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          const _RouteTile(Icons.layers_outlined, 'Rol Önizleme', 'Misafir, kullanıcı, düzenleyici ve işletme rollerini test et.', '/admin-preview'),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onTap;

  const _HeroAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cyan.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.cyan, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.3)),
                const SizedBox(height: 9),
                Text(button, style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _CompactAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CompactAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Ink(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.cyan),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.25),
          ),
        ],
      ),
    ),
  );
}

class _RouteTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool accent;

  const _RouteTile(
    this.icon,
    this.title,
    this.subtitle,
    this.route, {
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent ? AppColors.cyan.withValues(alpha: .12) : AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent ? AppColors.cyan.withValues(alpha: .4) : AppColors.border,
          ),
        ),
        child: Icon(icon, color: accent ? AppColors.cyan : Colors.white70),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pushNamed(context, route),
    ),
  );
}

class _AdminPill extends StatelessWidget {
  const _AdminPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.cyan.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'ADMIN',
      style: TextStyle(
        color: AppColors.cyan,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );
}
