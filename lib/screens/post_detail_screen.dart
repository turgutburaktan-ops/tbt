import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/post_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> _post;

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

  Future<void> _edit() async {
    final captionController = TextEditingController(text: (_post['caption'] ?? '').toString());
    final spotController = TextEditingController(text: (_post['spotName'] ?? '').toString());

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D1117),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gönderiyi Düzenle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: captionController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Açıklama')),
              const SizedBox(height: 12),
              TextField(controller: spotController, decoration: const InputDecoration(labelText: 'Konum / çekim noktası')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
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
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu paylaşım kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.redAccent))),
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
      backgroundColor: const Color(0xFF151A22),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFFFFC107)),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(sheetContext);
                _edit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
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
    final spot = (_post['spotName'] ?? _post['locationName'] ?? _post['location'] ?? '').toString().trim();
    final userName = (_post['userName'] ?? 'Fotoğrafçı').toString();
    final date = _dateLabel(_post['createdAt']);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            color: Colors.black,
            constraints: const BoxConstraints(minHeight: 360, maxHeight: 620),
            child: imageUrl.isEmpty
                ? const Center(child: Icon(Icons.image_outlined, size: 70, color: Colors.white30))
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: true,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 70, color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF202833),
                      child: Icon(Icons.person, size: 18, color: Colors.white54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(caption, style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 15)),
                ],
                if (spot.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 19, color: Color(0xFFFFC107)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(spot, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
                    ],
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
