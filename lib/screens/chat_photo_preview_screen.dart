import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/private_photo_service.dart';

class ChatPhotoPreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  const ChatPhotoPreviewScreen({super.key, required this.bytes});
  @override
  State<ChatPhotoPreviewScreen> createState() => _ChatPhotoPreviewScreenState();
}

class _ChatPhotoPreviewScreenState extends State<ChatPhotoPreviewScreen> {
  ChatPhotoMode _mode = ChatPhotoMode.keep;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Fotoğraf gönder')),
    body: SafeArea(child: Column(children: [
      Expanded(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
      Flexible(child: SingleChildScrollView(child: Column(children: [
        for (final entry in const {
          ChatPhotoMode.once: '① Bir kez görüntüle',
          ChatPhotoMode.replay: '② Tekrar oynatmaya izin ver',
          ChatPhotoMode.keep: 'Sohbette tut',
        }.entries)
          ListTile(
            leading: Icon(_mode == entry.key ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(entry.value),
            subtitle: entry.key == ChatPhotoMode.replay ? const Text('Toplam iki görüntüleme') : null,
            onTap: () => setState(() => _mode = entry.key)),
        if (_mode != ChatPhotoMode.keep) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(Platform.isIOS
            ? 'iPhone’da ekran görüntüsü kesin engellenemez. Ekran kaydında fotoğraf gizlenir. Fotoğraf 7 gün sonra sona erer.'
            : 'Kaydetme ve iletme kapalıdır. Başka bir cihazla ekranın fotoğrafı çekilebilir. Fotoğraf 7 gün sonra sona erer.',
            style: Theme.of(context).textTheme.bodySmall)),
      ]))),
      Padding(padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context, _mode),
            child: const Text('Gönder')))),
    ])),
  );
}
