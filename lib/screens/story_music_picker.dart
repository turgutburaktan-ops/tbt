
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_submission_screen.dart';

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
  final double musicVolume;
  final double originalAudioVolume;
  final int fadeInMs;
  final int fadeOutMs;
  final String mood;

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
    this.musicVolume = .85,
    this.originalAudioVolume = .25,
    this.fadeInMs = 350,
    this.fadeOutMs = 500,
    this.mood = 'Seyahat',
  });
  Map<String, dynamic> storyFields() => {
    'musicTrackId': trackId, 'musicTitle': title, 'musicArtist': artist,
    'musicArtworkUrl': artworkUrl, 'musicPreviewUrl': previewUrl, 'musicAudioUrl': previewUrl,
    'musicStartMs': startMs, 'musicDurationMs': clipDurationMs.clamp(1000, 15000),
    'musicStickerStyle': stickerStyle, 'musicLicense': license, 'musicSourceUrl': sourceUrl,
    'musicVolume': musicVolume, 'originalAudioVolume': originalAudioVolume,
    'musicFadeInMs': fadeInMs, 'musicFadeOutMs': fadeOutMs, 'musicMood': mood, 'musicVersion': 4,
  };
}

class StoryMusicPicker extends StatefulWidget {
  final int maxClipDurationMs;
  const StoryMusicPicker({super.key, this.maxClipDurationMs = 15000});

  @override
  State<StoryMusicPicker> createState() => _StoryMusicPickerState();
}

class _StoryMusicPickerState extends State<StoryMusicPicker> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  final Set<String> _savedIds = <String>{};
  final List<String> _recentIds = <String>[];
  String _previewingId = '';
  String _query = '';
  String _category = 'TBT Trend';

  static const _categories = <String>[
    'TBT Trend', 'Gezi', 'Chill', 'Türkçe', 'Enerjik', 'Romantik',
    'Sinematik', 'Elektronik', 'TBT’de Yükselenler', 'Orijinal Sesler',
    'Kaydedilenler', 'Son kullanılanlar',
  ];

  @override
  void initState() {
    super.initState();
    _loadLibraryState();
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedIds.addAll(prefs.getStringList('story_music_saved') ?? const <String>[]);
      _recentIds.addAll(prefs.getStringList('story_music_recent') ?? const <String>[]);
    });
  }

  Future<void> _toggleSaved(String id) async {
    setState(() => _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('story_music_saved', _savedIds.toList());
  }

  Future<void> _remember(String id) async {
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 30) _recentIds.removeRange(30, _recentIds.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('story_music_recent', _recentIds);
  }

  Future<void> _togglePreview(_Track track) async {
    if (_previewingId == track.id) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewingId = '');
      return;
    }
    try {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewingId = track.id);
      await _previewPlayer.setUrl(track.previewUrl);
      await _previewPlayer.setClip(
        start: Duration.zero,
        end: Duration(milliseconds: track.durationMs.clamp(1000, 15000)),
      );
      await _previewPlayer.play();
      if (mounted) setState(() => _previewingId = '');
    } catch (_) {
      if (mounted) {
        setState(() => _previewingId = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu müzik şu anda önizlenemiyor.')),
        );
      }
    }
  }

  List<_Track> _filtered(List<_Track> tracks) {
    final result = tracks.where((t) {
      if (!t.active) return false;
      if (_query.isNotEmpty && !'${t.title} ${t.artist}'.toLowerCase().contains(_query)) return false;
      if (_category == 'TBT Trend') return true;
      if (_category == 'TBT’de Yükselenler') return t.usageCount > 0;
      if (_category == 'Kaydedilenler') return _savedIds.contains(t.id);
      if (_category == 'Son kullanılanlar') return _recentIds.contains(t.id);
      return t.category == _category || t.mood == _category ||
          (_category == 'Gezi' && t.mood == 'Seyahat') ||
          (_category == 'Chill' && t.mood == 'Sakin');
    }).toList();
    result.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return result;
  }

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
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MusicSubmissionScreen()),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Müziğini gönder'),
                ),
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
                    selectedColor: const Color(0xFF285F8C),
                    backgroundColor: const Color(0xFF15181E),
                    side: BorderSide.none,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('music_tracks').where('active', isEqualTo: true).limit(300).snapshots(),
                  builder: (_, snapshot) {
                    if (snapshot.hasError) return const _MusicEmpty(title: 'Müzikler yüklenemedi', subtitle: 'Bağlantını kontrol edip tekrar aç.');
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final tracks = _filtered(snapshot.data!.docs.map(_Track.fromDoc).toList());
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
                      itemBuilder: (_, i) {
                        final track = tracks[i];
                        return _TrackTile(
                          track: track,
                          saved: _savedIds.contains(track.id),
                          playing: _previewingId == track.id,
                          onFavorite: () => _toggleSaved(track.id),
                          onPreview: () => _togglePreview(track),
                          onTap: () => _chooseClip(track),
                        );
                      },
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
    await _previewPlayer.stop();
    if (mounted) setState(() => _previewingId = '');
    await _remember(track.id);
    final selected = await showModalBottomSheet<StoryMusicSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0D12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * .85, child: SingleChildScrollView(child: _ClipSheet(track: track, maxClipDurationMs: widget.maxClipDurationMs))),
    );
    if (!mounted || selected == null) return;
    Navigator.pop(context, selected);
  }
}

