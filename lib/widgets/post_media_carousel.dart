import 'package:flutter/material.dart';

import 'firebase_media_image.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> storagePaths;
  final List<String> fallbackStoragePaths;
  final BoxFit fit;
  final bool zoomEnabled;
  final VoidCallback? onDoubleTap;

  const PostMediaCarousel({
    super.key,
    required this.imageUrls,
    this.storagePaths = const [],
    this.fallbackStoragePaths = const [],
    this.fit = BoxFit.cover,
    this.zoomEnabled = false,
    this.onDoubleTap,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  int _page = 0;

  int get _count => widget.imageUrls.isEmpty ? 1 : widget.imageUrls.length;

  String _urlAt(int index) =>
      index < widget.imageUrls.length ? widget.imageUrls[index] : '';

  String _pathAt(int index) =>
      index < widget.storagePaths.length ? widget.storagePaths[index] : '';

  Widget _image(int index) {
    final image = FirebaseMediaImage(
      imageUrl: _urlAt(index),
      storagePath: _pathAt(index),
      fallbackStoragePaths: index == 0 ? widget.fallbackStoragePaths : const [],
      width: double.infinity,
      height: double.infinity,
      fit: widget.fit,
      errorWidget: const ColoredBox(
        color: Color(0xFF1A1D20),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 58),
        ),
      ),
    );
    if (!widget.zoomEnabled) return image;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      panEnabled: true,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.expand(child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: _count,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) => RepaintBoundary(child: _image(index)),
          ),
          if (_count > 1)
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  child: Text(
                    '${_page + 1}/$_count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          if (_count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _count,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: index == _page ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _page ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
