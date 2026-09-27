import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Only the labels move. Swiping here never transforms the camera preview.
class CameraShareModeSelector extends StatefulWidget {
  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const CameraShareModeSelector({
    super.key,
    required this.selectedIndex,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<CameraShareModeSelector> createState() =>
      _CameraShareModeSelectorState();
}

class _CameraShareModeSelectorState extends State<CameraShareModeSelector> {
  static const labels = ['Story', 'Gönderi', 'Reels'];
  late final PageController _controller = PageController(
    initialPage: widget.selectedIndex,
    viewportFraction: .34,
  );

  @override
  void didUpdateWidget(covariant CameraShareModeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _controller.hasClients &&
        _controller.page!.round() != widget.selectedIndex) {
      _controller.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: PageView.builder(
        controller: _controller,
        physics: widget.enabled
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: labels.length,
        onPageChanged: (index) {
          if (widget.enabled && index != widget.selectedIndex) {
            widget.onChanged(index);
          }
        },
        itemBuilder: (context, index) {
          final selected = index == widget.selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              onTap: widget.enabled ? () => widget.onChanged(index) : null,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: selected ? 18 : 15,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                    child: Text(labels[index], maxLines: 1),
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 28 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CameraGalleryButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CameraGalleryButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Galeriden fotoğraf veya video seç',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xF01B252B),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82, maxWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onPressed == null ? Colors.white24 : AppColors.cyan,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  size: 30,
                  color: onPressed == null ? Colors.white38 : AppColors.cyan,
                ),
                const SizedBox(height: 6),
                Text(
                  'Galeriden seç',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: onPressed == null ? Colors.white38 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
