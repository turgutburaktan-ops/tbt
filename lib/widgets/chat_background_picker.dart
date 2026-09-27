import 'package:flutter/material.dart';

import '../services/chat_appearance_service.dart';
import 'chat_surface.dart';

class ChatBackgroundTile extends StatelessWidget {
  const ChatBackgroundTile({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ChatAppearanceService.instance,
    builder: (context, _) => ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Sohbet arka planı'),
      subtitle: Text(ChatAppearanceService.instance.background.label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final service = ChatAppearanceService.instance;
        // Let the stored selection load before showing the draft preview.
        await service.ready;
        if (!context.mounted) return;
        final selected = await showModalBottomSheet<ChatBackground>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: ChatSurface.panel,
          builder: (_) => ChatBackgroundPicker(service: service),
        );
        if (selected != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sohbet arka planı güncellendi.')),
          );
        }
      },
    ),
  );
}

class ChatBackgroundPicker extends StatefulWidget {
  const ChatBackgroundPicker({super.key, required this.service});
  final ChatAppearanceService service;

  @override
  State<ChatBackgroundPicker> createState() => _ChatBackgroundPickerState();
}

class _ChatBackgroundPickerState extends State<ChatBackgroundPicker> {
  late ChatBackground _selected = widget.service.background;
  late final String? _userId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = widget.service.userId;
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      if (_userId != widget.service.userId) throw StateError('Account changed');
      await widget.service.select(_selected);
      if (mounted) Navigator.pop(context, _selected);
    } catch (_) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Renk kaydedilemedi. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sohbet arka planı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Seçtiğin renk bu cihazda tüm sohbetlerinde yalnızca sana görünür.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ChatBackdrop(
              color: _selected.color,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _previewBubble('Hafta sonu nereye gidiyoruz?', false),
                  const SizedBox(height: 12),
                  _previewBubble('Yeni yerler keşfedelim 🌍', true),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ChatBackground.values.map((background) => ChoiceChip(
              label: Text(background.label),
              avatar: CircleAvatar(backgroundColor: background.color, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38)))),
              selected: _selected == background,
              onSelected: _saving ? null : (_) => setState(() => _selected = background),
            )).toList(),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet')),
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        ],
      ),
    ),
  );

  Widget _previewBubble(String text, bool mine) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 235),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: mine ? const Color(0xFF294D7A) : ChatSurface.panel, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );
}
