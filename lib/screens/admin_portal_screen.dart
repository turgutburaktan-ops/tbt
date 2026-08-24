import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _allowed = token?.claims?['admin'] == true);
  }

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
      appBar: AppBar(title: const Text('TBT Yönetim Merkezi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF121823), Color(0xFF1A1228)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                _PortalBadge(),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operasyon merkezi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kullanıcı, işletme, moderasyon, büyüme, sistem sağlığı ve rol önizlemelerini tek yerden kontrol et.',
                        style: TextStyle(color: Colors.white60, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AdminTile(
            icon: Icons.dashboard_outlined,
            title: 'Genel Bakış',
            subtitle: 'Kullanıcılar, aktiflik, içerikler, etkinlikler ve işletme başvuruları.',
            onTap: () => Navigator.pushNamed(context, '/admin-dashboard'),
          ),
          _AdminTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Kullanıcı Yönetimi',
            subtitle: 'Kullanıcı ara, profil ve güven durumunu incele; moderasyona yönlen.',
            onTap: () => Navigator.pushNamed(context, '/admin-users'),
          ),
          _AdminTile(
            icon: Icons.storefront_outlined,
            title: 'İşletmeler',
            subtitle: 'Bekleyen, doğrulanmış ve reddedilen işletmeleri; premium durumlarını gör.',
            onTap: () => Navigator.pushNamed(context, '/admin-businesses'),
          ),
          _AdminTile(
            icon: Icons.shield_outlined,
            title: 'Moderasyon ve Güvenlik',
            subtitle:
                'Şikâyetler, veri silme talepleri ve güvenlik operasyonları.',
            onTap: () => Navigator.pushNamed(context, '/moderation'),
          ),
          _AdminTile(
            icon: Icons.trending_up_rounded,
            title: 'Büyüme ve Dönüşüm',
            subtitle: 'Şehir yoğunluğu, kullanıcı/işletme tabanı ve büyüme sinyalleri.',
            onTap: () => Navigator.pushNamed(context, '/admin-growth'),
          ),
          _AdminTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Sistem Sağlığı',
            subtitle:
                'Hata kayıtları, analitik olaylar ve operasyon sinyalleri.',
            onTap: () => Navigator.pushNamed(context, '/admin-insights'),
          ),
          _AdminTile(
            icon: Icons.visibility_outlined,
            title: 'Uygulamayı Rol Olarak Önizle',
            subtitle: 'Hesap açmadan Misafir, Kullanıcı, Düzenleyici, İşletme, Doğrulanmış ve Premium görünümünü test et.',
            highlighted: true,
            onTap: () => Navigator.pushNamed(context, '/admin-preview'),
          ),
        ],
      ),
    );
  }
}

class _PortalBadge extends StatelessWidget {
  const _PortalBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppColors.accentGradient,
    ),
    child: const Icon(
      Icons.admin_panel_settings_rounded,
      color: Color(0xFF07080C),
    ),
  );
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.surfaceStrong : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? AppColors.cyan.withValues(alpha: .45)
                : AppColors.border,
          ),
        ),
        child: Icon(icon, color: highlighted ? AppColors.cyan : Colors.white70),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
