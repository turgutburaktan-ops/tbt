import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../theme/app_theme.dart';

class AdminInsightsScreen extends StatefulWidget {
  const AdminInsightsScreen({super.key});

  @override
  State<AdminInsightsScreen> createState() => _AdminInsightsScreenState();
}

class _AdminInsightsScreenState extends State<AdminInsightsScreen> {
  bool? _allowed;
  bool _loading = true;
  AdminInsightsData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      final allowed = token?.claims?['admin'] == true;
      if (!allowed) {
        if (mounted) setState(() { _allowed = false; _loading = false; });
        return;
      }
      final data = await AdminConsoleService.instance.insights();
      if (mounted) setState(() { _allowed = true; _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _allowed = true; _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) return const Scaffold(body: Center(child: Text('Yönetici yetkisi gerekli.')));
    final media = MediaQuery.of(context);
    final safeMedia = media.copyWith(textScaler: const TextScaler.linear(1.0));
    return MediaQuery(
      data: safeMedia,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Operasyon ve Kalite', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [IconButton(onPressed: _load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded))],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              const _IntroCard(),
              const SizedBox(height: 16),
              if (_loading && _data == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_error != null && _data == null)
                _ErrorCard(onRetry: _load)
              else ...[
                _MetricsGrid(data: _data!),
                const SizedBox(height: 22),
                const Text('Son uygulama hataları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (_data!.errors.isEmpty)
                  const _EmptyCard()
                else
                  ..._data!.errors.map((d) => _ErrorTile(data: d)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cyan.withValues(alpha: .28)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, color: AppColors.cyan, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Operasyon ve kalite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Güvenlik, veri talepleri ve uygulama sağlığını tek yerden takip et.', style: TextStyle(color: Colors.white60, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MetricsGrid extends StatelessWidget {
  final AdminInsightsData data;
  const _MetricsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Açık şikâyet', data.value('openReports'), Icons.report_gmailerrorred_rounded),
      ('Hesap silme talebi', data.value('deleteRequests'), Icons.person_remove_alt_1_rounded),
      ('Analitik olayı', data.value('analyticsEvents'), Icons.analytics_outlined),
      ('Uygulama hatası', data.value('appErrors'), Icons.bug_report_outlined),
      ('İşletme güven raporu', data.value('trustReports'), Icons.storefront_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns == 3 ? 1.8 : 1.35,
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(item.$3, color: AppColors.cyan, size: 22),
                const Spacer(),
                Text('${item.$2}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(item.$1, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
              ]),
            );
          },
        );
      },
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ErrorTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final title = (data['context'] ?? 'Uygulama').toString();
    final error = (data['error'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded, color: Colors.white70),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.white54),
            const SizedBox(height: 10),
            const Text('Operasyon verileri yüklenemedi', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Admin veri servisiyle bağlantı kurulamadı.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar Dene')),
          ]),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.cyan),
            SizedBox(width: 10),
            Expanded(child: Text('Kayıtlı uygulama hatası yok.', style: TextStyle(color: Colors.white70))),
          ]),
        ),
      );
}
