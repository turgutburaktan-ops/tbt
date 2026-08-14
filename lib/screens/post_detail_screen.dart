import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/post_service.dart';
import '../services/spot_repository.dart';
import '../widgets/content_engagement_bar.dart';
import '../widgets/mention_text.dart';
import 'spot_detail_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> _post;
  bool _openingSpot = false;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
  }

  String _dateLabel(dynamic value) {
    if (value is! Timestamp) return '';
    final d = value.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  bool get _isMine {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _post['userId']?.toString();
  }

  Future<void> _openSpot(String spotName) async {
    if (_openingSpot || spotName.trim().isEmpty) return;
    setState(() => _openingSpot = true);
    try {
      final results = await SpotRepository.instance.search(spotName, limit: 2000);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu çekim noktası kartı henüz bulunamadı.'),
          ),
        );
        return;
      }
      final exact = results.where(
        (spot) =>
            spot.name.trim().toLowerCase() == spotName.trim().toLowerCase(),
      );
      final spot = exact.isNotEmpty ? exact.first : results.first;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
      );
    } finally {
      if (mounted) setState(() => _openingSpot = false);
    }
  }

  Future<void> _edit() async {
    final captionController = TextEditingController(
      text: (_post['caption'] ?? '').toString(),
    );
    final spotController = TextEditingController(
      text: (_post['spotName'] ?? '').toString(),
    );

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0F0B1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gönderiyi Düzenle',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: captionController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spotController,
                decoration: const InputDecoration(
                  labelText: 'Konum / çekim noktası',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (save == true) {
      try {
        await PostService.instance.updatePost(
          postId: (_post['id'] ?? '').toString(),
          caption: captionController.text,
          spotName: spotController.text,
        );
        if (!mounted) return;
        setState(() {
          _post['caption'] = captionController.text.trim();
          _post['spotName'] = spotController.text.trim();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    }

    captionController.dispose();
    spotController.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141126),
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu paylaşım kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PostService.instance.deletePost(
        postId: (_post['id'] ?? '').toString(),
        storagePath: (_post['storagePath'] ?? '').toString(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(sheetContext);
                _edit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Sil',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (_post['imageUrl'] ?? '').toString();
    final caption = (_post['caption'] ?? '').toString().trim();
    final spot = (_post['spotName'] ??
            _post['locationName'] ??
            _post['location'] ??
            '')
        .toString()
        .trim();
    final userName = (_post['userName'] ?? 'Fotoğrafçı').toString();
    final date = _dateLabel(_post['createdAt']);

    return Scaffold(
      backgroundColor: const Color(0xFF090812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090812),
        foregroundColor: Colors.white,
        title: const Text('Paylaşım'),
        actions: [
          if (_isMine)
            IconButton(
              tooltip: 'Gönderi seçenekleri',
              onPressed: _showMenu,
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9F7AEA),
                  Color(0xFF6D28D9),
                  Color(0xFF3B1B68),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x338B5CF6),
                  blurRadius: 24,
                  spreadRadius: -10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0A15),
                borderRadius: BorderRadius.circular(25),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .1,
                                ),
                              ),
                              if (spot.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: _openingSpot
                                      ? null
                                      : () => _openSpot(spot),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 14,
                                        color: Color(0xFFC4B5FD),
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          spot,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFB9B1C8),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 17,
                          color: Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.black,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: imageUrl.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 70,
                                color: Colors.white30,
                              ),
                            )
                          : InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              panEnabled: true,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox.expand(
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 70,
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: ContentEngagementBar(
              collection: 'posts',
              contentId: (_post['id'] ?? '').toString(),
              ownerId: (_post['userId'] ?? '').toString(),
              title: caption.isEmpty ? 'Fotoğraf paylaşımı' : caption,
              sourceType: 'post',
              showTagAction: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty)
                  MentionText(
                    text: caption,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.5,
                      fontSize: 14.5,
                    ),
                    mentionStyle: const TextStyle(
                      color: Color(0xFFA78BFA),
                      height: 1.5,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
