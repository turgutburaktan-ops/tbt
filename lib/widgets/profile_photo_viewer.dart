import 'package:flutter/material.dart';

class ProfilePhotoViewer extends StatefulWidget {
  const ProfilePhotoViewer({super.key, required this.name, required this.child});
  final String name;
  final Widget child;
  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.name)),
    body: GestureDetector(
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: () {
        _transform.value = _transform.value.getMaxScaleOnAxis() > 1
            ? Matrix4.identity()
            : (Matrix4.identity()..translate(-_tap.dx * 2, -_tap.dy * 2)..scale(3.0));
      },
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(child: widget.child),
      ),
    ),
  );
}
