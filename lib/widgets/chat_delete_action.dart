import 'package:flutter/material.dart';

Future<bool> confirmChatDeletion(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sohbet silinsin mi?'),
      content: const Text(
        'Bu sohbet ve geçmiş mesajları yalnızca senin ekranından kaldırılır. '
        'Karşı tarafın mesajları silinmez. Yeni mesaj gelirse sohbet yeniden görünür.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Sohbeti sil')),
      ],
    ),
  ) ?? false;
}

class ChatDeleteAction extends StatelessWidget {
  const ChatDeleteAction({super.key, required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Sohbet seçenekleri',
    onSelected: (_) => onDelete(),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'delete', child: Text('Sohbeti sil')),
    ],
  );
}
