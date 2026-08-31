import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import 'camera_video_post_screen.dart';
import 'create_post_screen.dart';
import 'story_photo_editor_screen.dart';
import 'story_video_editor_screen.dart';

enum CameraShareMode { story, reels, photo, video }

class MainCameraScreen extends StatefulWidget {
  final CameraShareMode initialMode;

  const MainCameraScreen({
    super.key,
    this.initialMode = CameraShareMode.photo,
  });

  @override
  State<MainCameraScreen> createState() => _MainCameraScreenState();
}

class _MainCameraScreenState extends State<MainCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  late CameraShareMode _mode;
  CameraShareMode? _pendingMode;
  VideoRecordingCameraState? _recordingState;
  Timer? _recordingTimer;
  int _recordedSeconds = 0;
  bool _handlingCapture = false;
  bool _openingGallery = false;
  bool _showGrid = false;
  bool _storyVideo = false;

  bool get _isVideoMode =>
      _mode == CameraShareMode.reels ||
      _mode == CameraShareMode.video ||
      (_mode == CameraShareMode.story && _storyVideo);

  int get _videoLimitSeconds => _mode == CameraShareMode.story ? 15 : 60;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectMode(CameraShareMode mode, CameraState cameraState) {
    if (_recordingState != null || _handlingCapture || mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == CameraShareMode.story) _storyVideo = false;
      _recordedSeconds = 0;
    });
    cameraState.setState(
      mode == CameraShareMode.photo || mode == CameraShareMode.story
          ? CaptureMode.photo
          : CaptureMode.video,
    );
  }

  void _selectStoryMedia(bool video, CameraState cameraState) {
    if (_mode != CameraShareMode.story ||
        _recordingState != null ||
        _handlingCapture ||
        _storyVideo == video) {
      return;
    }
    setState(() {
      _storyVideo = video;
      _recordedSeconds = 0;
    });
    cameraState.setState(video ? CaptureMode.video : CaptureMode.photo);
  }

  Future<void> _capture(CameraState cameraState) async {
    if (_handlingCapture || _openingGallery) return;
    if (cameraState is PhotoCameraState) {
      _pendingMode = _mode;
      await cameraState.takePhoto();
      return;
    }
    if (cameraState is VideoCameraState) {
      _pendingMode = _mode;
      await cameraState.startRecording();
      _startRecordingClock();
      return;
    }
    if (cameraState is VideoRecordingCameraState) {
      _stopRecordingClock();
      await cameraState.stopRecording();
    }
  }

  void _startRecordingClock() {
    _recordingTimer?.cancel();
    if (mounted) setState(() => _recordedSeconds = 0);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final next = _recordedSeconds + 1;
      setState(() => _recordedSeconds = next);
      if (next < _videoLimitSeconds) return;
      timer.cancel();
      final state = _recordingState;
      _recordingState = null;
      if (state != null) await state.stopRecording();
    });
  }

  void _stopRecordingClock() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<void> _onMediaCapture(MediaCapture event) async {
    if (event.status == MediaCaptureStatus.failure) {
      _stopRecordingClock();
      _recordingState = null;
      _message('Çekim tamamlanamadı. Kamera izinlerini kontrol edip tekrar dene.');
      return;
    }
    if (event.status != MediaCaptureStatus.success || _handlingCapture) return;

    String? path;
    event.captureRequest.when(
      single: (single) {
        path = single.file?.path;
      },
      multiple: (multiple) {
        for (final file in multiple.fileBySensor.values) {
          if (file?.path.isNotEmpty == true) {
            path = file!.path;
            break;
          }
        }
      },
    );
    if (path == null || path!.isEmpty) {
      _message('Çekilen dosya bulunamadı.');
      return;
    }

    _stopRecordingClock();
    _recordingState = null;
    _handlingCapture = true;
    final capturedMode = _pendingMode ?? _mode;
    try {
      await _routeCapturedFile(
        File(path!),
        mode: capturedMode,
        isVideo: event.isVideo,
      );
    } finally {
      _handlingCapture = false;
    }
  }

  Future<void> _openGallery() async {
    if (_openingGallery || _handlingCapture || _recordingState != null) return;
    setState(() => _openingGallery = true);
    try {
      final wantsVideo = _isVideoMode;
      if (_mode == CameraShareMode.story) {
        final type = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheet) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Story için galeriden seç',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Fotoğraf seç'),
                  onTap: () => Navigator.pop(sheet, 'photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: const Text('Video seç'),
                  subtitle: const Text('En fazla 15 saniye'),
                  onTap: () => Navigator.pop(sheet, 'video'),
                ),
              ],
            ),
          ),
        );
        if (type == null || !mounted) return;
        final picked = type == 'video'
            ? await _picker.pickVideo(
                source: ImageSource.gallery,
                maxDuration: const Duration(seconds: 15),
              )
            : await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 100,
                requestFullMetadata: false,
              );
        if (picked != null && mounted) {
          await _routeCapturedFile(
            File(picked.path),
            mode: _mode,
            isVideo: type == 'video',
          );
        }
        return;
      }

      final picked = wantsVideo
          ? await _picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 60),
            )
          : await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 100,
              requestFullMetadata: false,
            );
      if (picked == null || !mounted) return;
      await _routeCapturedFile(
        File(picked.path),
        mode: _mode,
        isVideo: wantsVideo,
      );
    } catch (error) {
      _message('Galeri açılamadı: ${error.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _openingGallery = false);
    }
  }

  Future<void> _routeCapturedFile(
    File file, {
    required CameraShareMode mode,
    required bool isVideo,
  }) async {
    if (!await file.exists() || await file.length() <= 0) {
      throw Exception('Çekilen dosya okunamadı.');
    }
    if (!mounted) return;

    if (mode == CameraShareMode.story) {
      if (isVideo) {
        final shared = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => StoryVideoEditorScreen(video: file),
          ),
        );
        if (mounted && shared == true) Navigator.pop(context, true);
        return;
      }
      final shared = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StoryPhotoEditorScreen(photo: file),
        ),
      );
      if (mounted && shared == true) Navigator.pop(context, true);
      return;
    }

    if (isVideo) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CameraVideoPostScreen(
            video: file,
            isReel: mode == CameraShareMode.reels,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialImagePath: file.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode: _mode == CameraShareMode.photo
                  || (_mode == CameraShareMode.story && !_storyVideo)
              ? CaptureMode.photo
              : CaptureMode.video,
          videoOptions: VideoOptions(enableAudio: true),
          mirrorFrontCamera: true,
        ),
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.auto,
          aspectRatio: CameraAspectRatios.ratio_16_9,
          zoom: 0,
        ),
        previewFit: CameraPreviewFit.cover,
        enablePhysicalButton: true,
        progressIndicator: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.cyan,
                  size: 38,
                ),
                SizedBox(height: 14),
                CircularProgressIndicator(color: AppColors.cyan),
                SizedBox(height: 12),
                Text(
                  'Kamera hazırlanıyor…',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        onMediaCaptureEvent: _onMediaCapture,
        builder: (cameraState, preview) {
          final recording = cameraState is VideoRecordingCameraState;
          _recordingState = cameraState is VideoRecordingCameraState
              ? cameraState
              : null;
          return _CameraOverlay(
            state: cameraState,
            mode: _mode,
            storyVideo: _storyVideo,
            recording: recording,
            recordedSeconds: _recordedSeconds,
            showGrid: _showGrid,
            busy: _handlingCapture || _openingGallery,
            onClose: () => Navigator.pop(context),
            onGallery: _openGallery,
            onCapture: () => _capture(cameraState),
            onStoryMediaSelected: (video) =>
                _selectStoryMedia(video, cameraState),
            onToggleGrid: () => setState(() => _showGrid = !_showGrid),
            onModeSelected: (mode) => _selectMode(mode, cameraState),
          );
        },
      ),
    );
  }
}

