import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BusinessPanelPreviewScreen extends StatelessWidget {
  final String venueName;
  final String category;
  const BusinessPanelPreviewScreen({
    super.key,
    required this.venueName,
    required this.category,
  });

  String get categoryLabel => switch (category) {
    'cafe' => 'Kafe',
    'dining' => 'Lezzet',
    'hotel' => 'Otel / Konaklama',
    _ => 'İşletme',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('İşletme Paneli')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cyan.withValues(alpha: .5)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceStrong,
                child: Icon(Icons.storefront_rounded, color: AppColors.cyan),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venueName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      categoryLabel,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 15,
                          color: AppColors.cyan,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Admin önizleme',
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Yönetim',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        _item(
          Icons.store_mall_directory_outlined,
          'Profil Bilgileri',
          'Açıklama, telefon ve web sitesi',
        ),
        _item(
          Icons.schedule_rounded,
          'Çalışma Saatleri',
          'Açılış ve kapanış saatleri',
        ),
        _item(
          Icons.account_circle_outlined,
          'Logo ve Kapak',
          'Mekan görsellerini yönet',
        ),
        _item(
          Icons.restaurant_menu_rounded,
          'Menü Yönetimi',
          'Ürün, fiyat, stok ve görünürlük',
        ),
        _item(
          Icons.local_offer_outlined,
          'Kampanyalar',
          'Süreli fırsat ve duyurular',
        ),
        _item(
          Icons.calendar_month_rounded,
          'Etkinlikler',
          'Program ve etkinlik yönetimi',
        ),
        _item(
          Icons.add_to_photos_outlined,
          'Fotoğraf / Video',
          'Mekan adına içerik paylaş',
        ),
        const SizedBox(height: 16),
        const Text(
          'Gelişim',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        _item(
          Icons.query_stats_rounded,
          'İstatistikler',
          'Profil ve içerik performansı',
        ),
        _item(
          Icons.workspace_premium_outlined,
          'TBT Business Pro',
          'Rezervasyon, Boost ve gelişmiş araçlar',
          accent: true,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 19, color: Colors.white54),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Bu ekran yalnızca panel düzenini gösterir. Önizleme modunda hiçbir işletme verisi değiştirilemez.',
                  style: TextStyle(
                    color: Colors.white54,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _item(
    IconData icon,
    String title,
    String subtitle, {
    bool accent = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Icon(icon, color: accent ? AppColors.cyan : Colors.white70),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
    ),
  );
}
