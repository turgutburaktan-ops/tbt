import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../services/user_facing_error.dart';
import 'chat_voice_message.dart';

/// Download through authenticated Storage, not transferable download-token URLs.
class EventChatAttachment extends StatefulWidget {
  const EventChatAttachment({
    super.key,
    required this.eventId,
    required this.messageId,
    required this.data,
    required this.mine,
  });
  final String eventId, messageId;
  final Map<String, dynamic> data;
  final bool mine;
  @override
  State<EventChatAttachment> createState() => _EventChatAttachmentState();
}

class _EventChatAttachmentState extends State<EventChatAttachment> {
  File? _file;
  Directory? _directory;
  VideoPlayerController? _video;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.data['type'] == 'image') _open();
  }

  Future<void> _open() async {
    if (_loading || _file != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    Directory? directory;
    try {
      final d = widget.data;
      final path = d['storagePath']?.toString() ?? '';
      final audio = d['type'] == 'audio';
      final prefix =
          'event_chat/${widget.eventId}/${d['senderId']}/${widget.messageId}/';
      if (!path.startsWith(prefix) ||
          path.substring(prefix.length).contains('/') ||
          path.contains('..'))
        throw Exception('Dosya yolu geçersiz.');
      final ref = FirebaseStorage.instance.ref(path);
      final metadata = await ref.getMetadata();
      final limit =
          (audio
              ? 20
              : d['type'] == 'video'
              ? 100
              : 15) *
          1024 *
          1024;
      if ((metadata.size ?? 0) > limit)
        throw Exception('Dosya boyutu desteklenen sınırı aşıyor.');
      directory = await (await getTemporaryDirectory()).createTemp(
        'event_chat_',
      );
      final file = File('${directory.path}/${path.split('/').last}');
      await ref.writeToFile(file);
      if (!mounted) {
        await directory.delete(recursive: true);
        return;
      }
      _directory = directory;
      if (d['type'] == 'video') {
        final controller = VideoPlayerController.file(file);
        _video = controller;
        await controller.initialize();
        if (!mounted) return;
      }
      setState(() {
        _directory = directory;
        _file = file;
      });
    } catch (e) {
      if (directory != null && _file == null && await directory.exists())
        await directory.delete(recursive: true);
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    final video = _video;
    final directory = _directory;
    Future<void>(() async {
      await video?.dispose();
      if (directory != null && await directory.exists())
        await directory.delete(recursive: true);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _loading ? null : _open,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    widget.data['type'] == 'audio'
                        ? Icons.play_circle_outline
                        : widget.data['type'] == 'video'
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                  ),
            label: Text(
              _loading ? 'Yükleniyor…' : '${widget.data['text']} · Aç',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(fontSize: 12)),
        ],
      );
    if (widget.data['type'] == 'audio')
      return ChatAudioBubble(
        url: _file!.uri.toString(),
        durationMs: (widget.data['durationMs'] as num?)?.toInt(),
        mine: widget.mine,
      );
    if (_video != null)
      return Column(
        children: [
          AspectRatio(
            aspectRatio: _video!.value.aspectRatio,
            child: VideoPlayer(_video!),
          ),
          IconButton(
            tooltip: _video!.value.isPlaying ? 'Duraklat' : 'Oynat',
            onPressed: () {
              setState(() {
                _video!.value.isPlaying ? _video!.pause() : _video!.play();
              });
            },
            icon: Icon(
              _video!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ],
      );
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (c) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.file(_file!, fit: BoxFit.contain),
                ),
              ),
              SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(c),
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _file!,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Text('Fotoğraf bu cihazda açılamadı.'),
        ),
      ),
    );
  }
}

