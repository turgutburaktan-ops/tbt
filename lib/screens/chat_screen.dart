import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/chat_voice_message.dart';
import '../widgets/firebase_media_image.dart';
import 'post_detail_screen.dart';
import 'social_events_screen.dart';

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  String? _threadId;
  Stream<ChatThread?>? _threadStream;
  Stream<List<ChatMessage>>? _messagesStream;
  bool _loading = true;
  bool _sending = false;
  bool _sendingMedia = false;
  bool _searching = false;
  bool _typingSent = false;
  String? _error;
  ChatMessage? _replyTo;
  String? _lastMarkedMessageId;
  Timer? _typingTimer;

  static const _bg = Color(0xFF090B0E);
  static const _panel = Color(0xFF11161C);
  static const _mine = Color(0xFF20303A);
  static const _other = Color(0xFF171C22);
  static const _accent = Color(0xFF8CD9FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleTypingChanged);
    _prepare();
    Future.microtask(() => ChatService.instance.setPresence(true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final online = state == AppLifecycleState.resumed;
    Future.microtask(() => ChatService.instance.setPresence(online));
    if (!online) _stopTyping();
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
        _threadStream = ChatService.instance.watchThread(id);
        _messagesStream = ChatService.instance.messages(id);
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

  void _handleTypingChanged() {
    final id = _threadId;
    if (id == null) return;
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      Future.microtask(() async {
        try {
          await ChatService.instance.setTyping(id, true);
        } catch (_) {}
      });
    }
    _typingTimer?.cancel();
    if (!hasText) {
      _stopTyping();
      return;
    }
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    final id = _threadId;
    if (id == null) return;
    Future.microtask(() async {
      try {
        await ChatService.instance.setTyping(id, false);
      } catch (_) {}
    });
  }

  Future<void> _send() async {
    final id = _threadId;
    final text = _controller.text.trim();
    if (id == null || text.isEmpty || _sending || _sendingMedia) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(
        threadId: id,
        otherUserId: widget.otherUserId,
        text: text,
        replyTo: _replyTo,
      );
      _controller.clear();
      _stopTyping();
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(Uint8List bytes, int durationMs) async {
    final id = _threadId;
    if (id == null || _sending || _sendingMedia) return;
    setState(() => _sendingMedia = true);
    try {
      await ChatService.instance.sendAudioMessage(
        threadId: id,
        otherUserId: widget.otherUserId,
        bytes: bytes,
        durationMs: durationMs,
        replyTo: _replyTo,
      );
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
  }

  Future<void> _showVoiceRecorderSheet() async {
    if (_sending || _sendingMedia) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF12171D),
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq_rounded, size: 34, color: _accent),
            const SizedBox(height: 10),
            const Text(
              'Sesli Mesaj',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Mikrofona dokunarak kaydı başlatabilir veya basılı tutup bırakarak doğrudan gönderebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.35),
            ),
            const SizedBox(height: 18),
            ChatVoiceRecordButton(
              disabled: _sending || _sendingMedia,
              onRecorded: (bytes, durationMs) async {
                await _sendVoice(bytes, durationMs);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              onError: _showError,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF12171D),
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Gönder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _attachChoice(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    onTap: () => Navigator.pop(sheetContext, 'gallery'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _attachChoice(
                    icon: Icons.photo_camera_outlined,
                    label: 'Kamera',
                    onTap: () => Navigator.pop(sheetContext, 'camera'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _attachChoice(
                    icon: Icons.mic_none_rounded,
                    label: 'Ses',
                    onTap: () => Navigator.pop(sheetContext, 'voice'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'gallery') {
      await _pickAndSendImage(ImageSource.gallery);
    } else if (action == 'camera') {
      await _pickAndSendImage(ImageSource.camera);
    } else if (action == 'voice') {
      await _showVoiceRecorderSheet();
    }
  }

  Widget _attachChoice({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2027),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 27),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );

  Future<void> _react(ChatMessage message, String emoji) async {
    final id = _threadId;
    if (id == null) return;
    try {
      await ChatService.instance.toggleReaction(
        threadId: id,
        messageId: message.id,
        emoji: emoji,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showMessageActions(ChatMessage message, bool mine) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12171D),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['❤️', '😂', '🔥', '👏', '👍', '😮']
                    .map(
                      (emoji) => InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.pop(sheetContext, 'react:$emoji'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Yanıtla'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            if (!message.isImage && !message.isShare && !message.isAudio)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Kopyala'),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Herkesten geri al',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action.startsWith('react:')) {
      await _react(message, action.substring(6));
    } else if (action == 'reply') {
      setState(() => _replyTo = message);
      _focusNode.requestFocus();
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj kopyalandı.')),
        );
      }
    } else if (action == 'delete') {
      try {
        await ChatService.instance.deleteForEveryone(
          threadId: _threadId!,
          messageId: message.id,
        );
      } catch (e) {
        _showError(e);
      }
    }
  }

  void _markReadFromMessages(List<ChatMessage> messages, String myId) {
    if (messages.isEmpty || _threadId == null) return;
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

  String _lastSeenLabel(DateTime? value) {
    if (value == null) return 'çevrimdışı';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return 'az önce aktifti';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce aktifti';
    if (diff.inHours < 24) return '${diff.inHours} sa önce aktifti';
    return '${diff.inDays} gün önce aktifti';
  }

  bool _isSeen(ChatMessage message, ChatThread? thread) {
    final readAt = thread?.lastReadAt[widget.otherUserId];
    final sentAt = message.createdAt;
    if (readAt == null || sentAt == null) return false;
    return !readAt.isBefore(sentAt);
  }

  bool _otherTyping(ChatThread? thread) {
    final at = thread?.typingAt[widget.otherUserId];
    if (at == null) return false;
    return DateTime.now().difference(at.toLocal()) < const Duration(seconds: 6);
  }

  void _openImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: FirebaseMediaImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSharedContent(ChatMessage message) async {
    final id = message.sharedId?.trim() ?? '';
    if (id.isEmpty) {
      _showError(Exception('Paylaşılan içeriğin kimliği bulunamadı.'));
      return;
    }
    if (message.sharedType == 'event') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SocialEventsScreen()),
      );
      return;
    }
    if (message.sharedType == 'venue' || message.sharedType == 'spot') {
      final uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': id,
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Mekan haritada açılamadı.');
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!snap.exists || snap.data() == null) {
        throw Exception('Bu gönderi artık mevcut değil.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: <String, dynamic>{...snap.data()!, 'id': snap.id},
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Widget _replyPreview(ChatMessage message, bool mine) {
    if (!message.hasReply) return const SizedBox.shrink();
    final repliedToMe =
        message.replySenderId == FirebaseAuth.instance.currentUser?.uid;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _accent, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repliedToMe ? 'Sen' : widget.otherDisplayName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyText ?? 'Mesaj',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _shareCard(ChatMessage message) {
    final legacyTitle = message.text
        .split('\n')
        .first
        .replaceAll('📷', '')
        .replaceAll('▶️', '')
        .trim();
    final title =
        (message.sharedTitle ??
                (message.isLegacyShare ? legacyTitle : message.text))
            .trim();
    final imageUrl = message.sharedImageUrl?.trim() ?? '';
    final canOpen = message.sharedId?.trim().isNotEmpty ?? false;
    final icon = message.sharedType == 'event'
        ? Icons.event_outlined
        : message.sharedType == 'venue' || message.sharedType == 'spot'
        ? Icons.place_outlined
        : message.sharedType == 'reel'
        ? Icons.play_circle_outline_rounded
        : Icons.photo_library_outlined;
    final typeLabel = message.sharedType == 'event'
        ? 'Etkinlik'
        : message.sharedType == 'venue'
        ? 'Mekan'
        : message.sharedType == 'spot'
        ? 'Çekim noktası'
        : message.sharedType == 'reel'
        ? 'Reels'
        : 'Gönderi';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: canOpen ? () => _openSharedContent(message) : null,
      child: Container(
        width: 248,
        decoration: BoxDecoration(
          color: const Color(0xFF11171D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 138,
                width: double.infinity,
                child: FirebaseMediaImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: const ColoredBox(color: Color(0xFF1A2027)),
                ),
              )
            else
              Container(
                height: 82,
                width: double.infinity,
                alignment: Alignment.center,
                color: const Color(0xFF18212A),
                child: Icon(icon, size: 34, color: _accent),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 3),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: _accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title.isEmpty ? typeLabel : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 12, 10),
              child: Text(
                canOpen ? '$typeLabel · Açmak için dokun' : typeLabel,
                style: const TextStyle(
                  color: Colors.white45,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionBar(Map<String, String> reactions) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: counts.entries
          .map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF20262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _messageBubble({
    required ChatMessage message,
    required bool mine,
    required bool seen,
    required bool removed,
    required Map<String, String> reactions,
  }) {
    final time = _timeLabel(message.createdAt);
    if (removed) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF14181D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Text(
            'Mesaj geri alındı',
            style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final mediaLike = message.isImage || message.isShare;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: () => _react(message, '❤️'),
        onLongPress: () => _showMessageActions(message, mine),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .78,
          ),
          margin: EdgeInsets.only(bottom: reactions.isEmpty ? 8 : 4),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: mediaLike
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.fromLTRB(13, 9, 11, 6),
                decoration: BoxDecoration(
                  color: mine ? _mine : _other,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 18),
                  ),
                  border: Border.all(
                    color: mine
                        ? _accent.withValues(alpha: .18)
                        : Colors.white.withValues(alpha: .06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.hasReply)
                      Padding(
                        padding: mediaLike
                            ? const EdgeInsets.fromLTRB(5, 5, 5, 0)
                            : EdgeInsets.zero,
                        child: _replyPreview(message, mine),
                      ),
                    if (message.isImage)
                      GestureDetector(
                        onTap: () => _openImage(message.mediaUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 238,
                            height: 246,
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
                    else if (message.isAudio)
                      ChatAudioBubble(
                        url: message.mediaUrl!,
                        durationMs: message.durationMs,
                        mine: mine,
                      )
                    else if (message.isShare)
                      _shareCard(message)
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.2,
                            height: 1.28,
                          ),
                        ),
                      ),
                    Padding(
                      padding: mediaLike
                          ? const EdgeInsets.fromLTRB(7, 5, 7, 3)
                          : const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white45,
                              fontSize: 10.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 4),
                            Icon(
                              seen ? Icons.done_all_rounded : Icons.done_rounded,
                              size: 14,
                              color: seen ? _accent : Colors.white38,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 3),
                _reactionBar(reactions),
                const SizedBox(height: 5),
              ],
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
        final online = data['isOnline'] == true;
        final raw = data['lastSeenAt'];
        final lastSeen = raw is Timestamp ? raw.toDate() : null;
        return Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 39,
                  height: 39,
                  child: ClipOval(
                    child: FirebaseMediaImage(
                      imageUrl: photoUrl,
                      fallbackStoragePaths:
                          FirebaseMediaImage.avatarPaths(widget.otherUserId),
                      fit: BoxFit.cover,
                      errorWidget: const ColoredBox(
                        color: Color(0xFF20252B),
                        child: Center(child: Icon(Icons.person_rounded, size: 21)),
                      ),
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF55D68B),
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg, width: 2),
                      ),
                    ),
                  ),
              ],
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
                      fontSize: 15.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    online ? 'çevrimiçi' : _lastSeenLabel(lastSeen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: online ? const Color(0xFF55D68B) : Colors.white45,
                      fontSize: 11.2,
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

  Widget _searchBar() {
    if (!_searching) return const SizedBox.shrink();
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Sohbette ara...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searching = false);
            },
            icon: const Icon(Icons.close_rounded),
          ),
          filled: true,
          fillColor: const Color(0xFF171C22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _typingIndicator(ChatThread? thread) {
    if (!_otherTyping(thread)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      color: _bg,
      child: Text(
        '${widget.otherDisplayName} yazıyor…',
        style: const TextStyle(
          color: _accent,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        decoration: const BoxDecoration(
          color: _panel,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                padding: const EdgeInsets.fromLTRB(11, 8, 4, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 17, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yanıtlıyorsun',
                            style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            _replyTo!.isImage
                                ? 'Fotoğraf'
                                : _replyTo!.isAudio
                                ? 'Sesli mesaj'
                                : _replyTo!.isShare
                                ? (_replyTo!.sharedTitle ?? 'Paylaşım')
                                : _replyTo!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white45, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Fotoğraf veya ses gönder',
                  style: IconButton.styleFrom(
                    foregroundColor: _accent,
                    backgroundColor: const Color(0xFF1A2027),
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
                    style: const TextStyle(color: Colors.white, fontSize: 15.2),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Mesaj yaz…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF171C22),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(23),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    if (!hasText) {
                      return ChatVoiceRecordButton(
                        disabled: _sending || _sendingMedia,
                        onRecorded: _sendVoice,
                        onError: _showError,
                      );
                    }
                    return IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: const Color(0xFF081016),
                      ),
                      onPressed: (_sending || _sendingMedia) ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSafetyMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12171D),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Kullanıcıyı bildir'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Kullanıcıyı engelle'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
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
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _controller.removeListener(_handleTypingChanged);
    _stopTyping();
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        toolbarHeight: 62,
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: _conversationHeader(),
        actions: [
          IconButton(
            tooltip: 'Sohbette ara',
            onPressed: () => setState(() => _searching = !_searching),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: _showSafetyMenu,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
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
          : StreamBuilder<ChatThread?>(
              stream: _threadStream,
              builder: (context, threadSnapshot) {
                final thread = threadSnapshot.data;
                return Column(
                  children: [
                    _searchBar(),
                    Expanded(
                      child: StreamBuilder<List<ChatMessage>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: _accent),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Mesajlar yüklenemedi.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              ),
                            );
                          }
                          final allMessages = snapshot.data ?? const <ChatMessage>[];
                          _markReadFromMessages(allMessages, myId);
                          final query = _searchController.text.trim().toLowerCase();
                          final messages = query.isEmpty
                              ? allMessages
                              : allMessages.where((message) {
                                  final haystack =
                                      '${message.text} ${message.sharedTitle ?? ''}'
                                          .toLowerCase();
                                  return haystack.contains(query);
                                }).toList(growable: false);

                          if (messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      query.isEmpty
                                          ? Icons.forum_outlined
                                          : Icons.search_off_rounded,
                                      size: 44,
                                      color: Colors.white20,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      query.isEmpty
                                          ? 'İlk mesajı gönder'
                                          : 'Eşleşen mesaj yok',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (query.isEmpty) ...[
                                      const SizedBox(height: 5),
                                      const Text(
                                        'Fotoğraf, sesli mesaj ve içerik paylaşabilirsin.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white45),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            reverse: true,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(11, 13, 11, 9),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final mine = message.senderId == myId;
                              final removed =
                                  message.deleted ||
                                  (thread?.deletedMessageIds.contains(message.id) ??
                                      false);
                              final reactions =
                                  thread?.messageReactions[message.id] ??
                                  message.reactions;
                              return KeyedSubtree(
                                key: ValueKey('chat-message-${message.id}'),
                                child: _messageBubble(
                                  message: message,
                                  mine: mine,
                                  seen: mine && _isSeen(message, thread),
                                  removed: removed,
                                  reactions: reactions,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _typingIndicator(thread),
                    _composer(),
                  ],
                );
              },
            ),
    );
  }
}
