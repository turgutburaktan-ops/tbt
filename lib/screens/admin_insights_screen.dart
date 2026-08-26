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
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
        true,
      );
      if (token?.claims?['admin'] != true) {
        if (mounted)
          setState(() {
            _allowed = false;
            _loading = false;
          });
        return;
      }
      final data = await AdminConsoleService.instance.insights();
      if (mounted)
        setState(() {
          _allowed = true;
          _data = data;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _allowed = true;
          _loading = false;
          _error = 'Sistem verileri şu anda yüklenemedi.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    }

    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Sistem Sağlığı'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            children: [
              const _HeaderCard(),
              const SizedBox(height: 14),
              if (_loading && _data == null)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _data == null)
                _RetryCard(onRetry: _load)
              else if (_data != null) ...[
                _MetricsGrid(data: _data!),
                const SizedBox(height: 20),
                const Text(
                  'Son uygulama hataları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 9),
                if (_data!.errors.isEmpty)
                  const _HealthyCard()
                else
                  ..._data!.errors.take(20).map((e) => _ErrorTile(data: e)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.cyan.withValues(alpha: .32)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.monitor_heart_outlined, color: AppColors.cyan, size: 27),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operasyon ve kalite',
                maxLines: 2,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Güvenlik, veri talepleri ve uygulama sağlığını tek yerden takip et.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
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
      ('Açık şikâyet', data.value('openReports'), Icons.report_outlined),
      (
        'Silme talebi',
        data.value('deleteRequests'),
        Icons.person_remove_alt_1_outlined,
      ),
      (
        'Analitik olayı',
        data.value('analyticsEvents'),
        Icons.analytics_outlined,
      ),
      ('Uygulama hatası', data.value('appErrors'), Icons.bug_report_outlined),
      (
        'İşletme güven raporu',
        data.value('trustReports'),
        Icons.storefront_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns == 3 ? 1.7 : 1.25,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$3, color: AppColors.cyan, size: 21),
                  const Spacer(),
                  Text(
                    '${item.$2}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
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
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _RetryCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryCard({required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white54),
          const SizedBox(height: 10),
          const Text(
            'Sistem verileri yüklenemedi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    ),
  );
}

class _HealthyCard extends StatelessWidget {
  const _HealthyCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
          SizedBox(width: 10),
          Expanded(child: Text('Kayıtlı uygulama hatası yok.')),
        ],
      ),
    ),
  );
}
