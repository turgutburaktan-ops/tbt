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

  const ChatThread({
    required this.id,
    required this.memberIds,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    this.sourceType,
    this.sourceId,
    this.lastReadAt = const <String, DateTime?>{},
  });

  factory ChatThread.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawMembers = data['memberIds'];
    final rawReadAt = data['lastReadAt'];
    final readAt = <String, DateTime?>{};
    if (rawReadAt is Map) {
      for (final entry in rawReadAt.entries) {
        final value = entry.value;
        readAt[entry.key.toString()] = value is Timestamp
            ? value.toDate()
            : null;
      }
    }
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
      lastReadAt: readAt,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String type;
  final String? mediaUrl;
  final String? replyToId;
  final String? replyText;
  final String? replySenderId;
  final DateTime? createdAt;
  final bool deleted;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    this.replyToId,
    this.replyText,
    this.replySenderId,
    required this.createdAt,
    required this.deleted,
  });

  bool get isImage => type == 'image' && (mediaUrl?.isNotEmpty ?? false);
  bool get hasReply => (replyToId?.isNotEmpty ?? false);

  factory ChatMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      mediaUrl: data['mediaUrl']?.toString(),
      replyToId: data['replyToId']?.toString(),
      replyText: data['replyText']?.toString(),
      replySenderId: data['replySenderId']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
    );
  }
}
