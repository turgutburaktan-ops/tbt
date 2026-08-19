import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/community_profile_screen.dart';
import '../screens/event_deep_link_screen.dart';
import 'invite_link_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  final Set<String> _recent = <String>{};

  void start(GlobalKey<NavigatorState> navigatorKey) {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _open(uri, navigatorKey);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _open(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    final target = InviteLinkService.instance.parse(uri);
    if (target == null) return;

    final key = uri.toString();
    if (_recent.contains(key)) return;
    _recent.add(key);
    Future<void>.delayed(const Duration(seconds: 2), () => _recent.remove(key));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      switch (target.type) {
        case 'community':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => CommunityProfileScreen(communityId: target.id),
            ),
          );
          break;
        case 'event':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => EventDeepLinkScreen(eventId: target.id),
            ),
          );
          break;
      }
    });
  }
}