class _CameraOverlay extends StatelessWidget {
  final CameraState state;
  final CameraShareMode mode;
  final bool storyVideo;
  final bool recording;
  final bool busy;
  final bool showGrid;
  final int recordedSeconds;
  final VoidCallback onClose;
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final ValueChanged<bool> onStoryMediaSelected;
  final VoidCallback onToggleGrid;
  final ValueChanged<CameraShareMode> onModeSelected;

  const _CameraOverlay({
    required this.state,
    required this.mode,
    required this.storyVideo,
    required this.recording,
    required this.busy,
    required this.showGrid,
    required this.recordedSeconds,
    required this.onClose,
    required this.onGallery,
    required this.onCapture,
    required this.onStoryMediaSelected,
    required this.onToggleGrid,
    required this.onModeSelected,
  });

  String get _modeLabel => switch (mode) {
    CameraShareMode.story => 'STORY',
    CameraShareMode.reels => 'REELS',
    CameraShareMode.photo => 'FOTOĞRAF',
    CameraShareMode.video => 'VİDEO',
  };

  String get _durationLabel => switch (mode) {
    CameraShareMode.story => storyVideo ? '15 sn' : 'Tek kare',
    CameraShareMode.reels => '60 sn',
    CameraShareMode.photo => 'Tek kare',
    CameraShareMode.video => '60 sn',
  };

