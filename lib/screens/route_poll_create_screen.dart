import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/route_design/route_design.dart';

class RoutePollDraft {
  const RoutePollDraft(
    this.question,
    this.options,
    this.multiple,
    this.closesAt,
  );
  final String question;
  final List<String> options;
  final bool multiple;
  final DateTime? closesAt;
}

class RoutePollCreateScreen extends StatefulWidget {
  const RoutePollCreateScreen({super.key});
  @override
  State<RoutePollCreateScreen> createState() => _RoutePollCreateScreenState();
}

class _RoutePollCreateScreenState extends State<RoutePollCreateScreen> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _multiple = false;
  DateTime? _end;
  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) c.dispose();
    super.dispose();
  }

  void _save() {
    final values =
        _options
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
    if (_question.text.trim().isEmpty || values.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bir soru ve en az iki farklı seçenek yaz.'),
        ),
      );
      return;
    }
    if (_end != null && !_end!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İleri bir bitiş zamanı seç.')),
      );
      return;
    }
    Navigator.pop(
      context,
      RoutePollDraft(_question.text.trim(), values, _multiple, _end),
    );
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _end ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (mounted && time != null)
      setState(
        () =>
            _end = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Oylama oluştur')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RouteAction(label: 'Oylamayı paylaş', onPressed: _save),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _question,
          maxLength: 180,
          decoration: const InputDecoration(
            labelText: 'Sorun',
            hintText: 'Ne karar veriyoruz?',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Seçenekler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _options[i],
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Seçenek ${i + 1}',
                suffixIcon:
                    _options.length > 2
                        ? IconButton(
                          tooltip: 'Seçeneği kaldır',
                          onPressed: () {
                            final c = _options[i];
                            setState(() => _options.removeAt(i));
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => c.dispose(),
                            );
                          },
                          icon: const Icon(Icons.close),
                        )
                        : null,
              ),
            ),
          ),
        if (_options.length < 4)
          TextButton.icon(
            onPressed:
                () => setState(() => _options.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text('Seçenek ekle'),
          ),
        const Divider(height: 36),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Birden fazla seçim'),
          subtitle: Text(
            _multiple
                ? 'Birden çok seçenek işaretlenebilir.'
                : 'Herkes bir seçenek işaretleyebilir.',
          ),
          value: _multiple,
          onChanged: (v) => setState(() => _multiple = v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bitiş zamanı'),
          subtitle: Text(
            _end == null
                ? 'Belirlenmedi'
                : '${_end!.day}.${_end!.month} · ${TimeOfDay.fromDateTime(_end!).format(context)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _date,
        ),
        if (_end != null)
          TextButton(
            onPressed: () => setState(() => _end = null),
            child: const Text('Bitiş zamanını kaldır'),
          ),
        const SizedBox(height: 24),
        const Text(
          'Oylama rota sohbetinde paylaşılır.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
