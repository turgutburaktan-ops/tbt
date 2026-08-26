import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/invite_link_service.dart';
import 'community_profile_screen.dart';
import 'event_deep_link_screen.dart';

class InviteQrScannerScreen extends StatefulWidget {
  const InviteQrScannerScreen({super.key});

  @override
  State<InviteQrScannerScreen> createState() => _InviteQrScannerScreenState();
}

class _InviteQrScannerScreenState extends State<InviteQrScannerScreen> {
  bool _processing = false;

  Future<void> _handle(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue?.trim() ?? '';
    if (raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    final target = uri == null ? null : InviteLinkService.instance.parse(uri);
    if (target == null) {
      _show('Bu QR uygulamaya ait geçerli bir davet değil.');
      return;
    }

    setState(() => _processing = true);

    Widget? screen;
    if (target.type == 'community') {
      screen = CommunityProfileScreen(communityId: target.id);
    } else if (target.type == 'event') {
      screen = EventDeepLinkScreen(eventId: target.id);
    }

    if (screen == null) {
      setState(() => _processing = false);
      _show('Bu davet türü desteklenmiyor.');
      return;
    }

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Davet QR Oku'),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handle),
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB7BCC2), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 44,
            child: Text(
              'Topluluk veya etkinlik davet QR kodunu çerçevenin içine getir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
