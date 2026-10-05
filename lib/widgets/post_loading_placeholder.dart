import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reserves a card-sized viewport while the server checks post visibility.
/// A tiny loader would cause the lazy feed to mount every pending post at once.
class PostLoadingPlaceholder extends StatelessWidget {
  const PostLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: constraints.maxWidth.clamp(240.0, 680.0) + 112,
      child: Semantics(
        label: 'Gönderi yükleniyor',
        child: ColoredBox(
          color: AppColors.surface,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    ),
  );
}
