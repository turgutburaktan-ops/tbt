import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> notificationReplyBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NotificationReplyService.reply(response);
}

class NotificationReplyService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;
  static Future<void> Function(Map<String, dynamic>)? _onOpen;
  static const _action = AndroidNotificationAction(
    'tbt_reply',
    'Yanıtla',
    inputs: [AndroidNotificationActionInput(label: 'Mesaj')],
    showsUserInterface: false,
    cancelNotification: false,
  );
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static bool isChat(Map<String, dynamic> data) =>
      ['message', 'group_message'].contains(data['type']);
  static Map<String, dynamic>? decode(String? payload) {
    try {
      final value = jsonDecode(payload ?? '');
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  static int notificationNumber(String id) =>
      id.codeUnits.fold<int>(0, (n, c) => ((n * 31) + c) & 0x7fffffff);
  static Future<void> initialize({
    Future<void> Function(Map<String, dynamic>)? onOpen,
  }) async {
    if (!supported) return;
    if (onOpen != null) _onOpen = onOpen;
    if (ready) return;
    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_tbt'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'TBT_CHAT',
              actions: [
                DarwinNotificationAction.text(
                  'tbt_reply',
                  'Yanıtla',
                  buttonTitle: 'Gönder',
                  placeholder: 'Mesaj',
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'tbt_reply') {
          unawaited(reply(response));
          return;
        }
        final data = decode(response.payload);
        if (data != null)
          unawaited(_onOpen?.call(data) ?? Future<void>.value());
      },
      onDidReceiveBackgroundNotificationResponse: notificationReplyBackground,
    );
    ready = true;
    if (onOpen != null) {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      final data = decode(response?.payload);
      if (launch?.didNotificationLaunchApp == true &&
          data != null &&
          response?.actionId != 'tbt_reply') {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(onOpen(data)),
        );
      }
    }
  }

  static Future<void> show(
    Map<String, dynamic> data, {
    String? status,
    bool sent = false,
  }) async {
    if (!supported || !isChat(data)) return;
    await initialize();
    await _plugin.show(
      notificationNumber('${data['notificationId']}'),
      '${data['title'] ?? 'TBT'}',
      status ?? '${data['body'] ?? ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tbt_messages_reply',
          'Mesajlar',
          channelDescription: 'Sohbet mesajları ve hızlı yanıtlar',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: '${data['sourceId']}',
          onlyAlertOnce: status != null,
          actions: sent ? [] : [_action],
          styleInformation: BigTextStyleInformation(
            status ?? '${data['body'] ?? ''}',
          ),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: sent ? null : 'TBT_CHAT',
          threadIdentifier: '${data['sourceId']}',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> reply(NotificationResponse response) async {
    final data = decode(response.payload), text = response.input?.trim() ?? '';
    if (data == null || text.isEmpty || response.actionId != 'tbt_reply')
      return;
    try {
      if (Firebase.apps.isEmpty)
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      final auth = FirebaseAuth.instance;
      final user =
          auth.currentUser ??
          await auth.authStateChanges().first.timeout(
            const Duration(seconds: 5),
          );
      if (user == null || user.uid != data['recipientId'])
        throw StateError('account-changed');
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(
            'replyToNotification',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call({
            'threadId': data['sourceId'],
            'notificationId': data['notificationId'],
            'text': text,
          });
      await show(data, status: 'Yanıt gönderildi', sent: true);
    } catch (_) {
      await show(
        data,
        status:
            'Yanıt doğrulanamadı. Aynı metinle tekrar deneyebilirsin veya sohbeti açabilirsin.\nTaslak: $text',
      );
    }
  }
}
