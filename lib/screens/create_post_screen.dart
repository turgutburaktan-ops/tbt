import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialImagePath;

  const CreatePostScreen({
    super.key,
    this.initialImagePath,
  });

  @override
  State<CreatePostScreen> createState() =>
      _CreatePostScreenState();
}

class _CreatePostScreenState
    extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _captionController =
      TextEditingController();

  final TextEditingController _spotController =
      TextEditingController();

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

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141126),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: const Text(
                    'Kamera ile çek',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: const Text(
                    'Galeriden seç',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    try {
      final selected =
          await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
      );

      if (selected == null) return;

      if (!mounted) return;

      setState(() {
        _image = File(selected.path);
      });
    } catch (e) {
      if (!mounted) return;

      _message(
        'Fotoğraf seçilemedi: $e',
      );
    }
  }

  Future<void> _getLocation() async {
    if (_gettingLocation) return;

    setState(() {
      _gettingLocation = true;
    });

    try {
      final enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw Exception(
          'Telefonun konum servisini aç.',
        );
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        throw Exception(
          'Konum izni verilmedi.',
        );
      }

      final position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      _message('Konum eklendi.');
    } catch (e) {
      if (!mounted) return;

      _message(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  Future<void> _share() async {
    if (_image == null) {
      _message(
        'Önce bir fotoğraf seç veya çek.',
      );
      return;
    }

    if (_spotController.text.trim().isEmpty) {
      _message(
        'Çekim noktası adını yaz.',
      );
      return;
    }

    if (PostService.instance.currentUser == null) {
      _message(
        'Paylaşım yapmak için giriş yapmalısın.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await PostService.instance.createPost(
        image: _image!,
        caption: _captionController.text,
        spotName: _spotController.text,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (!mounted) return;

      _message(
        'Fotoğraf başarıyla paylaşıldı! 📸',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      _message(
        'Paylaşım başarısız: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: const Color(0xFF090812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090812),
        foregroundColor: Colors.white,
        title: const Text(
          'Fotoğraf Paylaş',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          16,
          18,
          40,
        ),
        children: [
          GestureDetector(
            onTap: _chooseSource,
            child: Container(
              height: 330,
              decoration: BoxDecoration(
                color: const Color(0xFF141126),
                borderRadius:
                    BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? const Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons
                              .add_photo_alternate_outlined,
                          color: yellow,
                          size: 68,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Fotoğraf ekle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Kamera veya galeri',
                          style: TextStyle(
                            color:
                                Colors.white54,
                          ),
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
                icon: const Icon(
                  Icons.edit,
                ),
                label: const Text(
                  'Fotoğrafı değiştir',
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          TextField(
            controller: _spotController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'Çekim noktası adı',
              hintText:
                  'Örn. Galata Köprüsü',
              prefixIcon: const Icon(
                Icons.place_outlined,
                color: yellow,
              ),
              filled: true,
              fillColor:
                  const Color(0xFF141126),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller:
                _captionController,
            maxLines: 4,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'Açıklama',
              hintText:
                  'Bu noktada fotoğrafı nasıl çektin?',
              prefixIcon: const Padding(
                padding:
                    EdgeInsets.only(bottom: 70),
                child: Icon(
                  Icons.notes,
                  color: yellow,
                ),
              ),
              filled: true,
              fillColor:
                  const Color(0xFF141126),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation
                  ? null
                  : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _latitude != null
                          ? Icons
                              .location_on
                          : Icons
                              .location_on_outlined,
                    ),
              label: Text(
                _latitude == null
                    ? 'Konumumu Ekle'
                    : 'Konum Eklendi ✓',
              ),
            ),
          ),

          if (_latitude != null &&
              _longitude != null)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 8,
              ),
              child: Text(
                '${_latitude!.toStringAsFixed(5)}, '
                '${_longitude!.toStringAsFixed(5)}',
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 26),

          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor:
                    Colors.black,
              ),
              onPressed:
                  _loading ? null : _share,
              icon: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                    ),
              label: Text(
                _loading
                    ? 'Yükleniyor...'
                    : 'Paylaş',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
