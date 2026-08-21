import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/social_event.dart';
import '../services/post_service.dart';
import '../widgets/app_video_player.dart';
import '../widgets/content_engagement_bar.dart';
import '../widgets/firebase_media_image.dart';

class EventMemoriesScreen extends StatefulWidget {
  final SocialEvent event;

  const EventMemoriesScreen({super.key, required this.event});

  @override
  State<EventMemoriesScreen> createState() => _EventMemoriesScreenState();
}

class _EventMemoriesScreenState extends State<EventMemoriesScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;

  bool get _started => !widget.event.startsAt.isAfter(DateTime.now());

  bool get _canAdd {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null &&
        _started &&
        widget.event.status != 'cancelled' &&
        widget.event.participantIds.contains(uid);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addMemory() async {
    if (!_canAdd || _uploading) {
      _message(!_started
          ? 'Anılar etkinlik başladıktan sonra eklenebilir.'
          : 'Yalnızca etkinlik katılımcıları anı ekleyebilir.');
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111315),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Etkinlik anısı ekle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Fotoğraf seç'),
                onTap: () => Navigator.pop(sheetContext, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Video seç'),
                subtitle: const Text('En fazla 30 saniye'),
                onTap: () => Navigator.pop(sheetContext, 'video'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    XFile? selected;
    final isVideo = choice == 'video';
    try {
      selected = isVideo
          ? await _picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 30),
            )
          : await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
              maxWidth: 2200,
            );
    } catch (e) {
      _message('Medya seçilemedi: $e');
      return;
    }
    if (selected == null || !mounted) return;

    final caption = TextEditingController();
    final file = File(selected.path);
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D0F11),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(sheet).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: isVideo
                      ? AppVideoPlayer.file(
                          file: file,
                          autoplay: true,
                          muted: true,
                          loop: true,
                          fit: BoxFit.cover,
                        )
                      : Image.file(file, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: caption,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Bu anı için bir not yaz',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheet, true),
                  icon: Icon(isVideo
                      ? Icons.video_call_rounded
                      : Icons.add_photo_alternate_outlined),
                  label: Text(isVideo
                      ? 'Video Anısını Ekle'
                      : 'Etkinlik Anılarına Ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (approved != true || !mounted) {
      caption.dispose();
      return;
    }

    setState(() => _uploading = true);
    try {
      final spotName = widget.event.locationLabel.isNotEmpty
          ? widget.event.locationLabel
          : widget.event.city;
      if (isVideo) {
        await PostService.instance.createEventVideoMemory(
          video: file,
          caption: caption.text,
          spotName: spotName,
          latitude: widget.event.latitude,
          longitude: widget.event.longitude,
          eventId: widget.event.id,
          eventTitle: widget.event.title,
        );
      } else {
        await PostService.instance.createEventMemory(
          image: file,
          caption: caption.text,
          spotName: spotName,
          latitude: widget.event.latitude,
          longitude: widget.event.longitude,
          eventId: widget.event.id,
          eventTitle: widget.event.title,
        );
      }
      _message(widget.event.visibility == EventVisibility.public
          ? 'Anı eklendi ve sosyal akışta da paylaşıldı.'
          : 'Anı eklendi. Bu özel etkinliğin görünürlüğü korunuyor.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      caption.dispose();
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _memoryMedia(Map<String, dynamic> data) {
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final mediaType = (data['mediaType'] ?? '').toString();
    final isVideo = mediaType == 'video' || videoUrl.isNotEmpty;
    final image = (data['imageUrl'] ?? '').toString();
    final storagePath = (data['storagePath'] ?? '').toString();
    final thumbnailUrl = (data['thumbnailUrl'] ?? image).toString();
    final thumbnailStorage =
        (data['thumbnailStoragePath'] ?? storagePath).toString();

    if (isVideo && videoUrl.isNotEmpty) {
      return AppVideoPlayer.network(
        url: videoUrl,
        autoplay: false,
        muted: true,
        loop: true,
        showControls: true,
        fit: BoxFit.cover,
        loading: FirebaseMediaImage(
          imageUrl: thumbnailUrl,
          storagePath: thumbnailStorage,
          fit: BoxFit.cover,
        ),
      );
    }
    return FirebaseMediaImage(
      imageUrl: image,
      storagePath: storagePath,
      fit: BoxFit.cover,
      errorWidget: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Etkinlik Anıları'),
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _addMemory,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_to_photos_outlined),
              label: Text(_uploading ? 'Hazırlanıyor' : 'Anı Ekle'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: PostService.instance.eventMemories(widget.event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text('Anılar yüklenemedi.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final docs = snapshot.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final at = a.data()['createdAt'];
            final bt = b.data()['createdAt'];
            if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
            return 0;
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121416),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF292D32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.event.participantCount} katılımcı • ${docs.length} anı',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 5),
                    const Text('Fotoğraf veya 30 sn video paylaşılabilir.',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    if (!_started) ...[
                      const SizedBox(height: 8),
                      const Text('Anılar etkinlik başladıktan sonra açılacak.',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121416),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          size: 48, color: Colors.white30),
                      const SizedBox(height: 10),
                      Text(
                        _started
                            ? 'Henüz anı eklenmemiş.'
                            : 'Etkinlikten sonra fotoğraf ve videolar burada birikecek.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                )
              else
                ...docs.map((doc) {
                  final d = doc.data();
                  final caption = (d['caption'] ?? '').toString();
                  final name = (d['userName'] ?? 'Katılımcı').toString();
                  final uid = (d['userId'] ?? '').toString();
                  final isVideo = (d['mediaType'] ?? '').toString() == 'video' ||
                      (d['videoUrl'] ?? '').toString().isNotEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111315),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF25292E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFF25292E),
                                child: Icon(Icons.person_outline, size: 19),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                              ),
                              Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.photo_camera_back_outlined,
                                size: 16,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 5),
                              const Text('Etkinlik anısı',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.white54)),
                            ],
                          ),
                        ),
                        AspectRatio(
                          aspectRatio: 4 / 5,
                          child: _memoryMedia(d),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: ContentEngagementBar(
                            collection: 'event_memories',
                            contentId: doc.id,
                            ownerId: uid,
                            title:
                                caption.isEmpty ? widget.event.title : caption,
                            sourceType: 'event_memory',
                          ),
                        ),
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: '$name ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                TextSpan(
                                    text: caption,
                                    style: const TextStyle(
                                        color: Colors.white70)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
