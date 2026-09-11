import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class BusinessWebPortalScreen extends StatelessWidget {
  const BusinessWebPortalScreen({super.key});

  Future<void> _openWebsite(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://trtbt.com/#/profil'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme yönetim merkezi açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('TBT Business')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10252B), Color(0xFF181427), Color(0xFF101116)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.cyan.withValues(alpha: .35)),
          ),
          child: Column(children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.business_center_rounded, color: AppColors.cyan, size: 31),
            ),
            const SizedBox(height: 16),
            const Text('İşletmeni internetten yönet', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Profil, menü, kampanya, etkinlik, rezervasyon, kupon, istatistik ve Business Boost araçları TBT internet sitesindeki yönetim merkezinde bulunur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openWebsite(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Yönetim Merkezini Aç'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