class _TrackTile extends StatelessWidget {
  final _Track track;
  final bool saved, playing;
  final VoidCallback onTap, onFavorite, onPreview;
  const _TrackTile({
    required this.track,
    required this.saved,
    required this.playing,
    required this.onTap,
    required this.onFavorite,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    leading: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF285F8C)]),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    ),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text('${track.artist}  •  ${track.license}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      IconButton(
        tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
        onPressed: onFavorite,
        icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
      ),
      IconButton(
        tooltip: playing ? 'Durdur' : 'Dinle',
        onPressed: onPreview,
        icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded),
      ),
    ]),
  );
}

class _ClipSheet extends StatefulWidget {
  final _Track track;
  final int maxClipDurationMs;
  const _ClipSheet({required this.track, required this.maxClipDurationMs});
  @override
  State<_ClipSheet> createState() => _ClipSheetState();
}

class _ClipSheetState extends State<_ClipSheet> {
  final AudioPlayer _player = AudioPlayer();
  double _startMs = 0;
  int _clipMs = 15000;

  @override
  void initState() {
    super.initState();
    _clipMs = widget.track.durationMs.clamp(1000, widget.maxClipDurationMs.clamp(1000, 15000)).toInt();
  }
  String _style = 'minimal';
  bool _loading = false;
  bool _playing = false;
  double _musicVolume = .85;
  double _originalVolume = .25;
  double _fadeInMs = 350;
  double _fadeOutMs = 500;

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
      await _player.setClip(start: Duration(milliseconds: _startMs.round()), end: Duration(milliseconds: _startMs.round() + _clipMs));
      await _player.setVolume(_musicVolume);
      if (!mounted) return;
      setState(() { _loading = false; _playing = true; });
      await _player.play();
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
    final maxStart = (widget.track.durationMs - _clipMs).clamp(0, 86400000).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
        const SizedBox(height: 18),
        Row(children: <Widget>[
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF285F8C)])),
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
        Text('${(_clipMs / 1000).toStringAsFixed(0)} saniyelik bölümü seç', style: const TextStyle(fontWeight: FontWeight.w800)),
        if (widget.maxClipDurationMs > 15000) Wrap(spacing: 8, children: [
          for (final ms in <int>{widget.track.durationMs.clamp(1000, 15000).toInt(), 30000, 60000})
            if (ms <= widget.track.durationMs && ms <= widget.maxClipDurationMs)
              ChoiceChip(label: Text('${ms ~/ 1000} sn'), selected: _clipMs == ms, onSelected: (_) {
                _player.stop();
                setState(() { _clipMs = ms; _startMs = 0; _playing = false; });
              }),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: const Color(0xFF15181E), borderRadius: BorderRadius.circular(18)),
          child: Row(children: List<Widget>.generate(24, (i) => Expanded(child: Center(child: Container(width: 3, height: 10 + ((i * 7) % 30).toDouble(), decoration: BoxDecoration(color: i.isEven ? const Color(0xFF38E8FF) : const Color(0xFF285F8C), borderRadius: BorderRadius.circular(4))))))),
        ),
        Slider(
          value: maxStart == 0 ? 0 : _startMs.clamp(0, maxStart.toDouble()).toDouble(),
          min: 0,
          max: maxStart == 0 ? 1 : maxStart.toDouble(),
          onChanged: maxStart == 0 ? null : (v) async { if (_playing) { await _player.stop(); _playing = false; } setState(() => _startMs = v); },
        ),
        Text('${(_startMs / 1000).toStringAsFixed(1)} sn → ${((_startMs + _clipMs) / 1000).toStringAsFixed(1)} sn', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        _MixSlider(
          icon: Icons.music_note_rounded,
          label: 'Müzik sesi',
          value: _musicVolume,
          onChanged: (v) async {
            setState(() => _musicVolume = v);
            await _player.setVolume(v);
          },
        ),
        _MixSlider(
          icon: Icons.movie_outlined,
          label: 'Videonun sesi',
          value: _originalVolume,
          onChanged: (v) => setState(() => _originalVolume = v),
        ),
        if (widget.maxClipDurationMs <= 15000) Row(children: <Widget>[
          Expanded(child: _FadeChoice(
            label: 'Giriş',
            value: _fadeInMs,
            onChanged: (v) => setState(() => _fadeInMs = v),
          )),
          const SizedBox(width: 10),
          Expanded(child: _FadeChoice(
            label: 'Çıkış',
            value: _fadeOutMs,
            onChanged: (v) => setState(() => _fadeOutMs = v),
          )),
        ]),
        const SizedBox(height: 14),
        if (widget.maxClipDurationMs <= 15000) Wrap(spacing: 8, children: <Widget>[
          ChoiceChip(label: const Text('Minimal'), selected: _style == 'minimal', onSelected: (_) => setState(() => _style = 'minimal')),
          ChoiceChip(label: const Text('Kapaklı'), selected: _style == 'card', onSelected: (_) => setState(() => _style = 'card')),
          ChoiceChip(label: const Text('Şarkı adı'), selected: _style == 'title', onSelected: (_) => setState(() => _style = 'title')),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF285F8C)]), borderRadius: BorderRadius.circular(18)),
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
                clipDurationMs: _clipMs,
                stickerStyle: _style,
                license: widget.track.license,
                sourceUrl: widget.track.sourceUrl,
                musicVolume: _musicVolume,
                originalAudioVolume: _originalVolume,
                fadeInMs: _fadeInMs.round(),
                fadeOutMs: _fadeOutMs.round(),
                mood: widget.track.mood,
              )),
              child: const Text('Müziği ekle', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MixSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _MixSlider({required this.icon, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
    Icon(icon, size: 20, color: Colors.white60),
    const SizedBox(width: 8),
    SizedBox(width: 105, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
    Expanded(child: Slider(value: value, onChanged: onChanged)),
    SizedBox(width: 38, child: Text('%${(value * 100).round()}', textAlign: TextAlign.right)),
  ]);
}

class _FadeChoice extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _FadeChoice({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Text('$label yumuşatma', style: const TextStyle(fontSize: 12, color: Colors.white60)),
    Slider(value: value, min: 0, max: 1500, divisions: 6, onChanged: onChanged),
  ]);
}

