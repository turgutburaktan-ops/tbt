import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/post_photo_capture_service.dart';
import '../utils/post_photo_frame.dart';
import '../services/user_facing_error.dart';
import '../widgets/camera_share_controls.dart';
import 'camera_video_post_screen.dart';
import 'story_music_picker.dart';
import 'create_post_screen.dart';
import 'import_share_screen.dart';
import 'story_photo_editor_screen.dart';
import 'story_video_editor_screen.dart';

enum CameraShareMode { story, reels, photo, video }

class MainCameraScreen extends StatefulWidget {
  final CameraShareMode initialMode;
  final StoryMusicSelection? initialMusic;

  const MainCameraScreen({
    super.key,
    this.initialMode = CameraShareMode.photo,
    this.initialMusic,
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
  bool _captureInFlight = false;
  bool _switchingSensor = false;
  PostPhotoFrame? _photoFrame;
  Rect? _pendingPhotoSource;
  int _pendingPreviewTurns = 0;
  CameraOrientations _orientation = CameraOrientations.portrait_up;
  StreamSubscription<CameraOrientations>? _orientationSubscription;

  bool get _cameraBusy => _handlingCapture || _openingGallery || _captureInFlight || _switchingSensor;

  int get _previewTurns => switch (_orientation) {
    CameraOrientations.portrait_up => 0,
    CameraOrientations.landscape_left => 3,
    CameraOrientations.portrait_down => 2,
    CameraOrientations.landscape_right => 1,
  };

  bool get _isVideoMode =>
      _mode == CameraShareMode.reels ||
      _mode == CameraShareMode.video ||
      (_mode == CameraShareMode.story && _storyVideo);

  int get _videoLimitSeconds => _mode == CameraShareMode.story ? 15 : 60;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _orientationSubscription = CamerawesomePlugin.getNativeOrientation()?.listen(
      (value) => _orientation = value,
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _orientationSubscription?.cancel();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectMode(CameraShareMode mode, CameraState cameraState) {
    if (_recordingState != null ||
        _cameraBusy ||
        mode == _mode)
      return;
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
    if ((_mode != CameraShareMode.story &&
            _mode != CameraShareMode.photo &&
            _mode != CameraShareMode.video) ||
        _cameraBusy ||
        _recordingState != null ||
        (_mode == CameraShareMode.story
                ? _storyVideo
                : _mode == CameraShareMode.video) ==
            video) {
      return;
    }
    setState(() {
      if (_mode == CameraShareMode.story) {
        _storyVideo = video;
      } else {
        _mode = video ? CameraShareMode.video : CameraShareMode.photo;
      }
      _recordedSeconds = 0;
    });
    cameraState.setState(video ? CaptureMode.video : CaptureMode.photo);
  }

  Future<void> _switchSensor(CameraState state) async {
    if (_cameraBusy || _recordingState != null) return;
    setState(() => _switchingSensor = true);
    try {
      await state.switchCameraSensor(
        aspectRatio: _mode == CameraShareMode.photo ? state.sensorConfig.aspectRatio : null,
      );
      await WidgetsBinding.instance.endOfFrame;
    } catch (error) {
      _message(userFacingError(error));
    } finally {
      if (mounted) setState(() => _switchingSensor = false);
    }
  }

  Future<void> _capture(CameraState cameraState) async {
    if (_cameraBusy) return;
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
    if (event.status == MediaCaptureStatus.capturing) {
      if (_captureInFlight || _handlingCapture) return;
      _pendingMode = _mode;
      _pendingPhotoSource = _mode == CameraShareMode.photo ? _photoFrame?.source : null;
      _pendingPreviewTurns = _previewTurns;
      if (!event.isVideo && mounted) setState(() => _captureInFlight = true);
      return;
    }
    if (event.status == MediaCaptureStatus.failure) {
      _stopRecordingClock();
      _recordingState = null;
      if (mounted) setState(() => _captureInFlight = false);
      _message(
        'Çekim tamamlanamadı. Kamera izinlerini kontrol edip tekrar dene.',
      );
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
      if (mounted) setState(() => _captureInFlight = false);
      _message('Çekilen dosya bulunamadı.');
      return;
    }

    _stopRecordingClock();
    _recordingState = null;
    if (mounted) setState(() => _handlingCapture = true);
    final capturedMode = _pendingMode ?? _mode;
    try {
      var photo = File(path!);
      if (capturedMode == CameraShareMode.photo && !event.isVideo) {
        final source = _pendingPhotoSource;
        if (source == null) throw StateError('Kamera kadrajı hazırlanıyor. Tekrar dene.');
        photo = await PostPhotoCaptureService.prepare(photo, source, _pendingPreviewTurns);
      }
      await _routeCapturedFile(
        photo,
        mode: capturedMode,
        isVideo: event.isVideo,
      );
    } catch (error) {
      _message(userFacingError(error));
    } finally {
      _pendingMode = null;
      _pendingPhotoSource = null;
      if (mounted) setState(() { _handlingCapture = false; _captureInFlight = false; });
    }
  }

  Future<void> _openGallery() async {
    if (_cameraBusy || _recordingState != null) return;
    setState(() => _openingGallery = true);
    try {
      final selectedMode = _mode;
      final wantsVideo = _isVideoMode;
      if (selectedMode == CameraShareMode.story) {
        // One native picker shows both photos and videos, without an extra menu.
        final picked = await _picker.pickMedia(requestFullMetadata: false);
        if (picked == null || !mounted) return;
        final path = picked.path.toLowerCase();
        final isVideo =
            picked.mimeType?.startsWith('video/') == true ||
            RegExp(r'\.(mp4|mov|m4v|3gp|webm|avi|mkv)$').hasMatch(path);
        await _routeCapturedFile(
          File(picked.path),
          mode: selectedMode,
          isVideo: isVideo,
        );
        return;
      }
      if (selectedMode == CameraShareMode.photo) {
        final photos = await _picker.pickMultiImage(
          limit: 10,
          requestFullMetadata: false,
        );
        if (photos.isEmpty || !mounted) return;
        if (photos.length > 10) {
          _message('Bir gönderide en fazla 10 fotoğraf seçebilirsin.');
          return;
        }
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(
              initialImagePaths: photos.map((photo) => photo.path).toList(),
            ),
          ),
        );
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
        mode: selectedMode,
        isVideo: wantsVideo,
      );
    } catch (error) {
      _message(userFacingError(error));
    } finally {
      // Android photo picker dismissal can dispatch the same tap once more to
      // the underlying camera surface. Keep a short cooldown before rearming.
      await Future<void>.delayed(const Duration(milliseconds: 450));
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
            builder: (_) => StoryVideoEditorScreen(
              video: file,
              initialMusic: widget.initialMusic,
            ),
          ),
        );
        if (mounted && shared == true) Navigator.pop(context, true);
        return;
      }
      final shared = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StoryPhotoEditorScreen(
            photo: file,
            initialMusic: widget.initialMusic,
          ),
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
            initialMusic: widget.initialMusic,
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
      body: LayoutBuilder(builder: (context, constraints) {
        return CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode:
              _mode == CameraShareMode.photo ||
                  (_mode == CameraShareMode.story && !_storyVideo)
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
        previewFit: _mode == CameraShareMode.photo
            ? CameraPreviewFit.contain : CameraPreviewFit.cover,
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
          final insets = MediaQuery.paddingOf(context);
          _photoFrame = _mode == CameraShareMode.photo
              ? PostPhotoFrame.calculate(canvas: constraints.biggest,
                  preview: preview.nativePreviewSize,
                  topInset: insets.top, bottomInset: insets.bottom)
              : null;
          return _CameraOverlay(
            photoFrame: _photoFrame?.viewport,
            state: cameraState,
            mode: _mode,
            storyVideo: _storyVideo,
            recording: recording,
            recordedSeconds: _recordedSeconds,
            showGrid: _showGrid,
            busy: _cameraBusy,
            onClose: () => Navigator.pop(context),
            onImport: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportShareScreen()),
            ),
            onGallery: _openGallery,
            onCapture: () => _capture(cameraState),
            onSwitchSensor: () => _switchSensor(cameraState),
            onStoryMediaSelected: (video) =>
                _selectStoryMedia(video, cameraState),
            onToggleGrid: () => setState(() => _showGrid = !_showGrid),
            onModeSelected: (mode) => _selectMode(mode, cameraState),
          );
        },
      );
      }),
    );
  }
}

