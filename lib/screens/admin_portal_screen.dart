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
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    if (mounted) setState(() => _allowed = token?.claims?['admin'] == true);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed != true) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Yönetici yetkisi gerekli.')));
    }

    final primary = [
      _ActionData(Icons.dashboard_rounded, 'Genel Bakış', 'Canlı operasyon özeti', '/admin-dashboard'),
      _ActionData(Icons.storefront_rounded, 'İşletmeler', 'Başvurular ve durumlar', '/admin-businesses'),
      _ActionData(Icons.workspace_premium_rounded, 'Business Pro', 'Ücretsiz Pro ver / geri al', '/admin-business-premium', highlighted: true),
      _ActionData(Icons.visibility_rounded, 'İşletme Önizleme', 'İşletme sahibi gibi paneli aç', '/admin-business-preview', highlighted: true),
    ];

    final operations = [
      _ActionData(Icons.manage_accounts_rounded, 'Kullanıcı Yönetimi', 'Kullanıcı ara ve incele', '/admin-users'),
      _ActionData(Icons.shield_rounded, 'Moderasyon', 'Şikâyet ve güvenlik işlemleri', '/moderation'),
      _ActionData(Icons.trending_up_rounded, 'Büyüme', 'Şehir ve dönüşüm sinyalleri', '/admin-growth'),
      _ActionData(Icons.monitor_heart_rounded, 'Sistem Sağlığı', 'Hata ve operasyon kayıtları', '/admin-insights'),
      _ActionData(Icons.layers_outlined, 'Rol Önizleme', 'Misafir/kullanıcı/işletme rolleri', '/admin-preview'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TBT Admin'),
        actions: [
          IconButton(onPressed: _check, tooltip: 'Yetkiyi yenile', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF101D23), Color(0xFF171322), Color(0xFF101116)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cyan.withValues(alpha: .28)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _PortalBadge(),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Operasyon Merkezi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('TBT yönetimi için tek kontrol noktası', style: TextStyle(color: Colors.white60)),
                ])),
                _AdminPill(),
              ]),
              SizedBox(height: 16),
              Text(
                'İşletme doğrulamalarını, premium yetkilerini, kullanıcı güvenliğini ve uygulama önizlemelerini buradan yönet.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Hızlı İşlemler'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: primary.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.18,
            ),
            itemBuilder: (context, index) => _QuickCard(
              data: primary[index],
              onTap: () => Navigator.pushNamed(context, primary[index].route),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Yönetim Araçları'),
          const SizedBox(height: 10),
          ...operations.map((item) => _AdminTile(
                data: item,
                onTap: () => Navigator.pushNamed(context, item.route),
              )),
        ],
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool highlighted;
  const _ActionData(this.icon, this.title, this.subtitle, this.route, {this.highlighted = false});
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900));
}

class _PortalBadge extends StatelessWidget {
  const _PortalBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF07080C)),
  );
}

class _AdminPill extends StatelessWidget {
  const _AdminPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
    child: const Text('ADMIN', style: TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
  );
}

class _QuickCard extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onTap;
  const _QuickCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Ink(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: data.highlighted ? AppColors.surfaceStrong : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.highlighted ? AppColors.cyan.withValues(alpha: .55) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: data.highlighted ? AppColors.cyan.withValues(alpha: .14) : Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)),
          child: Icon(data.icon, color: data.highlighted ? AppColors.cyan : Colors.white70),
        ),
        const Spacer(),
        Text(data.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(data.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.25)),
      ]),
    ),
  );
}

class _AdminTile extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onTap;
  const _AdminTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Icon(data.icon, color: Colors.white70),
      ),
      title: Text(data.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(data.subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
