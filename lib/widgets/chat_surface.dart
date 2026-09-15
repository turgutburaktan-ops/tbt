import 'package:flutter/material.dart';

export 'chat_backdrop.dart';

import '../services/chat_appearance_service.dart';
import '../theme/app_theme.dart';

/// Keep account-specific wallpaper while inheriting the shared TBT controls.
class ChatSurface extends StatefulWidget {
  const ChatSurface({super.key, required this.child});
  final Widget child;
  static const background = AppColors.background;
  static const panel = AppColors.surface;
  static const accent = AppColors.cyan;

  @override
  State<ChatSurface> createState() => _ChatSurfaceState();
}

class _ChatSurfaceState extends State<ChatSurface> {
  @override
  void initState() {
    super.initState();
    ChatAppearanceService.instance.start();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ChatAppearanceService.instance,
    child: widget.child,
    builder: (context, child) {
      final base = Theme.of(context);
      final background = ChatAppearanceService.instance.background.color;
      return Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: background,
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: child!,
      );
    },
  );
}
