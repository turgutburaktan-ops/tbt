import 'package:flutter/material.dart';

class VideoAudioSession extends ChangeNotifier {
  static final feed = VideoAudioSession();
  static final reels = VideoAudioSession();
  bool _muted = false;
  bool get muted => _muted;
  void setMuted(bool value) {
    if (value == _muted) return;
    _muted = value;
    notifyListeners();
  }

  void toggle() => setMuted(!_muted);
  void reset() => setMuted(false);
}

final videoRouteObserver = RouteObserver<PageRoute<dynamic>>();
