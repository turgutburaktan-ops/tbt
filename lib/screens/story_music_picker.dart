import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  final String license;
  final String sourceUrl;

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
    this.license = '',
    this.sourceUrl = '',
  });
}

class StoryMusicPicker extends StatefulWidget {
  const StoryMusicPicker({super.key});

  @override
  State<StoryMusicPicker> createState() => _StoryMusicPickerState();
}

class _StoryMusicPickerState extends State<StoryMusicPicker> {
  String _query = '';
  String _category = 'Senin için';

  static const _categories = <String>['Senin için', 'Trend', 'Türkçe', 'Yabancı', 'Kaydedilenler'];

  List<_Track> _filtered(List<_Track> tracks) => tracks.where((t) {
    if (!t.active) return false;
    if (_query.isNotEmpty && !'${t.title} ${t.artist}'.toLowerCase().contains(_query)) return false;
    if (_category == 'Senin için') return true;
    if (_category == 'Trend') return t.trending;
    if (_category == 'Kaydedilenler') return t.saved;
    return t.category.toLowerCase() == _category.toLowerCase();
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF090B0F),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(children: <Widget>[
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(children: <Widget>[
                const Expanded(child: Text('Müzik ekle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Şarkı veya sanatçı ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFF15181E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
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
                itemBuilder: (_, i) {
                  final item = _categories[i];
                  return ChoiceChip(
                    selected: item == _category,
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
                builder: (_, snapshot) {
                  final remote = snapshot.hasData ? snapshot.data!.docs.map(_Track.fromDoc).toList() : <_Track>[];
                  final merged = <String, _Track>{for (final t in _cc0Tracks) t.id: t, for (final t in remote) t.id: t}.values.toList();
                  final tracks = _filtered(merged);
                  if (tracks.isEmpty) {
                    return const _MusicEmpty(
                      title: 'Bu kategoride henüz müzik yok',
                      subtitle: 'Yalnızca lisansı doğrulanmış parçaları gösteriyoruz.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (_, i) => _TrackTile(track: tracks[i], onTap: () => _chooseClip(tracks[i])),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _chooseClip(_Track track) async {
    final selected = await showModalBottomSheet<StoryMusicSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0D12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    leading: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)]),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    ),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text('${track.artist}  •  ${track.license}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
    trailing: const Icon(Icons.play_circle_outline_rounded),
  );
}

class _ClipSheet extends StatefulWidget {
  final _Track track;
  const _ClipSheet({required this.track});
  @override
  State<_ClipSheet> createState() => _ClipSheetState();
}

class _ClipSheetState extends State<_ClipSheet> {
  final AudioPlayer _player = AudioPlayer();
  double _startMs = 0;
  String _style = 'minimal';
  bool _loading = false;
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      await _player.setUrl(widget.track.previewUrl);
      await _player.seek(Duration(milliseconds: _startMs.round()));
      if (!mounted) return;
      setState(() { _loading = false; _playing = true; });
      await _player.play();
      await Future<void>.delayed(const Duration(seconds: 15));
      await _player.stop();
      if (mounted) setState(() => _playing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _playing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müzik önizlemesi açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxStart = (widget.track.durationMs - 15000).clamp(0, 86400000).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 18),
        Row(children: <Widget>[
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)])),
            child: const Icon(Icons.music_note_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(widget.track.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(widget.track.artist, style: const TextStyle(color: Colors.white60)),
            Text(widget.track.license, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA6FF))),
          ])),
          IconButton.filledTonal(onPressed: _loading ? null : _preview, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded)),
        ]),
        const SizedBox(height: 18),
        const Text('15 saniyelik bölümü seç', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: const Color(0xFF15181E), borderRadius: BorderRadius.circular(18)),
          child: Row(children: List<Widget>.generate(24, (i) => Expanded(child: Center(child: Container(width: 3, height: 10 + ((i * 7) % 30).toDouble(), decoration: BoxDecoration(color: i.isEven ? const Color(0xFF38E8FF) : const Color(0xFF9B4DFF), borderRadius: BorderRadius.circular(4))))))),
        ),
        Slider(
          value: maxStart == 0 ? 0 : _startMs.clamp(0, maxStart.toDouble()).toDouble(),
          min: 0,
          max: maxStart == 0 ? 1 : maxStart.toDouble(),
          onChanged: maxStart == 0 ? null : (v) async { if (_playing) { await _player.stop(); _playing = false; } setState(() => _startMs = v); },
        ),
        Text('${(_startMs / 1000).toStringAsFixed(1)} sn → ${((_startMs + 15000) / 1000).toStringAsFixed(1)} sn', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: <Widget>[
          ChoiceChip(label: const Text('Minimal'), selected: _style == 'minimal', onSelected: (_) => setState(() => _style = 'minimal')),
          ChoiceChip(label: const Text('Kapaklı'), selected: _style == 'card', onSelected: (_) => setState(() => _style = 'card')),
          ChoiceChip(label: const Text('Şarkı adı'), selected: _style == 'title', onSelected: (_) => setState(() => _style = 'title')),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)]), borderRadius: BorderRadius.circular(18)),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              onPressed: () => Navigator.pop(context, StoryMusicSelection(
                trackId: widget.track.id,
                title: widget.track.title,
                artist: widget.track.artist,
                artworkUrl: widget.track.artworkUrl,
                previewUrl: widget.track.previewUrl,
                durationMs: widget.track.durationMs,
                startMs: _startMs.round(),
                stickerStyle: _style,
                license: widget.track.license,
                sourceUrl: widget.track.sourceUrl,
              )),
              child: const Text('Müziği ekle', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Track {
  final String id, title, artist, artworkUrl, previewUrl, category, license, sourceUrl;
  final int durationMs;
  final bool active, saved, trending;
  const _Track({required this.id, required this.title, required this.artist, required this.artworkUrl, required this.previewUrl, required this.category, required this.durationMs, required this.license, required this.sourceUrl, this.active = true, this.saved = false, this.trending = false});

  factory _Track.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _Track(
      id: doc.id,
      title: (d['title'] ?? 'İsimsiz şarkı').toString(),
      artist: (d['artist'] ?? 'Bilinmeyen sanatçı').toString(),
      artworkUrl: (d['artworkUrl'] ?? '').toString(),
      previewUrl: (d['previewUrl'] ?? '').toString(),
      category: (d['category'] ?? 'Yabancı').toString(),
      durationMs: (d['durationMs'] as num?)?.toInt() ?? 15000,
      license: (d['license'] ?? '').toString(),
      sourceUrl: (d['sourceUrl'] ?? '').toString(),
      active: d['active'] != false,
      saved: d['saved'] == true,
      trending: d['trending'] == true,
    );
  }
}

