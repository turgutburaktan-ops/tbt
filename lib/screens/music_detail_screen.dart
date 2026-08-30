import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'camera_screen.dart';
import 'story_music_picker.dart';

class MusicDetailScreen extends StatefulWidget {
  final StoryMusicSelection music;
  const MusicDetailScreen({super.key, required this.music});

  @override
  State<MusicDetailScreen> createState() => _MusicDetailScreenState();
}

class _MusicDetailScreenState extends State<MusicDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _saved = (prefs.getStringList('story_music_saved') ?? const <String>[]).contains(widget.music.trackId));
  }

  Future<void> _toggleSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('story_music_saved') ?? <String>[]).toSet();
    _saved ? ids.remove(widget.music.trackId) : ids.add(widget.music.trackId);
    await prefs.setStringList('story_music_saved', ids.toList());
    if (mounted) setState(() => _saved = !_saved);
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await _player.setUrl(widget.music.previewUrl);
      await _player.setVolume(widget.music.musicVolume);
      await _player.setClip(
        start: Duration(milliseconds: widget.music.startMs),
        end: Duration(milliseconds: widget.music.startMs + widget.music.clipDurationMs),
      );
      if (mounted) setState(() => _playing = true);
      await _player.play();
      if (mounted) setState(() => _playing = false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müzik açılamadı.')));
    }
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Hak veya içerik bildirimi'),
          content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: 'Nedenini ve hak sahipliği bilgini yaz')),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Gönder')),
          ],
        );
      },
    );
    final user = FirebaseAuth.instance.currentUser;
    if (reason == null || reason.length < 5 || user == null) return;
    await FirebaseFirestore.instance.collection('music_takedown_requests').add(<String, dynamic>{
      'trackId': widget.music.trackId,
      'title': widget.music.title,
      'reporterId': user.uid,
      'reporterEmail': user.email ?? '',
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim incelemeye alındı.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Müzik'),
      actions: <Widget>[
        IconButton(onPressed: _report, tooltip: 'Hak bildirimi', icon: const Icon(Icons.flag_outlined)),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(colors: <Color>[Color(0xFF18D8EE), Color(0xFF5D58F5), Color(0xFFA63DFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: const Icon(Icons.graphic_eq_rounded, size: 94),
        ),
        const SizedBox(height: 20),
        Text(widget.music.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(widget.music.artist, style: const TextStyle(fontSize: 17, color: Colors.white60)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: <Widget>[
          Chip(label: Text(widget.music.license.isEmpty ? 'Lisans kayıtlı' : widget.music.license)),
          Chip(label: Text(widget.music.mood)),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('music_usage').doc(widget.music.trackId).snapshots(),
            builder: (_, snap) => Chip(label: Text('${(snap.data?.data()?['storyCount'] as num?)?.toInt() ?? 0} Story')),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: <Widget>[
          Expanded(child: FilledButton.icon(onPressed: _togglePlay, icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded), label: Text(_playing ? 'Durdur' : '15 sn dinle'))),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: _toggleSaved, tooltip: 'Kaydet', icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded)),
        ]),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(storyMode: true, initialMusic: widget.music))),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Bu müzikle Story oluştur'),
        ),
        if (widget.music.sourceUrl.startsWith('https')) ...<Widget>[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(widget.music.sourceUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Lisans ve kaynak sayfası'),
          ),
        ],
      ],
    ),
  );
}
