import '../services/video_audio_session.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A single owner prevents off-screen previews and pushed routes playing together.
class _PlaybackOwner {
  static final players = <_AppVideoPlayerState>{};
  static final positions = <String, Duration>{};
  static Timer? timer;
  static void register(_AppVideoPlayerState p) {
    players.add(p);
    timer ??= Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => update(),
    );
  }

  static void unregister(_AppVideoPlayerState p) {
    players.remove(p);
    if (players.isEmpty) {
      timer?.cancel();
      timer = null;
    }
    while (positions.length > 100) {
      positions.remove(positions.keys.first);
    }
  }

  static void update() {
    _AppVideoPlayerState? winner;
    for (final p in players) {
      p._syncResources();
      if (p._eligible && (winner == null || p._visible > winner._visible))
        winner = p;
    }
    for (final p in players) {
      if (!identical(p, winner)) p._applyPlayback(false);
    }
    winner?._applyPlayback(true);
  }
}

class AppVideoPlayer extends StatefulWidget {
  final String? url;
  final File? file;
  final bool autoplay, muted, loop, showControls, active;
  final double volume;
  final VideoAudioSession? audioSession;
  final bool holdToSpeed, showMuteControl;
  final BoxFit fit;
  final Widget? loading, errorWidget;
  final VoidCallback? onTap;
  final Duration start;
  final Duration? end;
  final bool resumePosition;
  final ValueChanged<Duration>? onReady;
  final VoidCallback? onError;
  final ValueChanged<VideoPlayerValue>? onPlayback;
  const AppVideoPlayer.network({
    super.key,
    required String this.url,
    this.autoplay = false,
    this.muted = true,
    this.volume = 1,
    this.audioSession,
    this.holdToSpeed = false,
    this.showMuteControl = true,
    this.loop = true,
    this.showControls = true,
    this.active = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
    this.onTap,
    this.start = Duration.zero,
    this.end,
    this.resumePosition = true,
    this.onReady,
    this.onError,
    this.onPlayback,
  }) : file = null;
  const AppVideoPlayer.file({
    super.key,
    required File this.file,
    this.autoplay = false,
    this.muted = true,
    this.volume = 1,
    this.audioSession,
    this.holdToSpeed = false,
    this.showMuteControl = true,
    this.loop = true,
    this.showControls = true,
    this.active = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
    this.onTap,
    this.start = Duration.zero,
    this.end,
    this.resumePosition = true,
    this.onReady,
    this.onError,
    this.onPlayback,
  }) : url = null;
  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void> _disposals = Future<void>.value();
  Future<void> _commands = Future<void>.value();
  Timer? _releaseTimer;
  Duration? _resumeAt;
  double _visible = 0;
  bool _ready = false, _failed = false, _initializing = false, _foreground = true;
  bool _muted = true, _wantsPlay = false, _playing = false, _speeding = false;
  bool _seeking = false;
  int _attempt = 0;
  final _visibilityKey = UniqueKey();
  String get _source => widget.url ?? widget.file!.path;
  bool get _onScreen => mounted && _foreground && _visible > 0 &&
      TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
  bool get _eligible => _onScreen && _ready && widget.active && _wantsPlay && _visible > .5;
  bool _owns(VideoPlayerController c, int attempt) => mounted &&
      attempt == _attempt && identical(_controller, c);

