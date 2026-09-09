import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

import '../widgets/tbt_dialog.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/admin_console_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;
  Uint8List? _image;
  int _imageVersion = 0;
  String? _uploadedPath;
  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) throw Exception();
      final bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
      if (bytes.length > 10 * 1024 * 1024) throw Exception();
      if (mounted)
        setState(() {
          _image = bytes;
          _imageVersion++;
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf okunamadı. Başka bir fotoğraf seç.'),
          ),
        );
    }
  }

  String? _requestId;
  String? _payload;
  String? _lastBroadcastId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _title.text.trim().isEmpty || _body.text.trim().isEmpty)
      return;
    setState(() => _sending = true);
    final confirmed = await showTbtDialog<bool>(
      context: context,
      builder: (context) => TbtDialog(
        title: const Text('Herkese gönderilsin mi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_image!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            Text(
              _title.text.trim(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_body.text.trim()),
            const SizedBox(height: 12),
            const Text(
              'Bildirim merkezlerine eklenecek. Telefon bildirimi yalnız tanıtım izni verenlere gönderilir.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _sending = false);
      return;
    }
    final payload =
        '${_title.text.trim()}\n${_body.text.trim()}\n$_imageVersion';
    if (_payload != payload || _requestId == null) {
      _payload = payload;
      _uploadedPath = null;
      _requestId = FirebaseFirestore.instance
          .collection('admin_broadcasts')
          .doc()
          .id;
    }
    try {
      String imagePath = '';
      if (_image != null) {
        imagePath = 'admin_broadcasts/$_requestId/image.jpg';
        if (_uploadedPath != imagePath) {
          final ref = FirebaseStorage.instance.ref(imagePath);
          try {
            await ref.getMetadata();
          } on FirebaseException catch (error) {
            if (error.code != 'object-not-found') rethrow;
            await ref.putData(
              _image!,
              SettableMetadata(contentType: 'image/jpeg'),
            );
          }
          _uploadedPath = imagePath;
        }
      }
      final result = await AdminConsoleService.instance.sendBroadcast(
        requestId: _requestId!,
        title: _title.text.trim(),
        body: _body.text.trim(),
        imagePath: imagePath,
      );
      if (!mounted) return;
      setState(() => _lastBroadcastId = result['broadcastId'] as String);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Duyuru gönderim sırasına alındı. Durumunu aşağıdan takip edebilirsin.',
          ),
        ),
      );
      _title.clear();
      _body.clear();
      _requestId = null;
      _payload = null;
      setState(() {
        _image = null;
        _uploadedPath = null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Duyuru gönderilemedi.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gönderim doğrulanamadı. Tekrar denediğinde aynı duyuru ikinci kez oluşturulmaz.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('TBT Duyurusu')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Tüm kullanıcılara mesaj',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mesaj, bildirim merkezinde TBT adıyla görünür. Telefon bildirimi yalnız tanıtım bildirimlerine izin verenlere iletilir.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 20),
        TextField(
          enabled: !_sending,
          controller: _title,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Başlık'),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: !_sending,
          controller: _body,
          minLines: 5,
          maxLines: 9,
          maxLength: 600,
          decoration: const InputDecoration(labelText: 'Mesaj'),
        ),
        if (_image != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _image!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                          _image = null;
                          _imageVersion++;
                        }),
                  tooltip: 'Fotoğrafı kaldır',
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: _sending ? null : _pickPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_image == null ? 'Fotoğraf ekle' : 'Fotoğrafı değiştir'),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Gönderiliyor…' : 'TBT Adına Herkese Gönder'),
        ),
        if (_lastBroadcastId != null)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('admin_broadcasts')
                .doc(_lastBroadcastId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Gönderim durumu şu anda okunamıyor.'),
                );
              final data = snapshot.data?.data();
              final done = data?['status'] == 'completed';
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  '${done ? 'Tamamlandı' : 'Gönderim sırasında'} · ${data?['recipientCount'] ?? 0} bildirim merkezine eklendi. Telefon teslim sayısı değildir.',
                ),
              );
            },
          ),
      ],
    ),
  );
}