const List<_Track> _cc0Tracks = <_Track>[
  _Track(id: 'cc0_komiku_wind', title: 'The Wind', artist: 'Komiku', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Komiku/Tale_on_the_Late/Komiku_-_13_-_The_Wind.mp3', category: 'Yabancı', durationMs: 114000, license: 'CC0 1.0', sourceUrl: 'https://freemusicarchive.org/music/Komiku/Tale_on_the_Late/Komiku_-_Tale_on_the_Late_-_13_The_Wind/', trending: true),
  _Track(id: 'cc0_komiku_remember', title: 'Remember the time we use to play', artist: 'Komiku', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Komiku/Tale_on_the_Late/Komiku_-_02_-_Remember_the_time_we_use_to_play.mp3', category: 'Yabancı', durationMs: 96000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Komiku_-_02_-_Remember_the_time_we_use_to_play.ogg', trending: true),
  _Track(id: 'cc0_monplaisir_free3', title: 'Free To Use 3', artist: 'Monplaisir', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Monplaisir/Free_To_Use/Monplaisir_-_03_-_Free_To_Use_3.mp3', category: 'Yabancı', durationMs: 187000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monplaisir_-_03_-_Free_To_Use_3.ogg'),
  _Track(id: 'cc0_monplaisir_free12', title: 'Free To Use 12', artist: 'Monplaisir', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Monplaisir/Free_To_Use/Monplaisir_-_12_-_Free_To_Use_12.mp3', category: 'Yabancı', durationMs: 114000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monplaisir_-_12_-_Free_To_Use_12.ogg'),
  _Track(id: 'cc0_monplaisir_close', title: 'Close to you', artist: 'Monplaisir', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Monplaisir/Fifty_seconds_of_rain/Monplaisir_-_02_-_Close_to_you.mp3', category: 'Yabancı', durationMs: 137000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monplaisir_-_02_-_Close_to_you.ogg'),
  _Track(id: 'cc0_monplaisir_noneed', title: 'No need to', artist: 'Monplaisir', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/Music_for_Video/Monplaisir/Fifty_seconds_of_rain/Monplaisir_-_01_-_No_need_to.mp3', category: 'Yabancı', durationMs: 122000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monplaisir_-_01_-_No_need_to.ogg'),
  _Track(id: 'cc0_monplaisir_action', title: 'Action', artist: 'Monplaisir', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/WFMU/Monplaisir/American_Dreams_Soundtrack/Monplaisir_-_18_-_Action.mp3', category: 'Yabancı', durationMs: 190000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monplaisir_-_18_-_Action.ogg', trending: true),
  _Track(id: 'cc0_bartmann_bouncy', title: 'Bouncy Gypsy Beats', artist: 'John Bartmann', artworkUrl: '', previewUrl: 'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/John_Bartmann/Public_Domain_Soundtrack_Music_Album_One/John_Bartmann_-_03_-_Bouncy_Gypsy_Beats.mp3', category: 'Yabancı', durationMs: 260000, license: 'CC0 1.0', sourceUrl: 'https://commons.wikimedia.org/wiki/File:John_Bartmann_-_03_-_Bouncy_Gypsy_Beats.ogg'),
];

class _MusicEmpty extends StatelessWidget {
  final String title, subtitle;
  const _MusicEmpty({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
    const Icon(Icons.library_music_outlined, size: 54, color: Colors.white38),
    const SizedBox(height: 12),
    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
  ])));
}
