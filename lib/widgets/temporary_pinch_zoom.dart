import 'package:flutter/material.dart';

/// Two-finger, focal-point zoom that never opens a new screen and resets as
/// soon as the gesture ends. One-finger dragging remains available to the
/// parent scroll view.
class TemporaryPinchZoom extends StatefulWidget {
  final Widget child;
  final double maxScale;
  const TemporaryPinchZoom({super.key, required this.child, this.maxScale = 4});

  @override
  State<TemporaryPinchZoom> createState() => _TemporaryPinchZoomState();
}

class _TemporaryPinchZoomState extends State<TemporaryPinchZoom> {
  double _scale = 1;
  Offset _focal = Offset.zero;
  bool _active = false;

  void _start(ScaleStartDetails d) {
    if (d.pointerCount < 2) return;
    setState(() { _active = true; _focal = d.localFocalPoint; });
  }

  void _update(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    setState(() {
      _active = true;
      _focal = d.localFocalPoint;
      _scale = d.scale.clamp(1.0, widget.maxScale).toDouble();
    });
  }

  void _reset() {
    if (!_active && _scale == 1) return;
    setState(() { _active = false; _scale = 1; _focal = Offset.zero; });
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _start,
      onScaleUpdate: _update,
      onScaleEnd: (_) => _reset(),
      child: AnimatedScale(
        scale: _scale,
        duration: _active ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: _focal == Offset.zero ? Alignment.center : Alignment(
          (_focal.dx / (context.size?.width ?? 1)) * 2 - 1,
          (_focal.dy / (context.size?.height ?? 1)) * 2 - 1,
        ),
        child: widget.child,
      ),
    ),
  );
}
