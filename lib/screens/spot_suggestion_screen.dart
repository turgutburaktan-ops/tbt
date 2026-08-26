import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

class SpotSuggestionScreen extends StatefulWidget {
  const SpotSuggestionScreen({super.key});

  @override
  State<SpotSuggestionScreen> createState() => _SpotSuggestionScreenState();
}

class _SpotSuggestionScreenState extends State<SpotSuggestionScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _description = TextEditingController();
  final _whyVisit = TextEditingController();

  LatLng? _pickedLocation;
  File? _photo;
  bool _submitting = false;
  bool _locating = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _district.dispose();
    _description.dispose();
    _whyVisit.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Konum servisini açmalısın.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message('Konum izni olmadan harita konumu seçilemez.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted)
        setState(() => _pickedLocation = LatLng(p.latitude, p.longitude));
    } catch (_) {
      _message('Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
      requestFullMetadata: false,
    );
    if (file != null && mounted) setState(() => _photo = File(file.path));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Yeni gezilecek yer eklemek için giriş yapmalısın.');
      return;
    }
    if (_name.text.trim().length < 3 || _city.text.trim().length < 2) {
      _message('Yer adı ve şehir bilgilerini doldur.');
      return;
    }
    if (_description.text.trim().length < 10 ||
        _whyVisit.text.trim().length < 5) {
      _message(
        'Açıklama ve neden görülmeli alanlarını biraz daha detaylandır.',
      );
      return;
    }
    if (_pickedLocation == null) {
      _message('Haritadan yerin tam konumunu seç.');
      return;
    }
    if (_photo == null) {
      _message('En az bir fotoğraf eklemelisin.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath = 'users/${user.uid}/spot_submissions/$stamp/photo.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(_photo!, SettableMetadata(contentType: 'image/jpeg'));
      final imageUrl = await ref.getDownloadURL();

      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('submitSpotSuggestion')
          .call({
            'name': _name.text.trim(),
            'city': _city.text.trim(),
            'district': _district.text.trim(),
            'description': _description.text.trim(),
            'whyVisit': _whyVisit.text.trim(),
            'latitude': _pickedLocation!.latitude,
            'longitude': _pickedLocation!.longitude,
            'imageUrl': imageUrl,
            'imageStoragePath': storagePath,
          });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      final duplicate = data['duplicateWarning'] == true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Önerin alındı'),
          content: Text(
            duplicate
                ? 'Yer önerin incelemeye gönderildi. Benzer bir kayıt bulunduğu için admin kontrolünde ayrıca karşılaştırılacak.'
                : 'Yer önerin incelemeye gönderildi. Onaylandıktan sonra Gezilecek Yerler ve haritada görünecek.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      _message(e.message ?? 'Öneri gönderilemedi.');
    } catch (_) {
      _message('Öneri gönderilemedi. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _pickedLocation ?? const LatLng(39.0, 35.0);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yeni Gezilecek Yer Öner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const Text(
            'Topluluğa yeni bir yer kazandır',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sadece gezilecek yer önerileri kabul edilir. Kafe, restoran ve otel ekleme bu alandan yapılamaz.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Yer adı'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _district,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'İlçe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Kısa açıklama',
              hintText: 'Burası nasıl bir yer?',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _whyVisit,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Neden görülmeli?'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Konum',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(_locating ? 'Alınıyor…' : 'Konumumu kullan'),
              ),
            ],
          ),
          Container(
            height: 230,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initial,
                zoom: _pickedLocation == null ? 5.2 : 15,
              ),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              markers: _pickedLocation == null
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('picked'),
                        position: _pickedLocation!,
                      ),
                    },
              onTap: (point) => setState(() => _pickedLocation = point),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Haritada yerin tam noktasına dokun.',
            style: TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _photo == null ? 'Fotoğraf Ekle' : 'Fotoğraf seçildi ✓',
            ),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _photo!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.cyan,
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Gönderdiğin yer hemen yayınlanmaz. Admin incelemesinden sonra onaylanır; mükerrer veya uygun olmayan öneriler reddedilir.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _submitting ? 'İncelemeye gönderiliyor…' : 'İncelemeye Gönder',
            ),
          ),
        ],
      ),
    );
  }
}
