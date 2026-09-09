import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class AdminCreatorInvitesScreen extends StatefulWidget {
  const AdminCreatorInvitesScreen({super.key});

  @override
  State<AdminCreatorInvitesScreen> createState() => _AdminCreatorInvitesScreenState();
}

class _AdminCreatorInvitesScreenState extends State<AdminCreatorInvitesScreen> {
  final _labelController = TextEditingController();
  int _maxUses = 1;
  int _expiresInDays = 30;
  bool _loading = false;
  String _code = '';
  String _url = '';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final result = await _functions.httpsCallable('createCreatorInvite').call({
        'label': _labelController.text.trim(),
        'maxUses': _maxUses,
        'expiresInDays': _expiresInDays,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _code = (data['code'] ?? '').toString();
        _url = (data['url'] ?? '').toString();
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) _message(e.message ?? 'Davet oluşturulamadı.');
    } catch (_) {
      if (mounted) _message('Davet oluşturulamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String value, String message) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message(message);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Creator Davetleri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFD7DBDF)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'TBT İlk 100 Creator',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Influencer için kişiye özel veya sınırlı kullanımlı davet oluştur. İlk 100 geçerli kullanım Kurucu Creator statüsü kazanır.',
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _labelController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Davet etiketi',
              hintText: 'Örn. Ayşe Yılmaz / Instagram',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _maxUses,
            decoration: const InputDecoration(
              labelText: 'Kullanım hakkı',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
            items: const [1, 2, 5, 10, 20]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v kullanım')))
                .toList(),
            onChanged: _loading ? null : (v) => setState(() => _maxUses = v ?? 1),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _expiresInDays,
            decoration: const InputDecoration(
              labelText: 'Geçerlilik',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
            items: const [7, 14, 30, 60, 90]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v gün')))
                .toList(),
            onChanged: _loading ? null : (v) => setState(() => _expiresInDays = v ?? 30),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _loading ? null : _create,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_link_rounded),
              label: const Text(
                'Creator daveti oluştur',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (_code.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Davet hazır',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _code,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _url,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copy(_code, 'Creator kodu kopyalandı.'),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Kodu kopyala'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _copy(_url, 'Creator davet linki kopyalandı.'),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Linki kopyala'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
