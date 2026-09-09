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
  final bool holdToSpeed;
  final BoxFit fit;
  final Widget? loading, errorWidget;
  final VoidCallback? onTap;
  final Duration start;
  final Duration? end;
  const AppVideoPlayer.network({
    super.key,
    required String this.url,
    this.autoplay = false,
    this.muted = true,
    this.volume = 1,
    this.holdToSpeed = false,
    this.loop = true,
    this.showControls = true,
    this.active = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
    this.onTap,
    this.start = Duration.zero,
    this.end,
  }) : file = null;
  const AppVideoPlayer.file({
    super.key,
    required File this.file,
    this.autoplay = false,
    this.muted = true,
    this.volume = 1,
    this.holdToSpeed = false,
    this.loop = true,
    this.showControls = true,
    this.active = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
    this.onTap,
    this.start = Duration.zero,
    this.end,
  }) : url = null;
  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  double _visible = 0;
  bool _ready = false,
      _failed = false,
      _initializing = false,
      _foreground = true;
  bool _muted = true, _wantsPlay = false, _playing = false;
  int _attempt = 0;
  bool _speeding = false;
  void _speed(bool value) {
    if (_speeding == value) return;
    _speeding = value;
    _controller?.setPlaybackSpeed(value ? 2 : 1);
    if (mounted) setState(() {});
  }
  final _visibilityKey = UniqueKey();
  String get _source => widget.url ?? widget.file!.path;
  bool get _eligible =>
      mounted &&
      _ready &&
      widget.active &&
      _wantsPlay &&
      _foreground &&
      _visible > .5 &&
      TickerMode.of(context) &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void initState() {
    super.initState();
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 80,
    );
    _muted = widget.muted;
    _wantsPlay = widget.autoplay;
    WidgetsBinding.instance.addObserver(this);
    _PlaybackOwner.register(this);
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.file?.path != widget.file?.path) {
      ++_attempt;
      _speed(false);
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _initializing = false;
      _failed = false;
      _playing = false;
      _wantsPlay = widget.autoplay;
      if (_visible > 0) _init();
    }
    if (!widget.active || !widget.holdToSpeed) _speed(false);
    if (old.autoplay != widget.autoplay) _wantsPlay = widget.autoplay;
    if (old.muted != widget.muted || old.volume != widget.volume) {
      _muted = widget.muted;
      _controller?.setVolume(_muted ? 0 : widget.volume.clamp(0, 1));
    }
    if (old.start != widget.start || old.end != widget.end)
      _controller?.seekTo(widget.start);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _PlaybackOwner.update();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _speed(false);
    _PlaybackOwner.update();
  }

  Future<void> _init() async {
    if (_initializing || _ready) return;
    _initializing = true;
    _failed = false;
    final attempt = ++_attempt;
    final c = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || attempt != _attempt) return;
      await c.setLooping(widget.loop);
      await c.setVolume(_muted ? 0 : widget.volume.clamp(0, 1));
      c.addListener(_checkTrim);
      final position = widget.start > Duration.zero
          ? widget.start
          : _PlaybackOwner.positions[_source];
      if (position != null && position < c.value.duration)
        await c.seekTo(position);
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _ready = true;
        _initializing = false;
      });
      _PlaybackOwner.update();
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      await c.dispose();
      _controller = null;
      setState(() {
        _failed = true;
        _initializing = false;
      });
    }
  }

  bool _seeking = false;
  void _checkTrim() {
    final c = _controller;
    if (c == null || !_ready || _seeking || widget.end == null) return;
    if (c.value.position >= widget.end! || c.value.position < widget.start) {
      _seeking = true;
      c.seekTo(widget.start).whenComplete(() => _seeking = false);
    }
  }

  void _applyPlayback(bool play) {
    if (!play) _speed(false);
    if (!_ready || play == _playing) return;
    _playing = play;
    if (play) {
      final saved = _PlaybackOwner.positions[_source];
      if (saved != null &&
          saved >= widget.start &&
          (widget.end == null || saved < widget.end!) &&
          saved < _controller!.value.duration)
        _controller!.seekTo(saved);
      _controller!.play();
    } else {
      _PlaybackOwner.positions[_source] = _controller!.value.position;
      _controller!.pause();
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
    ++_attempt;
    WidgetsBinding.instance.removeObserver(this);
    _PlaybackOwner.unregister(this);
    if (_ready) _PlaybackOwner.positions[_source] = _controller!.value.position;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _visibilityKey,
    onVisibilityChanged: (info) {
      _visible = info.visibleFraction;
      if (_visible > 0 && !_ready && !_failed) _init();
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
    if (!widget.showControls) return video;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(builder: (context, constraints) => Listener(
          onPointerUp: (_) => _speed(false),
          onPointerCancel: (_) => _speed(false),
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          onLongPressStart: widget.holdToSpeed ? (details) {
            if (_playing && details.localPosition.dx >= constraints.maxWidth / 2) {
              _speed(true);
            }
          } : null,
          onLongPressEnd: widget.holdToSpeed ? (_) => _speed(false) : null,
          onLongPressCancel: widget.holdToSpeed ? () => _speed(false) : null,
          child: video,
        ))),
        if (_speeding)
          const Positioned(top: 88, left: 0, right: 0, child: IgnorePointer(
            child: Center(child: Chip(label: Text('2x ▶▶'))),
          )),
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
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton.filledTonal(
            tooltip: _muted ? 'Sesi aç' : 'Sesi kapat',
            onPressed: () {
              setState(() => _muted = !_muted);
              _controller!.setVolume(_muted ? 0 : widget.volume.clamp(0, 1));
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

