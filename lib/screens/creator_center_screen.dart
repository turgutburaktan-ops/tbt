import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/creator_service.dart';
import '../services/invite_link_service.dart';
import 'post_deep_link_screen.dart';

class CreatorCenterScreen extends StatefulWidget {
  const CreatorCenterScreen({super.key});
  @override
  State<CreatorCenterScreen> createState() => _CreatorCenterScreenState();
}

class _CreatorCenterScreenState extends State<CreatorCenterScreen> {
  final _posts = <Map<String, dynamic>>[];
  List<String> _pins = [];
  String? _cursor, _error;
  bool _busy = false, _hasMore = false;
  int _followers = 0, _referrals = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await CreatorService.instance.studio('dashboard', {
        if (more) 'cursor': _cursor,
      });
      if (!mounted) return;
      setState(() {
        if (!more) _posts.clear();
        _posts.addAll(
          (data['posts'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _pins = List<String>.from(data['pinnedPostIds'] as List);
        _cursor = data['nextCursor'] as String?;
        _hasMore = _cursor != null;
        _followers = (data['followers'] as num).toInt();
        _referrals = (data['referrals'] as num).toInt();
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Creator Merkezi yüklenemedi. Yeniden deneyebilirsin.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pin(String id) async {
    if (_busy) return;
    final next = [..._pins];
    if (next.contains(id)) {
      next.remove(id);
    } else if (next.length < 3) {
      next.add(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce sabitlenmiş içeriklerden birini kaldır.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await CreatorService.instance.studio('pin', {'postIds': next});
      if (mounted) setState(() => _pins = next);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sabitleme kaydedilemedi. İçeriğin herkese açık olmalı.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guide(Map<String, dynamic> post) async {
    final controller = TextEditingController(
      text: (post['guideNote'] ?? '').toString(),
    );
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İmzalı rehber notun'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLength: 1500,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Bu rotada neyi önerirsin? Kendi deneyimini ekle.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    // The dialog can still be animating out; dispose after its transition.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    if (note == null || !mounted) return;
    try {
      await CreatorService.instance.studio('guide', {
        'postId': post['id'],
        'note': note,
      });
      if (mounted) setState(() => post['guideNote'] = note);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rehber notu kaydedilemedi.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1629),
    appBar: AppBar(title: const Text('Creator Merkezi')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'İçeriklerin, senin imzan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$_followers takipçi · $_referrals davet bağlantısından katılım',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null)
                Share.share(
                  'TBT’de paylaşımlarımı ve rehberlerimi keşfet.\n${InviteLinkService.instance.creatorProfileUri(uid)}',
                );
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('Kişisel Creator bağlantımı paylaş'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Profilinde ve karşılama sayfanda en fazla 3 içerik sabitle. Gönderiler, Reels ve imzalı rota rehberleri birlikte görünür.',
            ),
          ),
          const Text(
            'Görüntülenme ve içerikten profil ziyareti günlük tekil olarak sayılır. Kendi ziyaretlerin sayılmaz. Hikâye sayısı şu anda yayında olan paylaşımlardır.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (_error != null)
            ListTile(
              title: Text(_error!),
              trailing: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (!_busy && _error == null && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'İlk gönderini veya rota rehberini paylaş; burada yönetebilirsin.',
              ),
            ),
          for (final post in _posts)
            Card(
              color: const Color(0xFF142238),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(post['title'].toString()),
                      subtitle: Text(
                        post['mediaType'] == 'route'
                            ? 'İmzalı rehber'
                            : post['mediaType'] == 'video'
                            ? 'Reel'
                            : 'Gönderi',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PostDeepLinkScreen(postId: post['id'].toString()),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: _pins.contains(post['id'])
                            ? 'Sabitlemeyi kaldır'
                            : 'Sabitle',
                        onPressed: _busy
                            ? null
                            : () => _pin(post['id'].toString()),
                        icon: Icon(
                          _pins.contains(post['id'])
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final entry in {
                          'views': 'Görüntülenme',
                          'likes': 'Beğeni',
                          'comments': 'Yorum',
                          'saves': 'Kaydetme',
                          'reposts': 'Yeniden paylaşım',
                          'activeStoryShares': 'Yayındaki hikâye',
                          'profileVisits': 'Profil ziyareti',
                        }.entries)
                          Text(
                            '${post[entry.key] ?? 0} ${entry.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    if (post['mediaType'] == 'route')
                      TextButton.icon(
                        onPressed: _busy ? null : () => _guide(post),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Rehber notunu düzenle'),
                      ),
                  ],
                ),
              ),
            ),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_hasMore && !_busy)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('Daha fazla içerik'),
            ),
        ],
      ),
    ),
  );
}
