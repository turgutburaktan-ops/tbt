import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/post_service.dart';
import '../widgets/app_video_player.dart';

class CameraVideoPostScreen extends StatefulWidget {
  final File video;
  final bool isReel;

  const CameraVideoPostScreen({
    super.key,
    required this.video,
    this.isReel = false,
  });

  @override
  State<CameraVideoPostScreen> createState() => _CameraVideoPostScreenState();
}

class _CameraVideoPostScreenState extends State<CameraVideoPostScreen> {
  final _captionController = TextEditingController();
  final _spotController = TextEditingController();
  bool _sharing = false;
  bool _gettingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _captionController.dispose();
    _spotController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    final spotName = _spotController.text.trim();
    final caption = _captionController.text.trim();
    if (spotName.isEmpty) {
      _message('Çekim noktası adını yaz.');
      return;
    }
    if (spotName.length > 120) {
      _message('Çekim noktası adı en fazla 120 karakter olabilir.');
      return;
    }
    if (caption.length > 500) {
      _message('Açıklama en fazla 500 karakter olabilir.');
      return;
    }
    if (!await widget.video.exists() || await widget.video.length() <= 0) {
      _message('Paylaşılacak video bulunamadı.');
      return;
    }
    setState(() => _sharing = true);
    try {
      await PostService.instance.createVideoPost(
        video: widget.video,
        caption: caption,
        spotName: spotName,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      _message(widget.isReel
          ? 'Reels başarıyla paylaşıldı! 🎬'
          : 'Video başarıyla paylaşıldı! 🎬');
      Navigator.of(context).pop(true);
    } catch (error) {
      _message(
        'Paylaşım başarısız: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: Text(widget.isReel ? 'Reels Paylaş' : 'Video Paylaş'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: AppVideoPlayer.file(
                file: widget.video,
                autoplay: true,
                muted: true,
                loop: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isReel
                ? 'Reels paylaşılırken 720p hazırlanacak. En fazla 60 saniye.'
                : 'Video paylaşılırken 720p hazırlanacak. En fazla 60 saniye.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _spotController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Çekim noktası adı',
              hintText: 'Örn. Galata Köprüsü',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _captionController,
            maxLength: 500,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              hintText: 'Videoyu anlat, istersen @kullanici etiketle…',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 70),
                child: Icon(Icons.notes_rounded),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude == null
                          ? Icons.location_on_outlined
                          : Icons.location_on_rounded,
                    ),
              label: Text(
                _latitude == null ? 'Konumumu Ekle' : 'Konum Eklendi ✓',
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sharing
                    ? (widget.isReel
                          ? 'Reels hazırlanıyor…'
                          : 'Video hazırlanıyor…')
                    : (widget.isReel ? 'Reels’i Paylaş' : 'Videoyu Paylaş'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