  bool get _videoMode =>
      mode == CameraShareMode.reels ||
      mode == CameraShareMode.video ||
      (mode == CameraShareMode.story && storyVideo);

  String _clock(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xE6000000),
                ],
                stops: [0, .25, .58, 1],
              ),
            ),
          ),
        ),
        if (showGrid && mode == CameraShareMode.photo)
          const IgnorePointer(child: _CameraGrid()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassButton(icon: Icons.close_rounded, onTap: onClose),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        recording ? '● ${_clock(recordedSeconds)}' : _modeLabel,
                        style: TextStyle(
                          color: recording ? Colors.redAccent : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _GlassButton(
                      icon: Icons.flash_auto_rounded,
                      onTap: recording
                          ? null
                          : () => state.sensorConfig.switchCameraFlash(),
                    ),
                  ],
                ),
                const SizedBox(height: 62),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    children: [
                      _SideInfo(icon: Icons.timer_outlined, label: _durationLabel),
                      if (mode == CameraShareMode.photo) ...[
                        const SizedBox(height: 9),
                        _SideTool(
                          icon: Icons.grid_3x3_rounded,
                          label: showGrid ? 'Izgara açık' : 'Izgara',
                          onTap: onToggleGrid,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (mode == CameraShareMode.story) ...[
                  _StoryMediaSelector(
                    video: storyVideo,
                    enabled: !recording && !busy,
                    onChanged: onStoryMediaSelected,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  switch (mode) {
                    CameraShareMode.story => storyVideo
                        ? '15 saniyeye kadar videonu çek'
                        : 'Fotoğrafını çek ve düzenlemeye devam et',
                    CameraShareMode.reels => 'Dikey videonu Reels olarak paylaş',
                    CameraShareMode.photo => 'Fotoğrafını çek, konumunu ekle ve paylaş',
                    CameraShareMode.video => 'Videonu çek ve ana akışta paylaş',
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _GlassButton(
                          icon: Icons.photo_library_outlined,
                          onTap: busy || recording ? null : onGallery,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: busy ? null : onCapture,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 82,
                        height: 82,
                        padding: EdgeInsets.all(recording ? 23 : 7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: recording ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: recording ? BorderRadius.circular(8) : null,
                            color: _videoMode ? Colors.redAccent : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _GlassButton(
                          icon: Icons.cameraswitch_rounded,
                          onTap: recording ? null : () => state.switchCameraSensor(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: CameraShareMode.values
                        .map(
                          (item) => _ModeButton(
                            mode: item,
                            selected: item == mode,
                            enabled: !recording && !busy,
                            onTap: () => onModeSelected(item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (busy)
          const ColoredBox(
            color: Color(0x55000000),
            child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final CameraShareMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeButton({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  String get _label => switch (mode) {
    CameraShareMode.story => 'Story',
    CameraShareMode.reels => 'Reels',
    CameraShareMode.photo => 'Fotoğraf',
    CameraShareMode.video => 'Video',
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.accentGradient : null,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMediaSelector extends StatelessWidget {
  final bool video;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _StoryMediaSelector({
    required this.video,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoryMediaChoice(
            label: 'Fotoğraf',
            selected: !video,
            enabled: enabled,
            onTap: () => onChanged(false),
          ),
          _StoryMediaChoice(
            label: 'Video',
            selected: video,
            enabled: enabled,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _StoryMediaChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StoryMediaChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onTap == null ? Colors.white30 : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SideTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SideTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SideInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraGrid extends StatelessWidget {
  const _CameraGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CameraGridPainter());
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .38)
      ..strokeWidth = .8;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
