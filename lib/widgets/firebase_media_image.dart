import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Loads user media through Firebase Storage instead of trusting a persisted
/// download token forever. Old download URLs remain as a final fallback.
class FirebaseMediaImage extends StatefulWidget {
  final String imageUrl;
  final String storagePath;
  final List<String> fallbackStoragePaths;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FirebaseMediaImage({
    super.key,
    this.imageUrl = '',
    this.storagePath = '',
    this.fallbackStoragePaths = const <String>[],
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.errorWidget,
  });

  static List<String> avatarPaths(String userId) {
    if (userId.trim().isEmpty) return const <String>[];
    return <String>[
      'users/$userId/profile/avatar.jpg',
      'users/$userId/profile/avatar.png',
    ];
  }

  @override
  State<FirebaseMediaImage> createState() => _FirebaseMediaImageState();
}

class _FirebaseMediaImageState extends State<FirebaseMediaImage> {
  late Future<String?> _resolvedUrl;
  bool _recoveryAttempted = false;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _initialUrl();
  }

  @override
  void didUpdateWidget(covariant FirebaseMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.storagePath != widget.storagePath ||
        !_samePaths(
            oldWidget.fallbackStoragePaths, widget.fallbackStoragePaths)) {
      _recoveryAttempted = false;
      _resolvedUrl = _initialUrl();
    }
  }

  bool _samePaths(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<String?> _initialUrl() {
    final savedUrl = widget.imageUrl.trim();
    if (savedUrl.startsWith('http://') || savedUrl.startsWith('https://')) {
      // This path preserves CachedNetworkImage's disk-cache speed. Storage is
      // contacted only if the persisted URL really fails.
      return Future<String?>.value(savedUrl);
    }
    return _resolveFreshUrl();
  }

  Future<String?> _resolveFreshUrl() async {
    final storagePath = widget.storagePath.trim();
    if (storagePath.isNotEmpty) {
      try {
        return await FirebaseStorage.instance
            .ref()
            .child(storagePath)
            .getDownloadURL();
      } catch (_) {
        // The saved URL and known fallback paths can still recover the image.
      }
    }

    final savedUrl = widget.imageUrl.trim();
    // Firebase download tokens can be rotated. Resolve the reference again so
    // posts created with an older token continue to render.
    if (savedUrl.isNotEmpty && _isFirebaseStorageUrl(savedUrl)) {
      try {
        return await FirebaseStorage.instance
            .refFromURL(savedUrl)
            .getDownloadURL();
      } catch (_) {
        // The original URL may still be public or supplied by another host.
      }
    }

    final fallbackPaths = <String>{
      ...widget.fallbackStoragePaths.map((path) => path.trim()).where(
            (path) => path.isNotEmpty,
          ),
    };
    for (final path in fallbackPaths) {
      try {
        return await FirebaseStorage.instance
            .ref()
            .child(path)
            .getDownloadURL();
      } catch (_) {
        // Try the next predictable path.
      }
    }

    return null;
  }

  bool get _canRecover {
    final savedUrl = widget.imageUrl.trim();
    return widget.storagePath.trim().isNotEmpty ||
        widget.fallbackStoragePaths.any((path) => path.trim().isNotEmpty) ||
        _isFirebaseStorageUrl(savedUrl);
  }

  void _recoverAfterLoadError() {
    if (_recoveryAttempted || !_canRecover) return;
    _recoveryAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _resolvedUrl = _resolveFreshUrl());
    });
  }

  bool _isFirebaseStorageUrl(String value) {
    if (value.startsWith('gs://')) return true;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.host == 'firebasestorage.googleapis.com' ||
        uri.host == 'storage.googleapis.com' ||
        uri.host.endsWith('.firebasestorage.app');
  }

  Widget _placeholder() {
    return widget.placeholder ??
        const ColoredBox(
          color: Color(0xFF171A1D),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white24,
              ),
            ),
          ),
        );
  }

  Widget _error() {
    return widget.errorWidget ??
        const ColoredBox(
          color: Color(0xFF171A1D),
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white30),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder();
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _error();
        return CachedNetworkImage(
          imageUrl: url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) {
            final willRecover = !_recoveryAttempted && _canRecover;
            _recoverAfterLoadError();
            return willRecover ? _placeholder() : _error();
          },
        );
      },
    );
  }
}
