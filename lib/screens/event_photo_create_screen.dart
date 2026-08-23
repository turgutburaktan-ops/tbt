import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/social_event.dart';
import '../services/social_event_service.dart';

class EventPhotoCreateScreen extends StatefulWidget {
  const EventPhotoCreateScreen({super.key});

  @override
  State<EventPhotoCreateScreen> createState() => _EventPhotoCreateScreenState();
}

class _EventPhotoCreateScreenState extends State<EventPhotoCreateScreen> {
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController(text: '10');
  final _picker = ImagePicker();

  File? _image;
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 2));
  SocialEventType _type = SocialEventType.social;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _location.dispose();
    _description.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;
    setState(() => _image = File(picked.path));
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF121416),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _dateLabel() {
    final d = _startsAt;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Etkinlik oluşturmak için giriş yapmalısın.');
      return;
    }
    if (_image == null) {
      _message('Etkinlik için bir kapak fotoğrafı ekle.');
      return;
    }
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    if (capacity < 1) {
      _message('Katılımcı sayısı en az 1 olmalı.');
      return;
    }

    setState(() => _saving = true);
    try {
      final eventId = await SocialEventService.instance.create(
        title: _title.text,
        type: _type,
        startsAt: _startsAt,
        capacity: capacity,
        city: _city.text,
        description: _description.text,
        locationLabel: _location.text,
        accessType: EventAccessType.free,
        visibility: EventVisibility.public,
      );

      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/events/$eventId/cover.jpg');
      await ref.putFile(
        _image!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection(SocialEventService.collection)
          .doc(eventId)
          .set({
        'coverImageUrl': url,
        'coverImageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Fotoğraflı Etkinlik'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
        children: [
          GestureDetector(
            onTap: _saving ? null : _chooseImage,
            child: Container(
              height: 230,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 52, color: Colors.white54),
                        SizedBox(height: 10),
                        Text('Etkinlik kapak fotoğrafı ekle', style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text('Kameradan çek veya galeriden seç', style: TextStyle(color: Colors.white54)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_image!, fit: BoxFit.cover),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: FilledButton.tonalIcon(
                            onPressed: _saving ? null : _chooseImage,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Değiştir'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Etkinlik başlığı', prefixIcon: Icon(Icons.title))),
          const SizedBox(height: 12),
          DropdownButtonFormField<SocialEventType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Etkinlik türü'),
            items: SocialEventType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                .toList(),
            onChanged: _saving ? null : (value) => setState(() => _type = value ?? SocialEventType.social),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            tileColor: const Color(0xFF121416),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Tarih ve saat'),
            subtitle: Text(_dateLabel()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _saving ? null : _chooseDateTime,
          ),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Konum / adres', prefixIcon: Icon(Icons.place_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Katılımcı sayısı', prefixIcon: Icon(Icons.groups_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 4, maxLength: 500, decoration: const InputDecoration(labelText: 'Açıklama', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.event_available_outlined),
              label: Text(_saving ? 'Oluşturuluyor...' : 'Etkinliği Oluştur'),
            ),
          ),
        ],
      ),
    );
  }
}
