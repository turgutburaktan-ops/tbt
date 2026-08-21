import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AppVideoPlayer extends StatefulWidget {
  final String? url;
  final File? file;
  final bool autoplay;
  final bool muted;
  final bool loop;
  final bool showControls;
  final BoxFit fit;
  final Widget? loading;
  final Widget? errorWidget;

  const AppVideoPlayer.network({
    super.key,
    required String this.url,
    this.autoplay = false,
    this.muted = true,
    this.loop = true,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
  }) : file = null;

  const AppVideoPlayer.file({
    super.key,
    required File this.file,
    this.autoplay = false,
    this.muted = true,
    this.loop = true,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.loading,
    this.errorWidget,
  }) : url = null;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _init();
  }

  Future<void> _init() async {
    final controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.loop);
      await controller.setVolume(_muted ? 0 : 1);
      if (widget.autoplay) await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget ??
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          );
    }
    if (!_ready || _controller == null) {
      return widget.loading ??
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
    }

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
        GestureDetector(onTap: _togglePlay, child: video),
        Center(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _controller!.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 38),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton.filledTonal(
            tooltip: _muted ? 'Sesi aç' : 'Sesi kapat',
            onPressed: _toggleMute,
            icon: Icon(
              _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
          ),
        ),
      ],
    );
  }
}
