import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/community_profile_screen.dart';
import '../screens/event_deep_link_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
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

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.setAutoInitEnabled(true);
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _lastSavedToken = null;
        return;
      }
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        action: message.data.isEmpty ? null : SnackBarAction(label: 'Aç', onPressed: () => _openMessage(message)),
      ));
    });
    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openMessage(initial));
    if (_auth.currentUser != null) await _saveCurrentToken();
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null || token.isEmpty || token == _lastSavedToken) return;
    _lastSavedToken = token;
    await _firestore.collection('users').doc(user.uid).collection('push_tokens').doc(token).set({
      'token': token,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _openMessage(RemoteMessage message) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    final eventId = (message.data['eventId'] ?? '').toString().trim();
    final communityId = (message.data['communityId'] ?? '').toString().trim();
    if (eventId.isNotEmpty) {
      navigator.push(MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: eventId)));
    } else if (communityId.isNotEmpty) {
      navigator.push(MaterialPageRoute(builder: (_) => CommunityProfileScreen(communityId: communityId)));
    }
  }

  void dispose() {
    _tokenSub?.cancel();
    _authSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
  }
}
