import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/community_service.dart';
import '../services/invite_link_service.dart';
import 'community_profile_screen.dart';
import 'invite_qr_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String _university = '';

  Future<void> _create() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Topluluk oluşturmak için giriş yapmalısın.');
      return;
    }
    final name = TextEditingController();
    final university = TextEditingController(text: _university);
    final description = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090A0C),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(sheet).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Topluluk Oluştur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Topluluk adı')),
            const SizedBox(height: 12),
            TextField(controller: university, decoration: const InputDecoration(labelText: 'Üniversite')),
            const SizedBox(height: 12),
            TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Açıklama')),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  try {
                    await CommunityService.instance.createCommunity(name: name.text, university: university.text, description: description.text);
                    if (sheet.mounted) Navigator.pop(sheet);
                    _message('Topluluk oluşturuldu. Doğrulama bekliyor.');
                  } catch (e) {
                    _message(e.toString().replaceFirst('Exception: ', ''));
                  }
                },
                child: const Text('Oluştur'),
              ),
            ),
          ]),
        ),
      ),
    );
    name.dispose(); university.dispose(); description.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Topluluklar'),
        actions: [IconButton(onPressed: _create, icon: const Icon(Icons.add_circle_outline), tooltip: 'Topluluk oluştur')],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined), labelText: 'Üniversiteye göre filtrele', hintText: 'Örn. Fırat Üniversitesi'),
            onChanged: (v) => setState(() => _university = v.trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: CommunityService.instance.watchCommunities(university: _university),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Bu üniversitede henüz topluluk yok.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final id = docs[i].id;
                  final verified = d['verified'] == true;
                  final name = (d['name'] ?? 'Topluluk').toString();
                  final university = (d['university'] ?? '').toString();
                  return Card(
                    color: const Color(0xFF121416),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityProfileScreen(communityId: id))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const CircleAvatar(radius: 27, backgroundColor: Color(0xFF25292E), child: Icon(Icons.groups_2_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), if (verified) const Icon(Icons.verified, size: 18, color: Color(0xFFB7BCC2))]),
                            const SizedBox(height: 3),
                            Text(university, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            if ((d['description'] ?? '').toString().trim().isNotEmpty) ...[const SizedBox(height: 6), Text(d['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))],
                            const SizedBox(height: 8),
                            StreamBuilder<int>(stream: CommunityService.instance.followerCount(id), builder: (_, s) => Text('${s.data ?? 0} takipçi', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                          ])),
                          const SizedBox(width: 8),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Davet QR',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InviteQrScreen(
                                    title: name,
                                    subtitle: university,
                                    uri: InviteLinkService.instance.communityUri(id),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_2_rounded),
                            ),
                            StreamBuilder<bool>(
                              stream: CommunityService.instance.isFollowing(id),
                              builder: (_, s) => FilledButton.tonal(
                                onPressed: () async {
                                  try { await CommunityService.instance.toggleFollow(id); }
                                  catch (e) { _message(e.toString().replaceFirst('Exception: ', '')); }
                                },
                                child: Text(s.data == true ? 'Takipte' : 'Takip Et'),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
