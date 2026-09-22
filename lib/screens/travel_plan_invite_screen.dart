import '../widgets/profile_name_link.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import '../services/user_facing_error.dart';

class TravelPlanInviteScreen extends StatefulWidget {
  final String planId;
  final String planTitle;
  final bool selectionOnly;
  final Set<String> initialSelection;

  const TravelPlanInviteScreen({
    super.key,
    required this.planId,
    required this.planTitle,
    this.selectionOnly = false,
    this.initialSelection = const {},
  });

  @override
  State<TravelPlanInviteScreen> createState() => _TravelPlanInviteScreenState();
}

class _TravelPlanInviteScreenState extends State<TravelPlanInviteScreen> {
  final Set<String> _selected = {};
  List<_InviteUser> _users = const [];
  Set<String> _existingMembers = {};
  bool _loading = true;
  String _query = '';
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelection);
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final following = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();
      final plan = widget.selectionOnly
          ? null
          : await FirebaseFirestore.instance
                .collection('travel_plans')
                .doc(widget.planId)
                .get();
      final ids = following.docs.map((doc) => doc.id).toList();
      final profiles = await Future.wait(
        ids.map(
          (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
        ),
      );
      final users =
          profiles
              .where((doc) => doc.exists)
              .map(
                (doc) => _InviteUser(
                  id: doc.id,
                  name: (doc.data()?['displayName'] ?? 'TBT kullanıcısı')
                      .toString(),
                  username: (doc.data()?['username'] ?? '').toString(),
                  photoUrl: (doc.data()?['photoUrl'] ?? '').toString(),
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final members = <dynamic>[...(plan?.data()?['memberIds'] as List<dynamic>? ?? const []), ...(plan?.data()?['invitedIds'] as List<dynamic>? ?? const [])]
          .map((id) => id.toString())
          .toSet();
      if (!mounted) return;
      setState(() {
        _users = users;
        _existingMembers = members;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = userFacingError(e);
        });
    }
  }

  Future<void> _invite() async {
    if (widget.selectionOnly) {
      Navigator.pop(context, _selected.toSet());
      return;
    }
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await TravelPlanService.instance.invite(
        planId: widget.planId,
        planTitle: widget.planTitle,
        userIds: _selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.length} kişiye davet gönderildi.')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Davet gönderilemedi. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users
        .where(
          (u) => '${u.name} ${u.username}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Arkadaşlarını Davet Et')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _loading = true;
                      });
                      _load();
                    },
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          : _users.isEmpty
          ? const _EmptyInvites()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'İsim veya kullanıcı adı ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aramana uygun kişi bulunamadı.'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.planTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final user = users[index];
                      final invited = _existingMembers.contains(user.id);
                      final selected = _selected.contains(user.id);
                      return CheckboxListTile(
                        value: invited || selected,
                        onChanged: invited
                            ? null
                            : (value) => setState(() {
                                value == true && _selected.length < 59
                                    ? _selected.add(user.id)
                                    : _selected.remove(user.id);
                              }),
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          backgroundImage: user.photoUrl.isEmpty
                              ? null
                              : NetworkImage(user.photoUrl),
                          child: user.photoUrl.isEmpty
                              ? Text(
                                  user.name.isEmpty
                                      ? '?'
                                      : user.name[0].toUpperCase(),
                                )
                              : null,
                        ),
                        title: ProfileNameLink(
                          userId: user.id,
                          compact: true,
                          child: Text(user.name),
                        ),
                        subtitle: ProfileNameLink(
                          userId: user.id,
                          compact: true,
                          child: Text(
                            invited
                                ? 'Zaten planda'
                                : user.username.isEmpty
                                ? 'Takip ediyorsun'
                                : '@${user.username}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed:
                          _sending ||
                              (!widget.selectionOnly && _selected.isEmpty)
                          ? null
                          : _invite,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        widget.selectionOnly
                            ? 'Seçimi tamamla (${_selected.length})'
                            : _selected.isEmpty
                            ? 'Arkadaş seç'
                            : '${_selected.length} kişiye davet gönder',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InviteUser {
  final String id;
  final String name;
  final String username;
  final String photoUrl;

  const _InviteUser({
    required this.id,
    required this.name,
    required this.username,
    required this.photoUrl,
  });
}

class _EmptyInvites extends StatelessWidget {
  const _EmptyInvites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 54, color: Colors.white38),
            SizedBox(height: 12),
            Text(
              'Davet edebileceğin biri görünmüyor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Önce birkaç kullanıcıyı takip ettiğinde burada görünecekler.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
