import 'dart:io';

import 'package:flutter/material.dart';

import 'story_photo_editor_screen.dart';
import 'story_music_picker.dart';

/// Both media types share the same drawing, sticker, mention and text tools.
class StoryVideoEditorScreen extends StatelessWidget {
  const StoryVideoEditorScreen({
    super.key,
    required this.video,
    this.initialMusic,
  });
  final File video;
  final StoryMusicSelection? initialMusic;
  @override
  Widget build(BuildContext context) => StoryPhotoEditorScreen(
    photo: video,
    videoMode: true,
    initialMusic: initialMusic,
  );
}
