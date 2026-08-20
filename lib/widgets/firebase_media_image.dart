import 'dart:typed_data';

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

  static List<String> postPaths(String userId, String postId) {
    if (userId.trim().isEmpty || postId.trim().isEmpty) {
      return const <String>[];
    }
    return <String>[
      'users/$userId/posts/$postId.jpg',
      'users/$userId/posts/$postId.png',
    ];
  }

  @override
  State<FirebaseMediaImage> createState() => _FirebaseMediaImageState();
}

class _FirebaseMediaImageState extends State<FirebaseMediaImage> {
  static const int _maxRecoveryBytes = 40 * 1024 * 1024;

  late Future<String?> _resolvedUrl;
  Uint8List? _resolvedBytes;
  bool _recoveryAttempted = false;
  bool _recoveringBytes = false;

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
      _recoveringBytes = false;
      _resolvedBytes = null;
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
    for (final reference in _storageReferences()) {
      try {
        return await reference.getDownloadURL();
      } catch (_) {
        // Try the next known Storage reference.
      }
    }

    return null;
  }

  List<Reference> _storageReferences() {
    final references = <Reference>[];
    final seen = <String>{};

    void add(Reference reference) {
      final key = '${reference.bucket}/${reference.fullPath}';
      if (seen.add(key)) references.add(reference);
    }

    final storage = FirebaseStorage.instance;
    final storagePath = widget.storagePath.trim();
    if (storagePath.isNotEmpty) add(storage.ref().child(storagePath));

    final savedUrl = widget.imageUrl.trim();
    if (savedUrl.isNotEmpty && _isFirebaseStorageUrl(savedUrl)) {
      try {
        add(storage.refFromURL(savedUrl));
      } catch (_) {
        // A malformed legacy URL must not block predictable path recovery.
      }
    }

    for (final path in widget.fallbackStoragePaths) {
      final cleanPath = path.trim();
      if (cleanPath.isNotEmpty) add(storage.ref().child(cleanPath));
    }

    return references;
  }

  bool get _canRecover {
    final savedUrl = widget.imageUrl.trim();
    return widget.storagePath.trim().isNotEmpty ||
        widget.fallbackStoragePaths.any((path) => path.trim().isNotEmpty) ||
        _isFirebaseStorageUrl(savedUrl);
  }

  Future<void> _recoverAfterLoadError() async {
    if (_recoveryAttempted || !_canRecover) return;
    _recoveryAttempted = true;
    if (mounted) setState(() => _recoveringBytes = true);

    Uint8List? bytes;
    for (final reference in _storageReferences()) {
      try {
        final candidate = await reference.getData(_maxRecoveryBytes);
        if (candidate != null && candidate.isNotEmpty) {
          bytes = candidate;
          break;
        }
      } catch (_) {
        // Authenticated byte download is the last recovery path.
      }
    }

    if (!mounted) return;
    setState(() {
      _resolvedBytes = bytes;
      _recoveringBytes = false;
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

  Widget _memoryImage(Uint8List bytes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = widget.width != null && widget.width!.isFinite
            ? widget.width!
            : constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        final deviceWidth =
            (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(64, 2160)
                .toInt();
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          cacheWidth: deviceWidth,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _error(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _resolvedBytes;
    if (bytes != null) return _memoryImage(bytes);
    if (_recoveringBytes) return _placeholder();

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
            if (willRecover) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _recoverAfterLoadError();
              });
            }
            return willRecover ? _placeholder() : _error();
          },
        );
      },
    );
  }
}
