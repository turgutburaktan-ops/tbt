import '../theme/app_theme.dart';

import 'package:flutter/material.dart';

import '../services/chat_appearance_service.dart';

/// Shared by the inbox and conversations, without affecting the rest of TBT.
class ChatSurface extends StatefulWidget {
  const ChatSurface({super.key, required this.child});
  final Widget child;
  static const background = AppColors.background;
  static const panel = AppColors.surface;
  static const accent = AppColors.primary;

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
          colorScheme: base.colorScheme.copyWith(
            primary: ChatSurface.accent,
            onPrimary: ChatSurface.background,
            secondary: ChatSurface.accent,
            onSecondary: ChatSurface.background,
            primaryContainer: const Color(0xFF203C62),
            onPrimaryContainer: const Color(0xFFE8F1FF),
            surface: ChatSurface.panel,
            onSurface: const Color(0xFFF0F5FF),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: ChatSurface.accent,
            selectionColor: Color(0x449FC7FF),
            selectionHandleColor: ChatSurface.accent,
          ),
          scaffoldBackgroundColor: background,
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            titleTextStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF0F5FF),
            ),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: ChatSurface.panel,
            prefixIconColor: ChatSurface.accent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: ChatSurface.accent),
            ),
          ),
          chipTheme: base.chipTheme.copyWith(
            backgroundColor: ChatSurface.panel,
            selectedColor: const Color(0xFF203C62),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: const TextStyle(color: Color(0xFFF0F5FF)),
          ),
        ),
        child: child!,
      );
    },
  );
}

class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(color: Theme.of(context).scaffoldBackgroundColor, child: child);
}
