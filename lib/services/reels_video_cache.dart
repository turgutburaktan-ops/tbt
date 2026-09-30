import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Screen-scoped original bytes only. No transcoding and no extra decoders.
class ReelsVideoCache {
  ReelsVideoCache({this.maxFileBytes = 24 * 1024 * 1024,
    this.maxBytes = 72 * 1024 * 1024, this.root});
  final int maxFileBytes, maxBytes;
  final Directory? root;
  static final _liveDirectories = <String>{};
  static Future<void> _directoryQueue = Future<void>.value();
  final _files = LinkedHashMap<String, File>();
  final _sizes = <String, int>{};
  Future<void> _queue = Future<void>.value();
  Directory? _directory;
  HttpClient? _client;
  int _generation = 0, _serial = 0;
  bool _disposed = false;
  List<String> _requested = [];
  String? activeUrl;

  File? peek(String url) {
    final file = _files.remove(url);
    if (file == null) return null;
    if (!file.existsSync()) { _sizes.remove(url); return null; }
    _files[url] = file;
    return file;
  }

  void stop() {
    _generation++;
    _requested = [];
    _client?.close(force: true);
    _client = null;
  }

  /// Called once playback is running; next video first, then current for revisits.
  void warm(List<String> urls) {
    if (_disposed) return;
    final targets = urls.where((u) => u.isNotEmpty).toSet().take(2).toList();
    if (targets.length == _requested.length &&
        List.generate(targets.length, (i) => targets[i] == _requested[i]).every((v) => v)) return;
    stop();
    _requested = targets;
    final generation = _generation;
    _queue = _queue.then((_) async {
      for (final url in targets) {
        if (_disposed || generation != _generation) return;
        if (peek(url) != null) continue;
        await _download(url, generation);
      }
    });
  }

  Future<void> get idle => _queue;

  Future<void> _remove(String url) async {
    final file = _files.remove(url);
    _sizes.remove(url);
    try { if (file != null && await file.exists()) await file.delete(); } catch (_) {}
  }

  Future<Directory> _createDirectory() async {
    late Directory result;
    final operation = _directoryQueue.then((_) async {
      final parent = root ?? await getTemporaryDirectory();
      // Remove leftovers after a killed process, without touching another live screen.
      await for (final entry in parent.list()) {
        if (entry is Directory && entry.path.split(Platform.pathSeparator).last.startsWith('tbt-reels-') && !_liveDirectories.contains(entry.path)) {
          try { await entry.delete(recursive: true); } catch (_) {}
        }
      }
      result = await parent.createTemp('tbt-reels-');
      _liveDirectories.add(result.path);
    });
    _directoryQueue = operation.catchError((Object _) {});
    await operation;
    return result;
  }

  Future<void> _download(String url, int generation) async {
    File? partial;
    IOSink? sink;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    _client = client;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.contentLength > maxFileBytes) return;
      final mime = response.headers.contentType?.mimeType;
      if (mime != null && !mime.startsWith('video/') && mime != 'application/octet-stream') return;
      // Reserve space for the in-flight file, including unknown content lengths.
      while (_sizes.values.fold<int>(0, (a, b) => a + b) + maxFileBytes > maxBytes || _files.length >= 3) {
        final candidates = _files.keys.where((key) => key != activeUrl).toList();
        if (candidates.isEmpty) return;
        await _remove(candidates.first);
      }
      final directory = _directory ??= await _createDirectory();
      partial = File('${directory.path}/${_serial++}.mp4');
      sink = partial.openWrite();
      int received = 0;
      final watch = Stopwatch()..start();
      await for (final bytes in response.timeout(const Duration(seconds: 5))) {
        if (_disposed || generation != _generation || watch.elapsed > const Duration(seconds: 20)) return;
        received += bytes.length;
        if (received > maxFileBytes) return;
        sink.add(bytes);
        await sink.flush();
      }
      await sink.close(); sink = null;
      if (_disposed || generation != _generation || received == 0 ||
          (response.contentLength >= 0 && received != response.contentLength)) return;
      _files[url] = partial;
      _sizes[url] = received;
      partial = null;
    } catch (_) {
      // A failed prefetch must never prevent normal network playback.
    } finally {
      try { await sink?.close(); } catch (_) {}
      try { if (partial != null && await partial.exists()) await partial.delete(); } catch (_) {}
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> trim() async {
    stop();
    await _queue;
    for (final url in _files.keys.toList()) {
      if (url != activeUrl) await _remove(url);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    stop();
    await _queue;
    _files.clear(); _sizes.clear();
    try { await _directory?.delete(recursive: true); } catch (_) {}
    _liveDirectories.remove(_directory?.path);
  }
}
