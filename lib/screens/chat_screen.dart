import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherDisplayName;
  final String? sourceType;
  final String? sourceId;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    this.otherDisplayName = 'Kullanıcı',
    this.sourceType,
    this.sourceId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _threadId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final id = await ChatService.instance.ensureDirectThread(
        widget.otherUserId,
        sourceType: widget.sourceType,
        sourceId: widget.sourceId,
      );
      if (!mounted) return;
      setState(() {
        _threadId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final id = _threadId;
    final text = _controller.text;
    if (id == null || text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(
        threadId: id,
        otherUserId: widget.otherUserId,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showSafetyMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121416),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text(
                'Kullanıcıyı bildir',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text(
                'Kullanıcıyı engelle',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );

    if (action == 'report') {
      await ChatService.instance.reportUser(
        otherUserId: widget.otherUserId,
        reason: 'chat_report',
        threadId: _threadId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirimin inceleme için kaydedildi.')),
        );
      }
    } else if (action == 'block') {
      await ChatService.instance.blockUser(widget.otherUserId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: Text(widget.otherDisplayName),
        actions: [
          IconButton(
            onPressed: _showSafetyMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: ChatService.instance.messages(_threadId!),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const <ChatMessage>[];
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFB7BCC2),
                          ),
                        );
                      }
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'İlk mesajı gönder. Buluşma detaylarını paylaşırken kişisel adres veya hassas bilgi göndermemeye dikkat et.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final mine = message.senderId == myId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 310),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFB7BCC2)
                                    : const Color(0xFF1C232D),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  color: mine ? Colors.black : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF121820),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 1500,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Mesaj yaz...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: const Color(0xFF1C232D),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFB7BCC2),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
