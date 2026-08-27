import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id;
  final List<String> memberIds;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final String? sourceType;
  final String? sourceId;
  final Map<String, DateTime?> lastReadAt;
  final Map<String, DateTime?> typingAt;
  final Map<String, Map<String, String>> messageReactions;
  final Set<String> deletedMessageIds;

  const ChatThread({
    required this.id,
    required this.memberIds,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    this.sourceType,
    this.sourceId,
    this.lastReadAt = const <String, DateTime?>{},
    this.typingAt = const <String, DateTime?>{},
    this.messageReactions = const <String, Map<String, String>>{},
    this.deletedMessageIds = const <String>{},
  });

  static Map<String, DateTime?> _timestampMap(dynamic raw) {
    final result = <String, DateTime?>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        result[entry.key.toString()] = value is Timestamp
            ? value.toDate()
            : null;
      }
    }
    return result;
  }

  static Map<String, Map<String, String>> _reactionMap(dynamic raw) {
    final result = <String, Map<String, String>>{};
    if (raw is Map) {
      for (final messageEntry in raw.entries) {
        final byUser = <String, String>{};
        final value = messageEntry.value;
        if (value is Map) {
          for (final userEntry in value.entries) {
            final emoji = userEntry.value?.toString() ?? '';
            if (emoji.isNotEmpty) byUser[userEntry.key.toString()] = emoji;
          }
        }
        if (byUser.isNotEmpty) result[messageEntry.key.toString()] = byUser;
      }
    }
    return result;
  }

  factory ChatThread.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawMembers = data['memberIds'];
    final rawDeleted = data['deletedMessageIds'];
    return ChatThread(
      id: doc.id,
      memberIds: rawMembers is List
          ? rawMembers.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      sourceType: data['sourceType']?.toString(),
      sourceId: data['sourceId']?.toString(),
      lastReadAt: _timestampMap(data['lastReadAt']),
      typingAt: _timestampMap(data['typingAt']),
      messageReactions: _reactionMap(data['messageReactions']),
      deletedMessageIds: rawDeleted is List
          ? rawDeleted.map((e) => e.toString()).toSet()
          : const <String>{},
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String type;
  final String? mediaUrl;
  final int? durationMs;
  final String? replyToId;
  final String? replyText;
  final String? replySenderId;
  final DateTime? createdAt;
  final bool deleted;
  final DateTime? deletedAt;
  final Map<String, String> reactions;
  final String? sharedType;
  final String? sharedId;
  final String? sharedTitle;
  final String? sharedImageUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    this.durationMs,
    this.replyToId,
    this.replyText,
    this.replySenderId,
    required this.createdAt,
    required this.deleted,
    this.deletedAt,
    this.reactions = const <String, String>{},
    this.sharedType,
    this.sharedId,
    this.sharedTitle,
    this.sharedImageUrl,
  });

  bool get isImage => type == 'image' && (mediaUrl?.isNotEmpty ?? false);
  bool get isAudio => type == 'audio' && (mediaUrl?.isNotEmpty ?? false);
  bool get isLegacyShare {
    if (type != 'text') return false;
    final normalized = text.toLowerCase();
    return normalized.contains('paylaşımı') &&
        normalized.contains('uygulama içinden paylaşıldı');
  }

  bool get isShare => type == 'share' || isLegacyShare;
  bool get hasReply => (replyToId?.isNotEmpty ?? false);

  factory ChatMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawReactions = data['reactions'];
    final reactions = <String, String>{};
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        final emoji = entry.value?.toString() ?? '';
        if (emoji.isNotEmpty) reactions[entry.key.toString()] = emoji;
      }
    }
    final rawDuration = data['durationMs'];
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      mediaUrl: data['mediaUrl']?.toString(),
      durationMs: rawDuration is num ? rawDuration.toInt() : null,
      replyToId: data['replyToId']?.toString(),
      replyText: data['replyText']?.toString(),
      replySenderId: data['replySenderId']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      reactions: reactions,
      sharedType: data['sharedType']?.toString(),
      sharedId: data['sharedId']?.toString(),
      sharedTitle: data['sharedTitle']?.toString(),
      sharedImageUrl: data['sharedImageUrl']?.toString(),
    );
  }
}
