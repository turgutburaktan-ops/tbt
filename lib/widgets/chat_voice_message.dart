import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatVoiceRecordButton extends StatefulWidget {
  final bool disabled;
  final Future<void> Function(Uint8List bytes, int durationMs) onRecorded;
  final ValueChanged<Object>? onError;

  const ChatVoiceRecordButton({
    super.key,
    required this.onRecorded,
    this.disabled = false,
    this.onError,
  });

  @override
  State<ChatVoiceRecordButton> createState() => _ChatVoiceRecordButtonState();
}

class _ChatVoiceRecordButtonState extends State<ChatVoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _finishing = false;
  bool _startedByLongPress = false;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  String _durationLabel(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _report(Object error) {
    widget.onError?.call(error is TimeoutException
        ? Exception('Ses kaydı zaman aşımına uğradı. Tekrar dene.')
        : error);
  }

  Future<void> _start({bool fromLongPress = false}) async {
    if (widget.disabled || _recording || _finishing) return;
    try {
      final allowed = await _recorder
          .hasPermission()
          .timeout(const Duration(seconds: 5));
      if (!allowed) {
        throw Exception('Sesli mesaj için mikrofon izni vermelisin.');
      }
      final temp = await getTemporaryDirectory()
          .timeout(const Duration(seconds: 4));
      final path =
          '${temp.path}/tbt_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder
          .start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 96000,
              sampleRate: 44100,
            ),
            path: path,
          )
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _recording = true;
        _startedByLongPress = fromLongPress;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } catch (e) {
      _report(e);
    }
  }

  Future<void> _stopAndSend() async {
    if (!_recording || _finishing) return;
    setState(() => _finishing = true);
    _ticker?.cancel();
    final duration = _startedAt == null
        ? _elapsed
        : DateTime.now().difference(_startedAt!);
    String? path;
    try {
      path = await _recorder.stop().timeout(const Duration(seconds: 6));
      if (mounted) {
        setState(() {
          _recording = false;
          _startedByLongPress = false;
          _startedAt = null;
        });
      }
      if (path == null || path.isEmpty) {
        throw Exception('Ses kaydı oluşturulamadı.');
      }
      final file = File(path);
      final bytes = await file.readAsBytes().timeout(const Duration(seconds: 8));
      if (duration.inMilliseconds < 450 || bytes.isEmpty) {
        throw Exception('Ses kaydı çok kısa. En az yarım saniye kaydet.');
      }
      await widget.onRecorded(bytes, duration.inMilliseconds);
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e) {
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      _report(e);
    } finally {
      if (mounted) {
        setState(() {
          _finishing = false;
          _elapsed = Duration.zero;
          _startedByLongPress = false;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_recording || _finishing) return;
    _ticker?.cancel();
    try {
      await _recorder.cancel().timeout(const Duration(seconds: 5));
    } catch (e) {
      _report(e);
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _startedByLongPress = false;
          _startedAt = null;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) {
      Future.microtask(() async {
        try {
          await _recorder.cancel();
        } catch (_) {}
      });
    }
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        constraints: const BoxConstraints(minWidth: 154),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF171D24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3A4654)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Kaydı iptal et',
              visualDensity: VisualDensity.compact,
              onPressed: _finishing ? null : _cancelRecording,
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
            ),
            const SizedBox(width: 1),
            const Icon(
              Icons.fiber_manual_record_rounded,
              color: Color(0xFFFF5D72),
              size: 12,
            ),
            const SizedBox(width: 5),
            Text(
              _durationLabel(_elapsed),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: 'Sesli mesajı gönder',
              onPressed: _finishing ? null : _stopAndSend,
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Color(0xFF8CD9FF)),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Sesli mesaj kaydet',
      hint: 'Dokunarak başlat veya basılı tutup bırakınca gönder',
      child: GestureDetector(
        onLongPressStart: widget.disabled || _finishing
            ? null
            : (_) => _start(fromLongPress: true),
        onLongPressEnd: widget.disabled || _finishing
            ? null
            : (_) {
                if (_startedByLongPress) _stopAndSend();
              },
        child: IconButton.filled(
          tooltip: 'Sesli mesaj',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF202731),
            foregroundColor: const Color(0xFF8CD9FF),
          ),
          onPressed: widget.disabled || _finishing
              ? null
              : () => _start(fromLongPress: false),
          icon: _finishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mic_none_rounded),
        ),
      ),
    );
  }
}

class ChatAudioBubble extends StatefulWidget {
  final String url;
  final int? durationMs;
  final bool mine;

  const ChatAudioBubble({
    super.key,
    required this.url,
    this.durationMs,
    required this.mine,
  });

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;

  String _label(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (!_loaded) {
        setState(() => _loading = true);
        await _player.setUrl(widget.url).timeout(const Duration(seconds: 10));
        _loaded = true;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesli mesaj oynatılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackDuration = Duration(milliseconds: widget.durationMs ?? 0);
    final fg = widget.mine ? const Color(0xFF0A1118) : Colors.white;
    final secondary = widget.mine ? Colors.black45 : Colors.white54;
    return SizedBox(
      width: 225,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (_, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                onPressed: _loading ? null : _toggle,
                style: IconButton.styleFrom(
                  backgroundColor: widget.mine
                      ? Colors.black12
                      : Colors.white10,
                  foregroundColor: fg,
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      ),
              );
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (_, durationSnapshot) {
                final total = durationSnapshot.data ?? fallbackDuration;
                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  initialData: Duration.zero,
                  builder: (_, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final totalMs = total.inMilliseconds > 0
                        ? total.inMilliseconds
                        : 1;
                    final value = position.inMilliseconds
                        .clamp(0, totalMs)
                        .toDouble();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4.5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 9,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: totalMs.toDouble(),
                            value: value,
                            activeColor: fg,
                            inactiveColor: secondary,
                            onChanged: _loaded
                                ? (next) => _player.seek(
                                    Duration(milliseconds: next.round()),
                                  )
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 7, right: 7),
                          child: Text(
                            '${_label(position)} / ${_label(total)}',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
