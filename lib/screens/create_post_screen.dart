import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/content_engagement_service.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialImagePath;

  const CreatePostScreen({
    super.key,
    this.initialImagePath,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _spotController = TextEditingController();

  final List<Map<String, String>> _taggedUsers = <Map<String, String>>[];

  File? _image;
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _image = File(widget.initialImagePath!);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _spotController.dispose();
    super.dispose();
  }

  Future<void> _chooseSource() async {
    if (_loading) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFFB7BCC2),
                ),
                title: const Text('Kamera ile çek'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFFB7BCC2),
                ),
                title: const Text('Galeriden seç'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (selected == null || !mounted) return;
      setState(() => _image = File(selected.path));
    } catch (e) {
      if (!mounted) return;
      _message('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _getLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Telefonun konum servisini aç.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _message('Konum eklendi.');
    } catch (e) {
      if (!mounted) return;
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _addTag() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0E1012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .64,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Açıklamaya kişi etiketle',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.users(),
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Kullanıcılar yüklenemedi.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users =
                      snapshot.data!.docs.where((d) => d.id != me).toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final doc = users[index];
                      final data = doc.data();
                      final name =
                          (data['displayName'] ?? data['email'] ?? 'Kullanıcı')
                              .toString()
                              .trim();
                      final photo = (data['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A1D20),
                          backgroundImage:
                              photo.isEmpty ? null : NetworkImage(photo),
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        title: Text(name),
                        onTap: () => Navigator.pop(
                          sheetContext,
                          {'id': doc.id, 'name': name},
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final id = selected['id'] ?? '';
    final name = selected['name'] ?? 'Kullanıcı';
    if (id.isEmpty || _taggedUsers.any((u) => u['id'] == id)) return;

    setState(() {
      _taggedUsers.add(selected);
      final mention = '@${name.replaceAll(' ', '')}';
      final current = _captionController.text.trimRight();
      _captionController.text = current.isEmpty ? mention : '$current $mention';
      _captionController.selection = TextSelection.collapsed(
        offset: _captionController.text.length,
      );
    });
  }

  void _removeTag(Map<String, String> user) {
    setState(() {
      _taggedUsers.removeWhere((u) => u['id'] == user['id']);
      final name = user['name'] ?? '';
      if (name.isNotEmpty) {
        final mention = '@${name.replaceAll(' ', '')}';
        _captionController.text = _captionController.text
            .replaceAll(mention, '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
        _captionController.selection = TextSelection.collapsed(
          offset: _captionController.text.length,
        );
      }
    });
  }

  Future<void> _share() async {
    if (_image == null) {
      _message('Önce bir fotoğraf seç veya çek.');
      return;
    }
    if (_spotController.text.trim().isEmpty) {
      _message('Çekim noktası adını yaz.');
      return;
    }
    if (PostService.instance.currentUser == null) {
      _message('Paylaşım yapmak için giriş yapmalısın.');
      return;
    }

    setState(() => _loading = true);
    try {
      await PostService.instance.createPost(
        image: _image!,
        caption: _captionController.text,
        spotName: _spotController.text,
        latitude: _latitude,
        longitude: _longitude,
        taggedUserIds: _taggedUsers
            .map((u) => u['id'] ?? '')
            .where((e) => e.isNotEmpty)
            .toList(),
        taggedUserNames: _taggedUsers
            .map((u) => u['name'] ?? '')
            .where((e) => e.isNotEmpty)
            .toList(),
      );

      if (!mounted) return;
      _message('Fotoğraf başarıyla paylaşıldı! 📸');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _message(
        'Paylaşım başarısız: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFB7BCC2);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: const Text('Fotoğraf Paylaş'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          GestureDetector(
            onTap: _chooseSource,
            child: Container(
              height: 330,
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x334B5158)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: purple,
                          size: 68,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Fotoğraf ekle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Kamera veya galeri',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : Image.file(
                      _image!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (_image != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _chooseSource,
                icon: const Icon(Icons.edit),
                label: const Text('Fotoğrafı değiştir'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _spotController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Çekim noktası adı',
              hintText: 'Örn. Galata Köprüsü',
              prefixIcon: const Icon(Icons.place_outlined, color: purple),
              filled: true,
              fillColor: const Color(0xFF121416),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121416),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x228B5CF6)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _captionController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Fotoğrafı anlat, istersen arkadaşını etiketle…',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 70),
                      child: Icon(Icons.notes, color: purple),
                    ),
                    filled: false,
                    border: InputBorder.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addTag,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFC4CA),
                          side: const BorderSide(color: Color(0x558B5CF6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        icon:
                            const Icon(Icons.alternate_email_rounded, size: 18),
                        label: const Text('Kişi etiketle'),
                      ),
                      const Spacer(),
                      Text(
                        '${_captionController.text.length}/500',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_taggedUsers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taggedUsers
                  .map(
                    (user) => InputChip(
                      avatar:
                          const Icon(Icons.alternate_email_rounded, size: 16),
                      label: Text(user['name'] ?? 'Kullanıcı'),
                      onDeleted: () => _removeTag(user),
                      backgroundColor: const Color(0xFF1B1430),
                      side: const BorderSide(color: Color(0x448B5CF6)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude != null
                          ? Icons.location_on
                          : Icons.location_on_outlined,
                    ),
              label: Text(
                _latitude == null ? 'Konumumu Ekle' : 'Konum Eklendi ✓',
              ),
            ),
          ),
          if (_latitude != null && _longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          const SizedBox(height: 26),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _loading ? null : _share,
              icon: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _loading ? 'Yükleniyor...' : 'Paylaş',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