class _Track {
  final String id, title, artist, artworkUrl, previewUrl, category, license, sourceUrl, mood;
  final int durationMs;
  final bool active;
  final int usageCount;
  const _Track({required this.id, required this.title, required this.artist, required this.artworkUrl, required this.previewUrl, required this.category, required this.durationMs, required this.license, required this.sourceUrl, this.mood = 'Seyahat', this.active = true, this.usageCount = 0});

  factory _Track.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final audioUrl = (d['audioUrl'] ?? d['previewUrl'] ?? '').toString().trim();
    final rightsVerified = d['commercialUseAllowed'] == true &&
        d['derivativesAllowed'] == true &&
        d['catalogDistributionAllowed'] == true;
    return _Track(
      id: doc.id,
      title: (d['title'] ?? 'İsimsiz şarkı').toString(),
      artist: (d['artist'] ?? 'Bilinmeyen sanatçı').toString(),
      artworkUrl: (d['artworkUrl'] ?? '').toString(),
      previewUrl: audioUrl,
      category: (d['category'] ?? 'Yabancı').toString(),
      durationMs: (d['durationMs'] as num?)?.toInt() ?? 15000,
      license: (d['license'] ?? '').toString(),
      sourceUrl: (d['sourceUrl'] ?? '').toString(),
      mood: (d['mood'] ?? 'Gezi').toString(),
      active: d['active'] == true && audioUrl.isNotEmpty && rightsVerified && (d['audioStoragePath'] ?? '').toString().startsWith('music/'),
      usageCount: (d['usageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

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
