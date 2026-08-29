import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StoryMusicSelection {
  final String trackId;
  final String title;
  final String artist;
  final String artworkUrl;
  final String previewUrl;
  final int durationMs;
  final int startMs;
  final int clipDurationMs;
  final String stickerStyle;

  const StoryMusicSelection({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.previewUrl,
    required this.durationMs,
    required this.startMs,
    this.clipDurationMs = 15000,
    this.stickerStyle = 'minimal',
  });

  StoryMusicSelection copyWith({int? startMs, String? stickerStyle}) {
    return StoryMusicSelection(
      trackId: trackId,
      title: title,
      artist: artist,
      artworkUrl: artworkUrl,
      previewUrl: previewUrl,
      durationMs: durationMs,
      startMs: startMs ?? this.startMs,
      clipDurationMs: clipDurationMs,
      stickerStyle: stickerStyle ?? this.stickerStyle,
    );
  }
}

class StoryMusicPicker extends StatefulWidget {
  const StoryMusicPicker({super.key});

  @override
  State<StoryMusicPicker> createState() => _StoryMusicPickerState();
}

class _StoryMusicPickerState extends State<StoryMusicPicker> {
  String _query = '';
  String _category = 'Senin için';

  static const List<String> _categories = <String>[
    'Senin için',
    'Trend',
    'Türkçe',
    'Yabancı',
    'Kaydedilenler',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF090B0F),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Müzik ekle',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Şarkı veya sanatçı ara',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFF15181E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, int index) {
                    final String item = _categories[index];
                    final bool selected = item == _category;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(item),
                      onSelected: (_) => setState(() => _category = item),
                      selectedColor: const Color(0xFF6947F5),
                      backgroundColor: const Color(0xFF15181E),
                      side: BorderSide.none,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('music_tracks').limit(160).snapshots(),
                  builder: (BuildContext context, snapshot) {
                    if (snapshot.hasError) {
                      return const _MusicEmpty(
                        icon: Icons.library_music_outlined,
                        title: 'Müzik kataloğu şu an kullanılamıyor',
                        subtitle: 'Katalog bağlantısı hazır olduğunda şarkılar burada görünecek.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<_Track> tracks = snapshot.data!.docs
                        .map(_Track.fromDoc)
                        .where((t) => t.active)
                        .where((t) {
                          if (_query.isNotEmpty && !'${t.title} ${t.artist}'.toLowerCase().contains(_query)) {
                            return false;
                          }
                          if (_category == 'Senin için') return true;
                          if (_category == 'Kaydedilenler') return t.saved;
                          return t.category.toLowerCase() == _category.toLowerCase();
                        })
                        .toList();

                    if (tracks.isEmpty) {
                      return const _MusicEmpty(
                        icon: Icons.music_note_rounded,
                        title: 'Henüz şarkı yok',
                        subtitle: 'Lisanslı müzik kataloğu eklendiğinde burada listelenecek.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (_, int index) => _TrackTile(
                        track: tracks[index],
                        onTap: () => _chooseClip(tracks[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseClip(_Track track) async {
    final StoryMusicSelection? selected = await showModalBottomSheet<StoryMusicSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ClipSheet(track: track),
    );
    if (!mounted || selected == null) return;
    Navigator.pop(context, selected);
  }
}

class _TrackTile extends StatelessWidget {
  final _Track track;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 52,
          height: 52,
          child: track.artworkUrl.isEmpty
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)],
                    ),
                  ),
                  child: Icon(Icons.music_note_rounded, color: Colors.white),
                )
              : Image.network(
                  track.artworkUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF20242C),
                    child: Icon(Icons.music_note_rounded),
                  ),
                ),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ClipSheet extends StatefulWidget {
  final _Track track;
  const _ClipSheet({required this.track});

  @override
  State<_ClipSheet> createState() => _ClipSheetState();
}

class _ClipSheetState extends State<_ClipSheet> {
  double _startMs = 0;
  String _style = 'minimal';

  @override
  Widget build(BuildContext context) {
    final int maxStart = (widget.track.durationMs - 15000).clamp(0, 86400000).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
          ),
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.track.artworkUrl.isEmpty
                    ? const Icon(Icons.music_note_rounded, color: Colors.white)
                    : Image.network(widget.track.artworkUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(widget.track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
              const Text('15 sn', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8FA6FF))),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Başlangıç noktasını seç', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: const Color(0xFF15181E), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: List<Widget>.generate(
                24,
                (int i) => Expanded(
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 10 + ((i * 7) % 30).toDouble(),
                      decoration: BoxDecoration(
                        color: i.isEven ? const Color(0xFF38E8FF) : const Color(0xFF9B4DFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Slider(
            value: maxStart == 0 ? 0.0 : _startMs.clamp(0.0, maxStart.toDouble()).toDouble(),
            min: 0.0,
            max: maxStart == 0 ? 1.0 : maxStart.toDouble(),
            onChanged: maxStart == 0 ? null : (double value) => setState(() => _startMs = value),
          ),
          Text('${(_startMs / 1000).toStringAsFixed(1)} sn → ${((_startMs + 15000) / 1000).toStringAsFixed(1)} sn', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          const Text('Etiket görünümü', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(label: const Text('Minimal'), selected: _style == 'minimal', onSelected: (_) => setState(() => _style = 'minimal')),
              ChoiceChip(label: const Text('Kapaklı'), selected: _style == 'card', onSelected: (_) => setState(() => _style = 'card')),
              ChoiceChip(label: const Text('Şarkı adı'), selected: _style == 'title', onSelected: (_) => setState(() => _style = 'title')),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                onPressed: () {
                  Navigator.pop(
                    context,
                    StoryMusicSelection(
                      trackId: widget.track.id,
                      title: widget.track.title,
                      artist: widget.track.artist,
                      artworkUrl: widget.track.artworkUrl,
                      previewUrl: widget.track.previewUrl,
                      durationMs: widget.track.durationMs,
                      startMs: _startMs.round(),
                      stickerStyle: _style,
                    ),
                  );
                },
                child: const Text('Müziği ekle', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Track {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String previewUrl;
  final String category;
  final int durationMs;
  final bool active;
  final bool saved;

  const _Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.previewUrl,
    required this.category,
    required this.durationMs,
    required this.active,
    required this.saved,
  });

  factory _Track.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _Track(
      id: doc.id,
      title: (data['title'] ?? 'İsimsiz şarkı').toString(),
      artist: (data['artist'] ?? 'Bilinmeyen sanatçı').toString(),
      artworkUrl: (data['artworkUrl'] ?? '').toString(),
      previewUrl: (data['previewUrl'] ?? '').toString(),
      category: (data['category'] ?? 'Senin için').toString(),
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 15000,
      active: data['active'] != false,
      saved: data['saved'] == true,
    );
  }
}

class _MusicEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MusicEmpty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 54, color: Colors.white38),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
