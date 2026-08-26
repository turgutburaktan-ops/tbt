import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two-finger focal zoom for inline photos.
///
/// Raw pointer events are used intentionally so one-finger vertical scrolling
/// stays owned by the parent ListView. The photo never opens a new route and
/// immediately animates back to 1x when fewer than two fingers remain.
class TemporaryPinchZoom extends StatefulWidget {
  final Widget child;
  final double maxScale;

  const TemporaryPinchZoom({super.key, required this.child, this.maxScale = 4});

  @override
  State<TemporaryPinchZoom> createState() => _TemporaryPinchZoomState();
}

class _TemporaryPinchZoomState extends State<TemporaryPinchZoom> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double _initialDistance = 0;
  double _scale = 1;
  Offset _focal = Offset.zero;
  bool _active = false;

  List<Offset> get _firstTwo =>
      _pointers.values.take(2).toList(growable: false);

  double _distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  Offset _midpoint(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  void _beginIfReady() {
    if (_pointers.length < 2) return;
    final points = _firstTwo;
    final distance = _distance(points[0], points[1]);
    if (distance <= 0) return;
    setState(() {
      _initialDistance = distance;
      _focal = _midpoint(points[0], points[1]);
      _scale = 1;
      _active = true;
    });
  }

  void _updateIfReady() {
    if (_pointers.length < 2 || _initialDistance <= 0) return;
    final points = _firstTwo;
    final currentDistance = _distance(points[0], points[1]);
    final nextScale = (currentDistance / _initialDistance)
        .clamp(1.0, widget.maxScale)
        .toDouble();
    setState(() {
      _focal = _midpoint(points[0], points[1]);
      _scale = nextScale;
      _active = true;
    });
  }

  void _endPointer(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length >= 2) {
      _beginIfReady();
      return;
    }
    if (_active || _scale != 1) {
      setState(() {
        _active = false;
        _scale = 1;
        _initialDistance = 0;
        _focal = Offset.zero;
      });
    }
  }

  Matrix4 _matrix() {
    if (!_active || _scale == 1) return Matrix4.identity();
    return Matrix4.identity()
      ..translate(_focal.dx, _focal.dy)
      ..scale(_scale, _scale)
      ..translate(-_focal.dx, -_focal.dy);
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointers[event.pointer] = event.localPosition;
        if (_pointers.length == 2) _beginIfReady();
      },
      onPointerMove: (event) {
        if (!_pointers.containsKey(event.pointer)) return;
        _pointers[event.pointer] = event.localPosition;
        if (_pointers.length >= 2) _updateIfReady();
      },
      onPointerUp: (event) => _endPointer(event.pointer),
      onPointerCancel: (event) => _endPointer(event.pointer),
      child: AnimatedContainer(
        duration: _active ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: _matrix(),
        transformAlignment: Alignment.topLeft,
        child: widget.child,
      ),
    ),
  );
}
