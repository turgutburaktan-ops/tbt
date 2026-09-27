import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';

class BusinessProfileEditorScreen extends StatefulWidget {
  final String category;
  final String venueId;
  final String venueName;

  const BusinessProfileEditorScreen({
    super.key,
    required this.category,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<BusinessProfileEditorScreen> createState() =>
      _BusinessProfileEditorScreenState();
}

class _BusinessProfileEditorScreenState
    extends State<BusinessProfileEditorScreen> {
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingMedia = false;
  String _openingHours = '';
  String _logoUrl = '';
  String _coverUrl = '';

  String get _key => BusinessService.instance.venueKey(
        widget.category.trim(),
        widget.venueId.trim(),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _phone.dispose();
    _website.dispose();
    super.dispose();
  }

  String _error(Object error) => error is FirebaseFunctionsException
      ? (error.message ?? 'İşlem tamamlanamadı.')
      : error.toString().replaceFirst('Exception: ', '');

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('business_venues')
          .doc(_key)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      _description.text = (data['description'] ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
      _website.text = (data['website'] ?? '').toString();
      _openingHours = (data['openingHours'] ?? '').toString();
      setState(() {
        _logoUrl = (data['logoUrl'] ?? '').toString();
        _coverUrl = (data['coverUrl'] ?? '').toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(_error(error));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await BusinessService.instance.updateProfile(
        category: widget.category.trim(),
        venueId: widget.venueId.trim(),
        description: _description.text.trim(),
        phone: _phone.text.trim(),
        website: _website.text.trim(),
        openingHours: _openingHours,
      );
      _message('İşletme profil bilgileri kaydedildi.');
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage(String kind) async {
    if (_uploadingMedia) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: kind == 'logo' ? 1400 : 2400,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingMedia = true);
    try {
      await BusinessService.instance.updateProfileImage(
        category: widget.category.trim(),
        venueId: widget.venueId.trim(),
        kind: kind,
        image: File(picked.path),
      );
      await _load();
      _message(
        kind == 'logo'
            ? 'İşletme logosu güncellendi.'
            : 'Kapak fotoğrafı güncellendi.',
      );
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletme Profilini Düzenle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                Text(
                  widget.venueName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Doğrulanmış işletme sahibi olarak profilinin görünen bilgilerini buradan yönetebilirsin.',
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 18),
                _MediaEditor(
                  title: 'Kapak fotoğrafı',
                  imageUrl: _coverUrl,
                  height: 150,
                  icon: Icons.panorama_outlined,
                  loading: _uploadingMedia,
                  onTap: () => _pickImage('cover'),
                ),
                const SizedBox(height: 12),
                _MediaEditor(
                  title: 'İşletme logosu',
                  imageUrl: _logoUrl,
                  height: 104,
                  icon: Icons.account_circle_outlined,
                  loading: _uploadingMedia,
                  onTap: () => _pickImage('logo'),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _description,
                  maxLines: 5,
                  maxLength: 1200,
                  decoration: const InputDecoration(
                    labelText: 'İşletme hakkında',
                    hintText: 'Mekanını kısa ve net şekilde anlat.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _website,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Web sitesi',
                    prefixIcon: Icon(Icons.language_rounded),
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Kaydediliyor…' : 'Değişiklikleri Kaydet'),
                ),
              ],
            ),
    );
  }
}

class _MediaEditor extends StatelessWidget {
  final String title;
  final String imageUrl;
  final double height;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _MediaEditor({
    required this.title,
    required this.imageUrl,
    required this.height,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                FirebaseMediaImage(imageUrl: imageUrl, fit: BoxFit.cover)
              else
                Center(child: Icon(icon, size: 38, color: Colors.white30)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xB0000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Icon(
                      loading ? Icons.hourglass_top_rounded : Icons.edit_rounded,
                      size: 19,
                      color: AppColors.cyan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
