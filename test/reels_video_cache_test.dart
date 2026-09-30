import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/reels_video_cache.dart';

void main() {
  late Directory root;
  late HttpServer server;
  late ReelsVideoCache cache;
  final original = List<int>.generate(4096, (i) => i % 256);
  String url(String path) => 'http://127.0.0.1:${server.port}/$path';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('reels-cache-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        if (request.uri.path == '/slow') await Future<void>.delayed(const Duration(milliseconds: 200));
        if (request.uri.path == '/error') { request.response.statusCode = 403; }
        else if (request.uri.path == '/large') { request.response.add(List.filled(16384, 1)); }
        else { request.response.contentLength = original.length; request.response.add(original); }
        await request.response.close();
      } catch (_) {}
    });
    cache = ReelsVideoCache(root: root, maxFileBytes: 8192, maxBytes: 24576);
  });
  tearDown(() async { await cache.dispose(); await server.close(force: true); await root.delete(recursive: true); });
  test('prefetch preserves exact original bytes and bounds disk cache while protecting active video', () async {
    cache.activeUrl = url('a');
    cache.warm([url('a'), url('b')]); await cache.idle;
    expect(await cache.peek(url('a'))!.readAsBytes(), original);
    cache.warm([url('c'), url('d')]); await cache.idle;
    expect(cache.peek(url('a')), isNotNull);
    expect(cache.peek(url('b')), isNull);
    final files = await root.list(recursive: true).where((f) => f is File).cast<File>().toList();
    expect(files.length, lessThanOrEqualTo(3));
    var bytes = 0; for (final f in files) { bytes += await f.length(); }
    expect(bytes, lessThanOrEqualTo(24576));
  });
  test('oversized chunked response and access errors leave no partial playable files', () async {
    cache.warm([url('large'), url('error')]); await cache.idle;
    expect(cache.peek(url('large')), isNull);
    expect(cache.peek(url('error')), isNull);
    expect(await root.list(recursive: true).where((f) => f is File).length, 0);
  });
  test('new swipe cancels obsolete work and screen disposal removes all cached bytes', () async {
    cache.warm([url('slow')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cache.warm([url('new')]); await cache.idle;
    expect(cache.peek(url('slow')), isNull);
    expect(await cache.peek(url('new'))!.readAsBytes(), original);
    await cache.dispose();
    expect(await root.list().length, 0);
  });
}
