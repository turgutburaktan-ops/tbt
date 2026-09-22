import 'dart:convert';

/// Scope one notification to an account and conversation, never to its sender.
String chatNotificationIdentity(Map<String, dynamic> data) {
  final thread = (data['sourceId'] ?? '').toString().trim();
  return 'tbt.chat:${jsonEncode([
    (data['recipientId'] ?? '').toString(),
    thread.isEmpty ? 'notification:${data['notificationId']}' : thread,
  ])}';
}
