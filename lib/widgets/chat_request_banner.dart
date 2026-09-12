import 'package:flutter/material.dart';

/// Keeps incoming request actions above Android navigation and iOS home areas.
class ChatRequestBanner extends StatelessWidget {
  const ChatRequestBanner({
    super.key,
    required this.incoming,
    required this.onAccept,
    required this.onReject,
    required this.onBlock,
  });

  final bool incoming;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF142238),
    child: SafeArea(
      top: false,
      // Outgoing requests already have a safe-area-aware composer below them.
      bottom: incoming,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              incoming
                  ? 'Mesaj isteği · Kabul edene kadar okundu bilgin paylaşılmaz.'
                  : 'Mesaj isteğin gönderildi. Kabul edilene kadar yalnızca metin gönderebilirsin.',
              style: const TextStyle(fontSize: 12),
            ),
            if (incoming) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('Kabul et'),
                  ),
                  TextButton(onPressed: onReject, child: const Text('Reddet')),
                  TextButton(onPressed: onBlock, child: const Text('Engelle')),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
