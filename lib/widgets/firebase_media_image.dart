import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'temporary_pinch_zoom.dart';

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
  static const int _maxRecoveryBytes = 12 * 1024 * 1024;
  static const Duration _storageTimeout = Duration(seconds: 6);
  static const Duration _urlCacheLifetime = Duration(minutes: 20);
  static final Map<String, _CachedMediaUrl> _urlCache =
      <String, _CachedMediaUrl>{};
  static final Map<String, Future<String?>> _urlInFlight =
      <String, Future<String?>>{};

  late Future<String?> _resolvedUrl;
  Uint8List? _resolvedBytes;
  bool _recoveryAttempted = false;
  bool _recoveringBytes = false;

  bool get _isPostMedia {
    if (widget.storagePath.contains('/posts/')) return true;
    return widget.fallbackStoragePaths.any((path) => path.contains('/posts/'));
  }

  Widget _withPostZoom(Widget child) =>
      _isPostMedia ? TemporaryPinchZoom(child: child) : child;

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
          oldWidget.fallbackStoragePaths,
          widget.fallbackStoragePaths,
        )) {
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
      return Future<String?>.value(savedUrl);
    }
    return _resolveFreshUrl();
  }

  String get _resolutionKey {
    final parts = <String>[
      widget.storagePath.trim(),
      ...widget.fallbackStoragePaths.map((e) => e.trim()),
      widget.imageUrl.trim(),
    ].where((e) => e.isNotEmpty).toList(growable: false);
    return parts.join('|');
  }

  Future<String?> _resolveFreshUrl() {
    final key = _resolutionKey;
    if (key.isEmpty) return Future.value(null);
    final cached = _urlCache[key];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.url);
    }
    final running = _urlInFlight[key];
    if (running != null) return running;

    final request = _resolveFreshUrlInternal().then((url) {
      if (url != null && url.isNotEmpty) {
        _urlCache[key] = _CachedMediaUrl(url, DateTime.now());
      }
      return url;
    });
    _urlInFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_urlInFlight[key], request)) _urlInFlight.remove(key);
    });
  }

  Future<String?> _resolveFreshUrlInternal() async {
    for (final reference in _storageReferences()) {
      try {
        return await reference.getDownloadURL().timeout(_storageTimeout);
      } catch (_) {}
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
      } catch (_) {}
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
        final candidate = await reference
            .getData(_maxRecoveryBytes)
            .timeout(_storageTimeout);
        if (candidate != null && candidate.isNotEmpty) {
          bytes = candidate;
          break;
        }
      } catch (_) {}
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

  Widget _placeholder() =>
      widget.placeholder ??
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

  Widget _error() =>
      widget.errorWidget ??
      const ColoredBox(
        color: Color(0xFF171A1D),
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white30),
        ),
      );

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
    if (bytes != null) return _withPostZoom(_memoryImage(bytes));
    if (_recoveringBytes) return _placeholder();

    return FutureBuilder<String?>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder();
        }
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _error();
        return _withPostZoom(
          CachedNetworkImage(
            imageUrl: url,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 80),
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
          ),
        );
      },
    );
  }
}

class _CachedMediaUrl {
  final String url;
  final DateTime savedAt;

  const _CachedMediaUrl(this.url, this.savedAt);

  bool get isExpired =>
      DateTime.now().difference(savedAt) > _FirebaseMediaImageState._urlCacheLifetime;
}
