import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/community_profile_screen.dart';
import '../screens/event_deep_link_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/user_profile_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _recentOpenedMessages = <String>{};

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastSavedToken;
  DateTime? _lastActivityWrite;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _observerAdded = false;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_initialized) return Future.value();
    final running = _initializing;
    if (running != null) return running;

    final request = _initializeInternal(navigatorKey);
    _initializing = request;
    return request.whenComplete(() {
      if (identical(_initializing, request)) _initializing = null;
    });
  }

  Future<void> _initializeInternal(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (!_observerAdded) {
      WidgetsBinding.instance.addObserver(this);
      _observerAdded = true;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging
        .setAutoInitEnabled(true)
        .timeout(const Duration(seconds: 4));
    final settings = await _messaging
        .requestPermission(alert: true, badge: true, sound: true)
        .timeout(const Duration(seconds: 8));
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _initialized = true;
      return;
    }

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _lastSavedToken = null;
        _lastActivityWrite = null;
        return;
      }
      unawaited(_refreshRegistration());
    });

    await _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_saveToken(token)),
      onError: (_) {},
      cancelOnError: false,
    );

    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      (message) {
        final context = navigatorKey.currentContext;
        if (context == null) return;
        final title = message.notification?.title ?? 'Yeni bildirim';
        final body = message.notification?.body ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body.isEmpty ? title : '$title\n$body'),
            action: message.data.isEmpty
                ? null
                : SnackBarAction(
                    label: 'Aç',
                    onPressed: () => unawaited(_openMessage(message)),
                  ),
          ),
        );
      },
      onError: (_) {},
      cancelOnError: false,
    );

    await _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openMessage(message)),
      onError: (_) {},
      cancelOnError: false,
    );

    try {
      final initial = await _messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 4));
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_openMessage(initial)),
        );
      }
    } catch (_) {}

    if (_auth.currentUser != null) {
      await _refreshRegistration();
    }
    _initialized = true;
  }

  Future<void> _refreshRegistration() async {
    await Future.wait<void>([
      _markActive(force: true),
      _saveCurrentToken(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_markActive());
    }
  }

  Future<void> _markActive({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastActivityWrite != null &&
        now.difference(_lastActivityWrite!) < const Duration(minutes: 15)) {
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'lastActivePlatform': _platformName,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      _lastActivityWrite = now;
    } catch (_) {
      // Activity tracking must never block the app.
    }
  }

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
      );
      if (token != null && token.isNotEmpty) await _saveToken(token);
    } catch (_) {}
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null || token.isEmpty || token == _lastSavedToken) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('push_tokens')
          .doc(token)
          .set({
            'token': token,
            'platform': _platformName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
      _lastSavedToken = token;
      await _markActive(force: true);
    } catch (_) {
      // Keep _lastSavedToken unchanged so the next resume/auth event retries.
    }
  }

  Future<Map<String, dynamic>> _profile(String userId) async {
    if (userId.isEmpty) return const <String, dynamic>{};
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 4));
      return doc.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  bool _claimOpen(RemoteMessage message) {
    final key = message.messageId ??
        '${message.data['type']}|${message.data['sourceId']}|${message.data['actorId']}|${message.data['eventId']}';
    if (_recentOpenedMessages.contains(key)) return false;
    _recentOpenedMessages.add(key);
    Future<void>.delayed(
      const Duration(seconds: 3),
      () => _recentOpenedMessages.remove(key),
    );
    return true;
  }

  Future<void> _openMessage(RemoteMessage message) async {
    if (!_claimOpen(message)) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    unawaited(_markActive(force: true));

    final type = (message.data['type'] ?? '').toString().trim();
    final sourceId = (message.data['sourceId'] ?? '').toString().trim();
    final actorId = (message.data['actorId'] ?? '').toString().trim();
    final eventId = (message.data['eventId'] ?? '').toString().trim();
    final communityId = (message.data['communityId'] ?? '').toString().trim();

    if (eventId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => EventDeepLinkScreen(eventId: eventId),
        ),
      );
      return;
    }
    if (communityId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CommunityProfileScreen(communityId: communityId),
        ),
      );
      return;
    }
    if (type == 'message' && actorId.isNotEmpty) {
      final data = await _profile(actorId);
      final displayName =
          (data['displayName'] ?? data['username'] ?? 'Kullanıcı').toString();
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(otherUserId: actorId, otherDisplayName: displayName),
        ),
      );
      return;
    }
    if (type.startsWith('post_') && sourceId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('posts')
            .doc(sourceId)
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) =>
                  PostDetailScreen(post: {...?doc.data(), 'id': doc.id}),
            ),
          );
        }
      } catch (_) {}
      return;
    }
    if ((type == 'follow' || type.startsWith('story_')) && actorId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: actorId)),
      );
      return;
    }
    if (type == 'reengagement') {
      navigator.pushNamed('/campus');
    }
  }

  void dispose() {
    if (_observerAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAdded = false;
    }
    _tokenSub?.cancel();
    _authSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    _tokenSub = null;
    _authSub = null;
    _foregroundSub = null;
    _openedSub = null;
    _navigatorKey = null;
    _initialized = false;
    _initializing = null;
    _recentOpenedMessages.clear();
  }
}
