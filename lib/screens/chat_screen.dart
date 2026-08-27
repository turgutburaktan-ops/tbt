import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/firebase_media_image.dart';

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
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  String? _threadId;
  bool _loading = true;
  bool _sending = false;
  bool _sendingMedia = false;
  String? _error;
  ChatMessage? _replyTo;
  String? _lastMarkedMessageId;

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
      try {
        await ChatService.instance.markThreadRead(id);
      } catch (_) {}
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
    if (id == null || text.trim().isEmpty || _sending || _sendingMedia) return;

    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(
        threadId: id,
        otherUserId: widget.otherUserId,
        text: text,
        replyTo: _replyTo,
      );
      _controller.clear();
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final id = _threadId;
    if (id == null || _sending || _sendingMedia) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 2200,
      );
      if (picked == null) return;
      if (mounted) setState(() => _sendingMedia = true);
      final bytes = await picked.readAsBytes();
      await ChatService.instance.sendImageMessage(
        threadId: id,
        otherUserId: widget.otherUserId,
        bytes: bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
        replyTo: _replyTo,
      );
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _showAttachMenu() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF171A1E),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: _attachChoice(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _attachChoice(
                  icon: Icons.photo_camera_rounded,
                  label: 'Kamera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickAndSendImage(source);
  }

  Widget _attachChoice({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF20252C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171A1E),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Yanıtla'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (!message.isImage)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Kopyala'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
          ],
        ),
      ),
    );
    if (action == 'reply') {
      setState(() => _replyTo = message);
      _focusNode.requestFocus();
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı.')));
      }
    }
  }

  void _markReadFromMessages(List<ChatMessage> messages, String myId) {
    if (messages.isEmpty) return;
    final latest = messages.first;
    if (latest.senderId == myId || latest.id == _lastMarkedMessageId) return;
    _lastMarkedMessageId = latest.id;
    Future.microtask(() async {
      try {
        await ChatService.instance.markThreadRead(_threadId!);
      } catch (_) {}
    });
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool _isSeen(ChatMessage message, ChatThread? thread) {
    final readAt = thread?.lastReadAt[widget.otherUserId];
    final sentAt = message.createdAt;
    if (readAt == null || sentAt == null) return false;
    return !readAt.isBefore(sentAt);
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
              title: const Text('Kullanıcıyı bildir'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Kullanıcıyı engelle'),
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

  void _openImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: FirebaseMediaImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _replyPreview(ChatMessage message, bool mine) {
    if (!message.hasReply) return const SizedBox.shrink();
    final repliedToMe =
        message.replySenderId == FirebaseAuth.instance.currentUser?.uid;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: mine ? Colors.black12 : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: Colors.white54, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repliedToMe ? 'Sen' : widget.otherDisplayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: mine ? Colors.black87 : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyText ?? 'Mesaj',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: mine ? Colors.black54 : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble({
    required ChatMessage message,
    required bool mine,
    required bool seen,
  }) {
    final time = _timeLabel(message.createdAt);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: message.isImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.fromLTRB(13, 10, 11, 7),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFD7DADF) : const Color(0xFF1B222B),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 5),
              bottomRight: Radius.circular(mine ? 5 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.hasReply)
                Padding(
                  padding: message.isImage
                      ? const EdgeInsets.fromLTRB(5, 5, 5, 0)
                      : EdgeInsets.zero,
                  child: _replyPreview(message, mine),
                ),
              if (message.isImage)
                GestureDetector(
                  onTap: () => _openImage(message.mediaUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 245,
                      height: 260,
                      child: FirebaseMediaImage(
                        imageUrl: message.mediaUrl!,
                        fit: BoxFit.cover,
                        errorWidget: const ColoredBox(
                          color: Color(0xFF15191E),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: mine ? Colors.black : Colors.white,
                      fontSize: 15.5,
                      height: 1.25,
                    ),
                  ),
                ),
              Padding(
                padding: message.isImage
                    ? const EdgeInsets.fromLTRB(7, 5, 7, 3)
                    : const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: mine ? Colors.black45 : Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        seen ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: seen ? const Color(0xFF2878B5) : Colors.black38,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversationHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final photoUrl = (data['photoUrl'] ?? '').toString();
        final username = (data['username'] ?? '').toString().trim();
        return Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: ClipOval(
                child: FirebaseMediaImage(
                  imageUrl: photoUrl,
                  fallbackStoragePaths: FirebaseMediaImage.avatarPaths(
                    widget.otherUserId,
                  ),
                  fit: BoxFit.cover,
                  errorWidget: const ColoredBox(
                    color: Color(0xFF20252B),
                    child: Center(child: Icon(Icons.person_rounded, size: 21)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white46,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1217),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 9, 12, 0),
                padding: const EdgeInsets.fromLTRB(12, 9, 5, 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yanıtlıyorsun',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _replyTo!.isImage ? '📷 Fotoğraf' : _replyTo!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF202731),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _sendingMedia ? null : _showAttachMenu,
                    icon: _sendingMedia
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1500,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Mesaj yaz...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1B222B),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFD7DADF),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: (_sending || _sendingMedia) ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: _conversationHeader(),
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
                  child: StreamBuilder<ChatThread?>(
                    stream: ChatService.instance.watchThread(_threadId!),
                    builder: (context, threadSnapshot) {
                      final thread = threadSnapshot.data;
                      return StreamBuilder<List<ChatMessage>>(
                        stream: ChatService.instance.messages(_threadId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFB7BCC2),
                              ),
                            );
                          }
                          final messages =
                              snapshot.data ?? const <ChatMessage>[];
                          _markReadFromMessages(messages, myId);
                          if (messages.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 46,
                                      color: Colors.white24,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Sohbeti başlat',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Mesaj veya fotoğraf göndererek konuşmaya başlayabilirsin.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white46,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final mine = message.senderId == myId;
                              return _messageBubble(
                                message: message,
                                mine: mine,
                                seen: mine && _isSeen(message, thread),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                _composer(),
              ],
            ),
    );
  }
}
