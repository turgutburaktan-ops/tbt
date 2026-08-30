import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
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
}
}

class StoryMusicPicker extends StatefulWidget {
  const StoryMusicPicker({super.key});

  @override
  State<StoryMusicPicker> createState() => _StoryMusicPickerState();
}

class _StoryMusicPickerState extends State<StoryMusicPicker> {
  late final Future<List<_Track>> _commonsTracks;
  final AudioPlayer _previewPlayer = AudioPlayer();
  final Set<String> _savedIds = <String>{};
  final List<String> _recentIds = <String>[];
  String _previewingId = '';
  String _query = '';
  String _category = 'Senin için';

  static const _categories = <String>[
    'Senin için', 'Trend', 'Yeni', 'Türkçe', 'Yabancı',
    'Seyahat', 'Doğa', 'Enerjik', 'Sakin', 'Sinematik',
    'Kaydedilenler', 'Son kullanılanlar',
  ];

  @override
  void initState() {
    super.initState();
    _commonsTracks = _fetchCommonsTracks();
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

  List<_Track> _filtered(List<_Track> tracks) => tracks.where((t) {
    if (!t.active) return false;
    if (_query.isNotEmpty && !'${t.title} ${t.artist}'.toLowerCase().contains(_query)) return false;
    if (_category == 'Senin için') return true;
    if (_category == 'Trend') return t.trending;
    if (_category == 'Kaydedilenler') return _savedIds.contains(t.id);
    if (_category == 'Son kullanılanlar') return _recentIds.contains(t.id);
    if (_category == 'Yeni') return !t.trending;
    if (const <String>{'Seyahat', 'Doğa', 'Enerjik', 'Sakin', 'Sinematik'}.contains(_category)) {
      return t.mood == _category;
    }
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
                    selectedColor: const Color(0xFF6947F5),
                    backgroundColor: const Color(0xFF15181E),
                    side: BorderSide.none,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<_Track>>(
                future: _commonsTracks,
                builder: (_, commonsSnapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('music_tracks').limit(160).snapshots(),
                  builder: (_, snapshot) {
                    final remote = snapshot.hasData ? snapshot.data!.docs.map(_Track.fromDoc).toList() : <_Track>[];
                    final commons = commonsSnapshot.data ?? const <_Track>[];
                    final merged = <String, _Track>{
                      for (final t in _cc0Tracks) t.id: t,
                      for (final t in commons) t.id: t,
                      for (final t in remote) t.id: t,
                    }.values.toList();
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
      builder: (_) => _ClipSheet(track: track),
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
        gradient: const LinearGradient(colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)]),
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
      await _player.seek(Duration(milliseconds: _startMs.round()));
      await _player.setVolume(_musicVolume);
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
        Row(children: <Widget>[
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
  final bool active, saved, trending;
  const _Track({required this.id, required this.title, required this.artist, required this.artworkUrl, required this.previewUrl, required this.category, required this.durationMs, required this.license, required this.sourceUrl, this.mood = 'Seyahat', this.active = true, this.saved = false, this.trending = false});

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
      mood: (d['mood'] ?? _inferMood((d['title'] ?? '').toString())).toString(),
      active: d['active'] != false && audioUrl.isNotEmpty && rightsVerified,
      saved: d['saved'] == true,
      trending: d['trending'] == true,
    );
  }
}

Future<List<_Track>> _fetchCommonsTracks() async {
  final groups = await Future.wait(<Future<List<_Track>>>[
    _fetchCommonsCategory(
      search: 'filetype:audio deepcat:"Audio files of music" incategory:"CC-Zero"',
      category: 'Yabancı',
      limit: 100,
    ),
    _fetchCommonsCategory(
      search: 'filetype:audio deepcat:"Turkish-language music" incategory:"CC-Zero"',
      category: 'Türkçe',
      limit: 50,
    ),
  ]);
  return <String, _Track>{
    for (final track in groups.expand((items) => items)) track.id: track,
  }.values.toList();
}

Future<List<_Track>> _fetchCommonsCategory({
  required String search,
  required String category,
  required int limit,
}) async {
  try {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
      'generator': 'search',
      'gsrsearch': search,
      'gsrnamespace': '6',
      'gsrlimit': limit.toString(),
      'prop': 'videoinfo',
      'viprop': 'url|duration|mime|derivatives|extmetadata',
    });
    final response = await http.get(
      uri,
      headers: const <String, String>{'User-Agent': 'TBT-Mobile/1.0 (story music catalog)'},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const <_Track>[];
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = ((root['query'] as Map?)?['pages'] as List?) ?? const <dynamic>[];
    final tracks = <_Track>[];
    for (final rawPage in pages) {
      if (rawPage is! Map) continue;
      final page = Map<String, dynamic>.from(rawPage);
      final infoList = page['videoinfo'] as List?;
      if (infoList == null || infoList.isEmpty || infoList.first is! Map) continue;
      final info = Map<String, dynamic>.from(infoList.first as Map);
      final ext = info['extmetadata'] is Map
          ? Map<String, dynamic>.from(info['extmetadata'] as Map)
          : const <String, dynamic>{};
      final license = _metaValue(ext['LicenseShortName']);
      if (!license.toUpperCase().replaceAll(' ', '').contains('CC0')) continue;
      final derivatives = (info['derivatives'] as List?) ?? const <dynamic>[];
      String audioUrl = '';
      for (final rawDerivative in derivatives) {
        if (rawDerivative is! Map) continue;
        final derivative = Map<String, dynamic>.from(rawDerivative);
        final type = (derivative['type'] ?? '').toString().toLowerCase();
        final key = (derivative['transcodekey'] ?? '').toString().toLowerCase();
        if (type == 'audio/mpeg' || key.contains('mp3')) {
          audioUrl = (derivative['src'] ?? '').toString();
          if (audioUrl.isNotEmpty) break;
        }
      }
      if (audioUrl.isEmpty && (info['mime'] ?? '').toString() == 'audio/mpeg') {
        audioUrl = (info['url'] ?? '').toString();
      }
      if (audioUrl.isEmpty) continue;
      final rawTitle = (page['title'] ?? 'İsimsiz parça').toString();
      final title = rawTitle
          .replaceFirst(RegExp(r'^File:'), '')
          .replaceFirst(
            RegExp(r'\.(ogg|oga|mp3|wav|flac|webm)$', caseSensitive: false),
            '',
          )
          .replaceAll('_', ' ');
      final artist = _plainText(_metaValue(ext['Artist']));
      final pageUrl =
          'https://commons.wikimedia.org/wiki/${Uri.encodeComponent(rawTitle.replaceAll(' ', '_'))}';
      tracks.add(_Track(
        id: 'commons_${page['pageid']}',
        title: title,
        artist: artist.isEmpty ? 'Wikimedia Commons' : artist,
        artworkUrl: '',
        previewUrl: audioUrl,
        category: category,
        durationMs: (((info['duration'] as num?)?.toDouble() ?? 15) * 1000).round(),
        license: 'CC0 1.0',
        sourceUrl: pageUrl,
        mood: _inferMood(title),
      ));
    }
    return tracks;
  } catch (_) {
    return const <_Track>[];
  }
}

String _inferMood(String title) {
  final value = title.toLowerCase();
  if (RegExp(r'nature|forest|river|rain|wind|garden|sea|ocean|doğa|orman|nehir|yağmur').hasMatch(value)) return 'Doğa';
  if (RegExp(r'action|dance|battle|run|beat|party|enerji|dans').hasMatch(value)) return 'Enerjik';
  if (RegExp(r'sad|calm|sleep|piano|quiet|ambient|sakin|hüzün').hasMatch(value)) return 'Sakin';
  if (RegExp(r'cinema|film|epic|theme|dram|score|sinem').hasMatch(value)) return 'Sinematik';
  return 'Seyahat';
}

String _metaValue(dynamic value) {
  if (value is Map) return (value['value'] ?? '').toString();
  return value?.toString() ?? '';
}

String _plainText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();

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
