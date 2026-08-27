import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/community_profile_screen.dart';
import '../screens/event_deep_link_screen.dart';
import '../screens/post_deep_link_screen.dart';
import '../screens/user_profile_screen.dart';
import 'invite_link_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  final Set<String> _recent = <String>{};
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _started = false;

  void start(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_started) return;
    _started = true;

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _open(uri),
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('Deep link stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
      cancelOnError: false,
    );
    unawaited(_openInitialLink());
  }

  Future<void> _openInitialLink() async {
    try {
      final uri = await _appLinks
          .getInitialLink()
          .timeout(const Duration(seconds: 3));
      if (uri != null) _open(uri);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Initial deep link skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _navigatorKey = null;
    _started = false;
    _recent.clear();
  }

  void _open(Uri uri) {
    final navigatorKey = _navigatorKey;
    if (navigatorKey == null) return;
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
        case 'profile':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: target.id),
            ),
          );
          break;
        case 'post':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => PostDeepLinkScreen(postId: target.id),
            ),
          );
          break;
      }
    });
  }
}