class _CameraOverlay extends StatelessWidget {
  final Rect? photoFrame;
  final CameraState state;
  final CameraShareMode mode;
  final bool storyVideo;
  final bool recording;
  final bool busy;
  final bool showGrid;
  final int recordedSeconds;
  final VoidCallback onClose;
  final VoidCallback onImport;
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final VoidCallback onSwitchSensor;
  final ValueChanged<bool> onStoryMediaSelected;
  final VoidCallback onToggleGrid;
  final ValueChanged<CameraShareMode> onModeSelected;

  const _CameraOverlay({
    this.photoFrame,
    required this.state,
    required this.mode,
    required this.storyVideo,
    required this.recording,
    required this.busy,
    required this.showGrid,
    required this.recordedSeconds,
    required this.onClose,
    required this.onImport,
    required this.onGallery,
    required this.onCapture,
    required this.onSwitchSensor,
    required this.onStoryMediaSelected,
    required this.onToggleGrid,
    required this.onModeSelected,
  });

  String get _modeLabel => switch (mode) {
    CameraShareMode.story => 'STORY',
    CameraShareMode.reels => 'REELS',
    CameraShareMode.photo => 'GÖNDERİ',
    CameraShareMode.video => 'GÖNDERİ',
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
        if (photoFrame != null)
          IgnorePointer(child: CustomPaint(painter: _PostFrameMask(photoFrame!))),
        if (photoFrame == null) const IgnorePointer(
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
        if (showGrid && photoFrame != null)
          Positioned.fromRect(rect: photoFrame!,
            child: const IgnorePointer(child: _CameraGrid())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassButton(icon: Icons.close_rounded, onTap: onClose),
                    if (!recording && !busy)
                      PopupMenuButton<String>(
                        tooltip: 'Diğer seçenekler',
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onSelected: (_) => onImport(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'import',
                            child: Text('Diğer uygulamalardan aktar'),
                          ),
                        ],
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
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
                    if (photoFrame != null) _GlassButton(
                      icon: showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      onTap: onToggleGrid,
                    ),
                    _GlassButton(
                      icon: Icons.flash_auto_rounded,
                      onTap: recording || busy
                          ? null
                          : () => state.sensorConfig.switchCameraFlash(),
                    ),
                  ],
                ),
                if (photoFrame == null) ...[
                const SizedBox(height: 62),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    children: [
                      _SideInfo(
                        icon: Icons.timer_outlined,
                        label: _durationLabel,
                      ),
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
                ],
                const Spacer(),
                if (mode != CameraShareMode.reels) ...[
                  _StoryMediaSelector(
                    video: _videoMode,
                    enabled: !recording && !busy,
                    onChanged: onStoryMediaSelected,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  switch (mode) {
                    CameraShareMode.story =>
                      storyVideo
                          ? '15 saniyeye kadar videonu çek'
                          : 'Fotoğraf çek veya galeriden seç',
                    CameraShareMode.reels =>
                      'Dikey videonu Reels olarak paylaş',
                    CameraShareMode.photo =>
                      'Bu kadraj gönderinde aynı şekilde görünecek',
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
                        child: CameraGalleryButton(
                          onPressed: busy || recording ? null : onGallery,
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
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 18),
                          ],
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: recording
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius: recording
                                ? BorderRadius.circular(8)
                                : null,
                            color: _videoMode ? Colors.redAccent : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _GlassButton(
                          icon: Icons.cameraswitch_rounded,
                          onTap: recording || busy
                              ? null
                              : onSwitchSensor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                CameraShareModeSelector(
                  selectedIndex: mode == CameraShareMode.story
                      ? 0
                      : mode == CameraShareMode.reels
                      ? 2
                      : 1,
                  enabled: !recording && !busy,
                  onChanged: (index) => onModeSelected(
                    [
                      CameraShareMode.story,
                      CameraShareMode.photo,
                      CameraShareMode.reels,
                    ][index],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (busy)
          const ColoredBox(
            color: Color(0x55000000),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            ),
          ),
      ],
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
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PostFrameMask extends CustomPainter {
  final Rect frame;
  const _PostFrameMask(this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)..addRect(frame);
    canvas.drawPath(outside, Paint()..color = Colors.black);
    canvas.drawRect(frame, Paint()..color = Colors.white38
      ..style = PaintingStyle.stroke..strokeWidth = 1);
  }
  @override
  bool shouldRepaint(covariant _PostFrameMask oldDelegate) => oldDelegate.frame != frame;
}
