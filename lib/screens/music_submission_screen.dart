import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MusicSubmissionScreen extends StatefulWidget {
  const MusicSubmissionScreen({super.key});

  @override
  State<MusicSubmissionScreen> createState() => _MusicSubmissionScreenState();
}

class _MusicSubmissionScreenState extends State<MusicSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  XFile? _audio;
  final _sourceUrl = TextEditingController();
  final _attribution = TextEditingController();
  String _category = 'Türkçe';
  String _mood = 'Gezi';
  String _license = 'DIRECT-TBT';
  bool _commercial = false;
  bool _derivatives = false;
  bool _catalog = false;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in <TextEditingController>[_title, _artist, _sourceUrl, _attribution]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().length < 2 ? 'Bu alan gerekli.' : null;

  String? _url(String? value) {
    final uri = Uri.tryParse((value ?? '').trim());
    return uri != null && uri.scheme == 'https' ? null : 'HTTPS bağlantısı gir.';
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce giriş yapmalısın.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_audio == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bir ses dosyası seç.'))); return; }
    if (!_commercial || !_derivatives || !_catalog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Üç kullanım izninin de hak sahibi tarafından verilmesi gerekir.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final submission = FirebaseFirestore.instance.collection('music_submissions').doc();
      final bytes = await _audio!.readAsBytes();
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) throw Exception('Ses dosyası en fazla 20 MB olabilir.');
      final ext = _audio!.name.split('.').last.toLowerCase();
      final type = {'mp3':'audio/mpeg', 'm4a':'audio/mp4', 'wav':'audio/wav', 'ogg':'audio/ogg', 'aac':'audio/aac'}[ext];
      if (type == null) throw Exception('MP3, M4A, WAV, OGG veya AAC seç.');
      final storage = FirebaseStorage.instance.ref('users/${user.uid}/music_submissions/${submission.id}/audio.$ext');
      await storage.putData(bytes, SettableMetadata(contentType: type));
      await submission.set(<String, dynamic>{
        'submittedBy': user.uid,
        'submitterName': user.displayName ?? '',
        'submitterEmail': user.email ?? '',
        'title': _title.text.trim(),
        'artist': _artist.text.trim(),
        'audioUrl': await storage.getDownloadURL(),
        'audioStoragePath': storage.fullPath,
        'consentVersion': 'v1',
        'sourceUrl': _sourceUrl.text.trim(),
        'attributionText': _attribution.text.trim(),
        'category': _category,
        'mood': _mood,
        'licenseType': _license,
        'commercialUseAllowed': true,
        'derivativesAllowed': true,
        'catalogDistributionAllowed': true,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müzik incelemeye gönderildi. Onaylanmadan katalogda görünmez.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başvuru gönderilemedi. Bağlantıları kontrol et.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TBT Sanatçı Programı')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: <Widget>[
          const Text('Müziğin TBT’de keşfedilsin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Yalnızca sahibi olduğun veya TBT kataloğunda kullanma yetkisi bulunan müziği gönder.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextFormField(controller: _title, validator: _required, decoration: const InputDecoration(labelText: 'Parça adı')),
          const SizedBox(height: 10),
          TextFormField(controller: _artist, validator: _required, decoration: const InputDecoration(labelText: 'Sanatçı adı')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sending ? null : () async {
              final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Ses', extensions: ['mp3','m4a','wav','ogg','aac'], uniformTypeIdentifiers: ['public.audio'])]);
              if (mounted && file != null) setState(() => _audio = file);
            },
            icon: const Icon(Icons.audio_file_outlined), label: Text(_audio?.name ?? 'Ses dosyası seç (en fazla 20 MB)'),
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _sourceUrl, validator: _url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Lisans / kaynak sayfası')),
          const SizedBox(height: 10),
          TextFormField(controller: _attribution, maxLines: 2, decoration: const InputDecoration(labelText: 'Atıf metni (varsa)')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _license,
            decoration: const InputDecoration(labelText: 'Lisans'),
            items: const ['DIRECT-TBT', 'CC0-1.0', 'CC-BY-4.0'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => _license = v ?? _license),
          ),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Dil'),
              items: const ['Türkçe', 'Yabancı', 'Enstrümantal'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _mood,
              decoration: const InputDecoration(labelText: 'Tarz'),
              items: const ['Gezi', 'Chill', 'Enerjik', 'Romantik', 'Sinematik', 'Elektronik'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => _mood = v ?? _mood),
            )),
          ]),
          const SizedBox(height: 12),
          CheckboxListTile(value: _commercial, onChanged: (v) => setState(() => _commercial = v == true), title: const Text('Ticari kullanıma izin veriyorum'), contentPadding: EdgeInsets.zero),
          CheckboxListTile(value: _derivatives, onChanged: (v) => setState(() => _derivatives = v == true), title: const Text('15–60 saniyelik kesme, karıştırma ve TBT videoları/Story ile eşlemeye izin veriyorum'), contentPadding: EdgeInsets.zero),
          CheckboxListTile(value: _catalog, onChanged: (v) => setState(() => _catalog = v == true), title: const Text('TBT kullanıcı kataloğunda sunulmasına izin veriyorum'), contentPadding: EdgeInsets.zero),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_user_outlined),
            label: const Text('İncelemeye Gönder'),
          ),
        ],
      ),
    ),
  );
}
