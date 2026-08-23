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
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastSavedToken;
  DateTime? _lastActivityWrite;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.setAutoInitEnabled(true);
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _lastSavedToken = null;
        _lastActivityWrite = null;
        return;
      }
      await _markActive(force: true);
      await _saveCurrentToken();
    });
    _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen(_saveToken);
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
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
                  onPressed: () => _openMessage(message),
                ),
        ),
      );
    });
    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMessage(initial));
    }
    if (_auth.currentUser != null) {
      await _markActive(force: true);
      await _saveCurrentToken();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markActive();
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
    _lastActivityWrite = now;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'lastActivePlatform': _platformName,
      }, SetOptions(merge: true));
    } catch (_) {
      // Activity tracking must never block app startup or foregrounding.
    }
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) await _saveToken(token);
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
    _lastSavedToken = token;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('push_tokens')
        .doc(token)
        .set({
      'token': token,
      'platform': _platformName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _markActive(force: true);
  }

  Future<Map<String, dynamic>> _profile(String userId) async {
    if (userId.isEmpty) return const <String, dynamic>{};
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data() ?? const <String, dynamic>{};
  }

  Future<void> _openMessage(RemoteMessage message) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    await _markActive(force: true);

    final type = (message.data['type'] ?? '').toString().trim();
    final sourceId = (message.data['sourceId'] ?? '').toString().trim();
    final actorId = (message.data['actorId'] ?? '').toString().trim();
    final eventId = (message.data['eventId'] ?? '').toString().trim();
    final communityId = (message.data['communityId'] ?? '').toString().trim();

    if (eventId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: eventId)),
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
          builder: (_) => ChatScreen(
            otherUserId: actorId,
            otherDisplayName: displayName,
          ),
        ),
      );
      return;
    }
    if (type.startsWith('post_') && sourceId.isNotEmpty) {
      final doc = await _firestore.collection('posts').doc(sourceId).get();
      if (doc.exists) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: {...?doc.data(), 'id': doc.id},
            ),
          ),
        );
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _tokenSub?.cancel();
    _authSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
  }
}
