import 'package:flutter/material.dart';

import '../services/trust_safety_service.dart';

class UserSafetyActions extends StatelessWidget {
  final String userId;
  const UserSafetyActions({super.key, required this.userId});

  Future<void> _report(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcıyı şikâyet et'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Neden?',
            hintText: 'Taciz, sahte hesap, uygunsuz içerik…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Gönder')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 3) return;
    await TrustSafetyService.instance.report(targetType: 'user', targetId: userId, reason: reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şikâyetin moderasyon ekibine gönderildi.')));
    }
  }

  Future<void> _block(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcıyı engelle?'),
        content: const Text('Bu kullanıcıyla sosyal etkileşimlerini sınırlandıracağız.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Engelle')),
        ],
      ),
    );
    if (confirmed != true) return;
    await TrustSafetyService.instance.blockUser(userId);
    if (context.mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Güvenlik seçenekleri',
      onSelected: (value) {
        if (value == 'report') _report(context);
        if (value == 'block') _block(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Şikâyet et'))),
        PopupMenuItem(value: 'block', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Engelle'))),
      ],
    );
  }
}
