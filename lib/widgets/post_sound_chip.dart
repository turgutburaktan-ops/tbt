import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/music_detail_screen.dart';
import '../screens/story_music_picker.dart';

class PostSoundChip extends StatelessWidget {
  final String postId;
  const PostSoundChip({super.key, required this.postId});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
    builder: (_, snap) {
      final p = snap.data?.data() ?? {};
      final id = (p['musicTrackId'] ?? p['originalSoundTrackId'] ?? '').toString();
      if (id.isEmpty) return const SizedBox.shrink();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('music_tracks').doc(id).snapshots(),
        builder: (_, track) {
          final t = track.data?.data();
          if (t == null || t['active'] != true) return const SizedBox.shrink();
          final music = StoryMusicSelection(
            trackId: id, title: (t['title'] ?? '').toString(), artist: (t['artist'] ?? '').toString(),
            artworkUrl: (t['artworkUrl'] ?? '').toString(), previewUrl: (t['audioUrl'] ?? '').toString(),
            durationMs: (t['durationMs'] as num?)?.toInt() ?? 15000,
            startMs: (p['musicStartMs'] as num?)?.toInt() ?? 0,
            clipDurationMs: (p['musicDurationMs'] as num?)?.toInt() ?? ((t['durationMs'] as num?)?.toInt() ?? 15000).clamp(1000,15000).toInt(),
            license: (t['license'] ?? '').toString(), sourceUrl: (t['sourceUrl'] ?? '').toString(),
            mood: (t['mood'] ?? '').toString(),
          );
          return TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MusicDetailScreen(music: music))),
            icon: const Icon(Icons.music_note_rounded, size: 16),
            label: Text('${music.title} — ${music.artist}', maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        },
      );
    },
  );
}
