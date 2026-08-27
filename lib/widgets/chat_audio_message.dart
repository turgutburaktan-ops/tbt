import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ChatAudioMessage extends StatefulWidget {
  final String url;
  final bool mine;
  final int? durationMs;

  const ChatAudioMessage({
    super.key,
    required this.url,
    required this.mine,
    this.durationMs,
  });

  @override
  State<ChatAudioMessage> createState() => _ChatAudioMessageState();
}

class _ChatAudioMessageState extends State<ChatAudioMessage> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;
  String? _error;

  Duration get _fallbackDuration =>
      Duration(milliseconds: widget.durationMs ?? 0);

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (_player.duration == null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        await _player.setUrl(widget.url);
      }
      if (mounted) setState(() => _loading = false);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ses açılamadı';
      });
    }
  }

  String _label(Duration value) {
    final seconds = value.inSeconds.clamp(0, 3599);
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.mine ? Colors.black87 : Colors.white;
    final muted = widget.mine ? Colors.black45 : Colors.white54;
    return SizedBox(
      width: 238,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing == true;
              return IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: widget.mine
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.08),
                  foregroundColor: foreground,
                ),
                onPressed: _toggle,
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              );
            },
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? _fallbackDuration;
                    return StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds <= 0
                            ? 1.0
                            : duration.inMilliseconds.toDouble();
                        final value = position.inMilliseconds
                            .clamp(0, maxMs.toInt())
                            .toDouble();
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: foreground,
                                inactiveTrackColor: muted.withValues(
                                  alpha: 0.35,
                                ),
                                thumbColor: foreground,
                              ),
                              child: Slider(
                                min: 0,
                                max: maxMs,
                                value: value,
                                onChanged: duration.inMilliseconds <= 0
                                    ? null
                                    : (next) => _player.seek(
                                        Duration(milliseconds: next.round()),
                                      ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _label(position),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: muted,
                                  ),
                                ),
                                Text(
                                  _label(duration),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(fontSize: 10.5, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