  @override
  void initState() {
    super.initState();
    VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 80);
    _muted = widget.audioSession?.muted ?? widget.muted;
    widget.audioSession?.addListener(_audioChanged);
    _wantsPlay = widget.autoplay;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _PlaybackOwner.register(this);
  }

  // A paused story still keeps its position; only hidden surfaces release decoders.
  void _syncResources() {
    if (!mounted) return;
    if (_onScreen) {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      if (widget.active && !_ready && !_initializing && !_failed) unawaited(_init());
    } else if (_controller != null || _initializing) {
      _releaseTimer ??= Timer(const Duration(seconds: 2), () {
        assert(() { debugPrint('Video idle timer fired: onScreen=$_onScreen'); return true; }());
        _releaseTimer = null;
        if (mounted && !_onScreen) {
          setState(() => _detach(remember: true));
        }
      });
    }
  }

  void _detach({required bool remember}) {
    ++_attempt;
    final c = _controller;
    assert(() { debugPrint('Video decoder release: initialized=${c?.value.isInitialized}'); return true; }());
    if (remember && c != null && c.value.isInitialized) {
      _resumeAt = c.value.position;
      if (widget.resumePosition) _PlaybackOwner.positions[_source] = _resumeAt!;
    }
    _controller = null;
    _ready = false;
    _initializing = false;
    _playing = false;
    _speeding = false;
    _seeking = false;
    if (c != null) {
      c.removeListener(_checkTrim);
      final commands = _commands;
      _commands = Future<void>.value();
      _disposals = _disposals.then((_) async {
        // A play command can create its polling timer after its native await.
        // Finish queued operations before stopping and disposing that controller.
        await commands;
        assert(() { debugPrint('Video commands drained; stopping controller'); return true; }());
        try {
          if (c.value.isInitialized) await c.pause();
        } catch (_) { /* Dispose even if the platform can no longer pause. */ }
        try { await c.dispose(); assert(() { debugPrint('Video native dispose finished'); return true; }()); } catch (error) {
          assert(() { debugPrint('Video decoder teardown failed: $error'); return true; }());
        }
      });
    }
  }

  Future<void> _command(Future<void> Function(VideoPlayerController) action) {
    final c = _controller;
    final attempt = _attempt;
    if (c == null || !_ready) return Future<void>.value();
    final result = _commands.then((_) async {
      if (!_owns(c, attempt) || !_ready) return;
      try {
        await action(c);
      } catch (_) {
        _fail(c, attempt);
      }
    });
    _commands = result;
    return result;
  }

  void _fail(VideoPlayerController c, int attempt) {
    if (!_owns(c, attempt) || _failed) return;
    // Invalidate identity before asynchronous disposal, so an old completion
    // can never null out a replacement video or setState after navigation.
    setState(() {
      _detach(remember: true);
      _failed = true;
    });
    widget.onError?.call();
  }

  void _speed(bool value) {
    if (_speeding == value) return;
    _speeding = value;
    unawaited(_command((c) => c.setPlaybackSpeed(value ? 2 : 1)));
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.file?.path != widget.file?.path) {
      _detach(remember: false);
      _resumeAt = null;
      _failed = false;
      _wantsPlay = widget.autoplay;
    }
    if (old.audioSession != widget.audioSession) {
      old.audioSession?.removeListener(_audioChanged);
      widget.audioSession?.addListener(_audioChanged);
      _audioChanged();
    }
    if (!widget.active || !widget.holdToSpeed) _speed(false);
    if (old.autoplay != widget.autoplay) _wantsPlay = widget.autoplay;
    if (old.muted != widget.muted || old.volume != widget.volume) {
      _muted = widget.audioSession?.muted ?? widget.muted;
      unawaited(_command((c) => c.setVolume(_muted ? 0 : widget.volume.clamp(0, 1))));
    }
    if (old.start != widget.start || old.end != widget.end) {
      _resumeAt = null;
      unawaited(_command((c) => c.seekTo(widget.start)));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _PlaybackOwner.update();
    });
  }

  void _audioChanged() {
    if (!mounted) return;
    setState(() => _muted = widget.audioSession?.muted ?? widget.muted);
    unawaited(_command((c) => c.setVolume(_muted ? 0 : widget.volume.clamp(0, 1))));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _speed(false);
    _PlaybackOwner.update();
  }

  @override
  void didHaveMemoryPressure() {
    if (mounted && !_onScreen) setState(() => _detach(remember: true));
  }

  Future<void> _init() async {
    if (!mounted || _initializing || _ready || !_onScreen) return;
    setState(() { _initializing = true; _failed = false; });
    final attempt = ++_attempt;
    VideoPlayerController? c;
    try {
      await _disposals;
      if (!mounted || attempt != _attempt) return;
      // This State owns lifecycle pause/resume. Disable the plugin's second
      // lifecycle observer, which can otherwise issue play outside our queue.
      final options = VideoPlayerOptions(allowBackgroundPlayback: true);
      c = widget.file != null
          ? VideoPlayerController.file(widget.file!, videoPlayerOptions: options)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url!), videoPlayerOptions: options);
      _controller = c;
      await c.initialize().timeout(const Duration(seconds: 15));
      if (!_owns(c, attempt)) return;
      await c.setLooping(widget.loop);
      if (!_owns(c, attempt)) return;
      await c.setVolume(_muted ? 0 : widget.volume.clamp(0, 1));
      if (!_owns(c, attempt)) return;
      final position = _resumeAt ?? (widget.start > Duration.zero ? widget.start :
          (widget.resumePosition ? _PlaybackOwner.positions[_source] : null));
      if (position != null && position >= widget.start && position < c.value.duration &&
          (widget.end == null || position < widget.end!)) await c.seekTo(position);
      if (!_owns(c, attempt)) return;
      c.addListener(_checkTrim);
      setState(() { _ready = true; _initializing = false; });
      widget.onReady?.call(c.value.duration);
      _PlaybackOwner.update();
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      if (c != null) {
        _fail(c, attempt);
      } else {
        setState(() { _initializing = false; _failed = true; });
        widget.onError?.call();
      }
    }
  }

  void _checkTrim() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.hasError) {
      final attempt = _attempt;
      scheduleMicrotask(() => _fail(c, attempt));
      return;
    }
    widget.onPlayback?.call(c.value);
    if (_seeking || widget.end == null) return;
    if (c.value.position >= widget.end! || c.value.position < widget.start) {
      _seeking = true;
      final attempt = _attempt;
      unawaited(_command((c) => c.seekTo(widget.start)).whenComplete(() {
        if (_owns(c, attempt)) _seeking = false;
      }));
    }
  }

  void _applyPlayback(bool play) {
    if (!play) _speed(false);
    if (!_ready || play == _playing) return;
    _playing = play;
    if (play) {
      unawaited(_command((c) => c.play()));
    } else {
      _resumeAt = _controller!.value.position;
      if (widget.resumePosition) _PlaybackOwner.positions[_source] = _resumeAt!;
      unawaited(_command((c) => c.pause()));
    }
    if (mounted) setState(() {});
  }

  void _tap() {
    if (widget.onTap != null) {
      _applyPlayback(false);
      widget.onTap!();
      return;
    }
    _wantsPlay = !_playing;
    _PlaybackOwner.update();
  }

  @override
  void dispose() {
    widget.audioSession?.removeListener(_audioChanged);
    _releaseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _detach(remember: true);
    _PlaybackOwner.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _visibilityKey,
    onVisibilityChanged: (info) {
      if (!mounted) return;
      _visible = info.visibleFraction;
      _PlaybackOwner.update();
    },
    child: _content(),
  );
  Widget _content() {
    if (_failed)
      return widget.errorWidget ??
          Center(
            child: TextButton(
              onPressed: _init,
              child: const Text('Video yüklenemedi · Tekrar dene'),
            ),
          );
    if (!_ready || _controller == null)
      return widget.loading ??
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
    final size = _controller!.value.size;
    final video = FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(_controller!),
      ),
    );
    final surface = ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller!,
      builder: (_, value, child) => Stack(fit: StackFit.expand, children: [
        child!,
        if (value.isBuffering) const Center(child: CircularProgressIndicator()),
      ]),
      child: video,
    );
    if (!widget.showControls) return surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Listener(
            onPointerUp: (_) => _speed(false),
            onPointerCancel: (_) => _speed(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tap,
              onLongPressStart: widget.holdToSpeed
                  ? (details) {
                      if (_playing &&
                          details.localPosition.dx >=
                              constraints.maxWidth / 2) {
                        _speed(true);
                      }
                    }
                  : null,
              onLongPressEnd: widget.holdToSpeed ? (_) => _speed(false) : null,
              onLongPressCancel: widget.holdToSpeed
                  ? () => _speed(false)
                  : null,
              child: surface,
            ),
          ),
        ),
        if (_speeding)
          const Positioned(
            top: 88,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: Chip(label: Text('2x ▶▶'))),
            ),
          ),
        if (!_playing)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: Colors.white70,
              ),
            ),
          ),
        if (widget.showMuteControl)
          Positioned(
            right: 10,
            bottom: 10,
            child: IconButton.filledTonal(
              tooltip: _muted ? 'Sesi aç' : 'Sesi kapat',
              onPressed: () {
                if (widget.audioSession != null) {
                  widget.audioSession!.toggle();
                  return;
                }
                setState(() => _muted = !_muted);
                unawaited(_command((c) => c.setVolume(_muted ? 0 : widget.volume.clamp(0, 1))));
              },
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ),
      ],
    );
  }
}

