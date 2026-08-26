import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id;
  final List<String> memberIds;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final String? sourceType;
  final String? sourceId;

  const ChatThread({
    required this.id,
    required this.memberIds,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    this.sourceType,
    this.sourceId,
  });

  factory ChatThread.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawMembers = data['memberIds'];
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
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool deleted;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.deleted,
  });

  factory ChatMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
    );
  }
}
