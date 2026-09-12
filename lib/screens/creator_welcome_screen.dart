import '../widgets/profile_name_link.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/creator_service.dart';
import '../services/social_service.dart';
import '../widgets/shared_post_card.dart';
import 'creator_center_screen.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';

class CreatorWelcomeScreen extends StatefulWidget {
  const CreatorWelcomeScreen({
    super.key,
    required this.id,
    this.enrollment = false,
  });
  final String id;
  final bool enrollment;
  @override
  State<CreatorWelcomeScreen> createState() => _CreatorWelcomeScreenState();
}

class _CreatorWelcomeScreenState extends State<CreatorWelcomeScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false, _follow = false, _joined = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? data;
      if (widget.enrollment) {
        final response = await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('getCreatorInvitePreview').call({'code': widget.id});
        data = Map<String, dynamic>.from(response.data as Map);
        if (data['valid'] != true) throw Exception('Davet geçersiz');
      } else if (FirebaseAuth.instance.currentUser != null) {
        data = await CreatorService.instance.studio('welcome', {
          'creatorId': widget.id,
        });
      }
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Bu Creator bağlantısı şu anda kullanılamıyor.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_busy || _joined) return;
    setState(() => _busy = true);
    try {
      if (widget.enrollment) {
        await FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('redeemCreatorInvite')
            .call({'code': widget.id});
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CreatorCenterScreen()),
        );
      } else {
        await CreatorService.instance.studio('referral', {
          'creatorId': widget.id,
        });
        if (_follow) await SocialService.instance.followUser(widget.id);
        if (mounted) setState(() => _joined = true);
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'İşlem tamamlanamadı.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem tamamlanamadı. Yeniden deneyebilirsin.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1629),
      appBar: AppBar(title: const Text('TBT Creator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProfileNameLink(userId: widget.enrollment ? '' : widget.id, compact: true, child: Text(
            widget.enrollment
                ? 'Creator davetin'
                : (_data?['name'] ?? 'Creator ile keşfet').toString(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          )),
          const SizedBox(height: 12),
          Text(
            widget.enrollment
                ? 'Gönderilerini, Reels videolarını ve imzalı rehberlerini kendi Creator profilinde bir araya getir.'
                : (_data?['bio'] ??
                          'Paylaşımlarını ve seçtiği rehberleri keşfetmek için giriş yap.')
                      .toString(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_error!),
            ),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!signedIn)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      if (mounted) _load();
                    },
              child: const Text('Giriş yap / hesap oluştur'),
            ),
          if (signedIn && _data != null && _error == null) ...[
            if (!widget.enrollment) ...[
              for (final post in (_data!['posts'] as List? ?? const []))
                SharedPostCard(
                  key: ValueKey(post['id']),
                  postId: post['id'].toString(),
                  compact: true,
                ),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: widget.id),
                  ),
                ),
                child: const Text('Tüm paylaşımlarını gör'),
              ),
              if (!_joined &&
                  FirebaseAuth.instance.currentUser?.uid != widget.id)
                CheckboxListTile(
                  value: _follow,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _follow = v ?? false),
                  title: const Text('Bu Creator’ı takip et'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
            if (widget.enrollment ||
                FirebaseAuth.instance.currentUser?.uid != widget.id)
              FilledButton(
                onPressed: _busy || _joined ? null : _join,
                child: Text(
                  widget.enrollment
                      ? 'Creator davetini kabul et'
                      : _joined
                      ? 'Katılımın kaydedildi'
                      : 'Bu Creator’ın davetiyle katıl',
                ),
              ),
            if (!widget.enrollment)
              const Text(
                'Katılımın davet sayacına eklenir. Takip seçimi sana ait.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
          ],
          if (_error != null)
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Yeniden dene'),
            ),
        ],
      ),
    );
  }
}

