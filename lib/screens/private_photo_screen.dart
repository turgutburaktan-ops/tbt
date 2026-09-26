import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/private_photo_service.dart';
import '../services/user_facing_error.dart';

class PrivatePhotoScreen extends StatefulWidget {
  final String threadId;
  final String messageId;
  const PrivatePhotoScreen({super.key, required this.threadId, required this.messageId});
  @override
  State<PrivatePhotoScreen> createState() => _PrivatePhotoScreenState();
}

class _PrivatePhotoScreenState extends State<PrivatePhotoScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('tbt/private_photo');
  Uint8List? _bytes;
  MemoryImage? _image;
  String? _session;
  String? _error;
  Timer? _timer;
  bool _closed = false;
  bool _armed = false;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'captured') _close();
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      // Protection must be installed successfully before a viewing right is used.
      final state = await _channel.invokeMapMethod<String, dynamic>('setActive', {'active': true});
      if (_closed || !mounted) {
        await _channel.invokeMethod<void>('setActive', {'active': false});
        return;
      }
      _armed = true;
      if (state?['captured'] != false) {
        throw Exception('Ekran kaydını veya yansıtmayı kapatıp tekrar dene.');
      }
      final result = await PrivatePhotoService.call({
        'action': 'open', 'threadId': widget.threadId, 'messageId': widget.messageId});
      _session = result['session'] as String;
      if (_closed || !mounted) { unawaited(_release()); return; }
      _bytes = base64Decode(result['bytes'] as String);
      _image = MemoryImage(_bytes!);
      _remaining = result['remaining'] as int;
      _timer = Timer(Duration(milliseconds: result['sessionMs'] as int), _close);
      setState(() {});
    } catch (error) {
      if (mounted && !_closed) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _release() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    try {
      await PrivatePhotoService.call({'action': 'close', 'threadId': widget.threadId,
        'messageId': widget.messageId, 'session': session});
    } catch (_) { /* Server lease expires even if the device goes offline. */ }
  }

  void _clear() {
    _timer?.cancel();
    final image = _image;
    _image = null;
    if (image != null) unawaited(image.evict());
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _clear();
    if (mounted) {
      setState(() {});
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_armed && state != AppLifecycleState.resumed) _close();
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _clear();
    unawaited(_release());
    _channel.setMethodCallHandler(null);
    unawaited(_channel.invokeMethod<void>('setActive', {'active': false}).catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) { _closed = true; _clear(); }
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Özel fotoğraf'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _close)),
      body: SafeArea(child: Column(children: [
        Expanded(child: Center(child: _closed ? const SizedBox.shrink()
          : _error != null ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
          : _image == null ? const CircularProgressIndicator()
          : Image(image: _image!, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('Fotoğraf görüntülenemedi.')))),
        if (_image != null) Padding(padding: const EdgeInsets.all(16),
          child: Text(_remaining > 0
            ? 'Kapatınca bir kez daha açabilirsin.\nEn fazla 2 dakika görüntülenir.'
            : 'Kapatınca tekrar açılamaz.\nEn fazla 2 dakika görüntülenir.',
            textAlign: TextAlign.center)),
      ])),
    ),
  );
}
