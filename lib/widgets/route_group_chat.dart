import '../theme/app_theme.dart';
import '../models/nearby_venue.dart';
import '../screens/business_profile_screen.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/travel_plan.dart';
import '../models/photo_spot.dart';
import '../screens/event_location_picker_screen.dart';
import '../services/route_chat_service.dart';
import '../services/travel_plan_collaboration_service.dart';
import '../services/user_facing_error.dart';
import 'chat_voice_message.dart';
import 'profile_name_link.dart';
import 'route_chat_attachment.dart';
import 'route_chat_bubble.dart';
import 'route_polls.dart';
import 'route_stop_picker.dart';

class RouteGroupChat extends StatefulWidget {
  const RouteGroupChat({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<RouteGroupChat> createState() => _RouteGroupChatState();
}

class _RouteGroupChatState extends State<RouteGroupChat> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _subscriptions =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final _entries =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final _errors = <String, Object>{};
  Map<String, dynamic>? _reply;
  bool _busy = false;
  final _actions = <String>{};
  DocumentReference<Map<String, dynamic>> get _root =>
      RouteChatService.instance.plan(widget.plan.id);
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  @override
  void initState() {
    super.initState();
    for (final type in ['messages', 'proposals', 'polls']) {
      _subscriptions.add(
        _root
            .collection(type)
            .orderBy('createdAt', descending: true)
            .limit(type == 'messages' ? 120 : 50)
            .snapshots()
            .listen(
              (s) {
                if (mounted)
                  setState(() {
                    _entries[type] = s.docs;
                    _errors.remove(type);
                  });
              },
              onError: (Object e) {
                if (mounted) setState(() => _errors[type] = e);
              },
            ),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _error(Object e) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(e))));
  }

  Future<void> _act(String key, Future<void> Function() action) async {
    if (_actions.contains(key)) return;
    setState(() => _actions.add(key));
    try {
      await action();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _actions.remove(key));
    }
  }

  Future<void> _send() async {
    if (_busy || _text.text.trim().isEmpty) return;
    final text = _text.text;
    final reply = _reply;
    setState(() => _busy = true);
    try {
      await RouteChatService.instance.send(widget.plan.id, text, reply: reply);
      if (!mounted) return;
      setState(() {
        if (_text.text == text) _text.clear();
        if (identical(_reply, reply)) _reply = null;
      });
      if (_scroll.hasClients)
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<EventLocationSelection?> _map(String title) =>
      Navigator.push<EventLocationSelection>(
        context,
        MaterialPageRoute(
          builder: (_) => EventLocationPickerScreen(
            city: widget.plan.city,
            addressLabel: '',
            title: title,
          ),
        ),
      );
  Future<void> _propose(bool map) async {
    if (map) {
      final p = await _map('Durak öner');
      if (p == null || !mounted) return;
      await _act(
        'proposal',
        () => TravelPlanCollaborationService.instance.proposeStopIfAbsent(
          widget.plan.id,
          p.label.isEmpty ? 'Haritadan seçilen durak' : p.label,
          spotId:
              'map:${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
          latitude: p.latitude,
          longitude: p.longitude,
          city: widget.plan.city,
        ),
      );
    } else {
      final p = await showModalBottomSheet<PhotoSpot>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            RouteStopPicker(city: widget.plan.city, stops: const []),
      );
      if (p == null || !mounted) return;
      await _act(
        'proposal',
        () => TravelPlanCollaborationService.instance.proposeStopIfAbsent(
          widget.plan.id,
          p.name,
          spotId: p.id,
          latitude: p.latitude,
          longitude: p.longitude,
          city: p.city,
          stopSnapshot: {
            'id': p.id,
            'name': p.name,
            'latitude': p.latitude,
            'longitude': p.longitude,
            'city': p.city,
            'imageUrl': p.imageUrl,
            'category': p.category,
          },
        ),
      );
    }
  }

  Future<void> _media() async {
    if (_busy) return;
    final file = await ImagePicker().pickMedia();
    if (file == null || !mounted) return;
    var album = false, export = false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fotoğraf / video gönder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'Yalnızca bu gezinin katılımcıları görebilir.',
                  style: TextStyle(color: Colors.white60),
                ),
                CheckboxListTile(
                  value: album,
                  onChanged: (v) => update(() => album = v ?? false),
                  title: const Text('Gezi albümüne de ekle'),
                ),
                if (album)
                  CheckboxListTile(
                    value: export,
                    onChanged: (v) => update(() => export = v ?? false),
                    title: const Text(
                      'Albümden indirmeye ve paylaşmaya izin ver',
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Gönder'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final reply = _reply;
    setState(() => _busy = true);
    try {
      await RouteChatService.instance.media(
        widget.plan.id,
        file,
        addToAlbum: album,
        allowExport: export,
        reply: reply,
      );
      if (mounted)
        setState(() {
          if (identical(reply, _reply)) _reply = null;
        });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _plus() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              (Icons.photo_library_outlined, 'Fotoğraf / video', 'media'),
              (Icons.location_on_outlined, 'Konum paylaş', 'location'),
              (Icons.add_location_alt_outlined, 'Durak öner', 'stop'),
              (Icons.map_outlined, 'Haritadan durak öner', 'map'),
              (Icons.poll_outlined, 'Oylama oluştur', 'poll'),
            ])
              ListTile(
                leading: Icon(item.$1, color: AppColors.primary),
                title: Text(item.$2),
                onTap: () => Navigator.pop(c, item.$3),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'media':
          await _media();
        case 'location':
          final p = await _map('Konum paylaş');
          if (p != null && mounted)
            await _act(
              'location',
              () => RouteChatService.instance.location(
                widget.plan.id,
                p.label,
                p.latitude,
                p.longitude,
                reply: _reply,
              ),
            );
        case 'stop':
          await _propose(false);
        case 'map':
          await _propose(true);
        case 'poll':
          await RoutePolls(
            planId: widget.plan.id,
            ownerId: widget.plan.ownerId,
          ).create(context);
      }
    } catch (e) {
      _error(e);
    }
  }

  String _time(dynamic value) {
    if (value is! Timestamp) return '';
    final d = value.toDate().toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _summary() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _root.snapshots(),
    builder: (_, s) {
      final meeting = s.data?.data()?['meetingPoint'];
      final label = meeting is Map ? meeting['label']?.toString() : null;
      final d = widget.plan.startAt.toLocal();
      return Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: () => DefaultTabController.of(context).animateTo(0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.selection,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.plan.hasSchedule ? '${d.day}.${d.month} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : 'Tarih belirlenmedi'} · ${widget.plan.memberIds.length} kişi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      if (label != null)
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 38,
                  child: Stack(
                    children: [
                      for (
                        var i = 0;
                        i < widget.plan.memberIds.take(2).length;
                        i++
                      )
                        Positioned(
                          left: i * 17.0,
                          top: i * 5.0,
                          child: _RouteMemberAvatar(
                            userId: widget.plan.memberIds[i],
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      );
    },
  );
  Future<void> _openProposal(Map<String, dynamic> data) async {
    final snapshot = data['stopSnapshot'];
    final venue = snapshot is Map ? snapshot['venue'] : null;
    if (venue is Map) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessProfileScreen(
            venue: NearbyVenue.fromJson(Map<String, dynamic>.from(venue)),
          ),
        ),
      );
      return;
    }
    final lat =
        data['latitude'] ?? (snapshot is Map ? snapshot['latitude'] : null);
    final lng =
        data['longitude'] ?? (snapshot is Map ? snapshot['longitude'] : null);
    if (lat is! num || lng is! num) throw Exception('Durak konumu bulunamadı.');
    if (!await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$lat,$lng',
      }),
      mode: LaunchMode.externalApplication,
    ))
      throw Exception('Harita açılamadı.');
  }

  Widget _proposal(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final voters = List<String>.from(d['voterIds'] as List? ?? []);
    final accepted = d['status'] == 'accepted';
    final owner = widget.plan.ownerId == _uid;
    final photo = d['stopSnapshot'] is Map
        ? d['stopSnapshot']['imageUrl']?.toString() ?? ''
        : '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DURAK ÖNERİSİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
              ),
              if (owner || d['authorId'] == _uid)
                IconButton(
                  tooltip: 'Öneriyi sil',
                  onPressed: _actions.contains(doc.id)
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Öneri silinsin mi?'),
                              content: Text(
                                accepted
                                    ? 'Rotaya eklenmiş durak rotada kalır.'
                                    : 'Bu öneri sohbetten kaldırılacak.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Vazgeç'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && mounted)
                            await _act(
                              doc.id,
                              () => TravelPlanCollaborationService.instance
                                  .deleteProposal(widget.plan.id, doc.id),
                            );
                        },
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
            ],
          ),
          if (photo.startsWith('https://'))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photo,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          InkWell(
            onTap: () => _act('open-${doc.id}', () => _openProposal(d)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d['text']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
          Text(
            accepted ? '✓ Rotaya eklendi' : 'Rotaya ekleyelim mi?',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (!accepted)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: voters.contains(_uid) || _actions.contains(doc.id)
                      ? null
                      : () => _act(
                          doc.id,
                          () => TravelPlanCollaborationService.instance.vote(
                            widget.plan.id,
                            doc.id,
                          ),
                        ),
                  icon: Icon(
                    voters.contains(_uid)
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 16,
                  ),
                  label: Text(
                    '${voters.length} · ${voters.contains(_uid) ? 'Destekledin' : 'Destekle'}',
                  ),
                ),
                if (owner)
                  FilledButton(
                    onPressed: _actions.contains(doc.id)
                        ? null
                        : () => _act(
                            doc.id,
                            () => TravelPlanCollaborationService.instance
                                .acceptDayStopProposal(widget.plan.id, doc.id),
                          ),
                    child: const Text('Rotaya ekle'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _message(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data(), mine = doc.data()['senderId'] == _uid;
    final reply = d['reply'];
    if (d['type'] == 'update')
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        child: Text(
          '${d['senderName'] ?? 'Katılımcı'} · ${d['text']}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      );
    Widget? attachment;
    if (['image', 'video', 'audio'].contains(d['type']))
      attachment = RouteChatAttachment(
        key: ValueKey(doc.id),
        planId: widget.plan.id,
        messageId: doc.id,
        data: d,
        mine: mine,
      );
    if (d['type'] == 'location')
      attachment = TextButton.icon(
        onPressed: () => _act(doc.id, () async {
          final lat = d['latitude'], lng = d['longitude'];
          if (lat is! num || lng is! num)
            throw Exception('Konum bilgisi eksik.');
          if (!await launchUrl(
            Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': '$lat,$lng',
            }),
            mode: LaunchMode.externalApplication,
          ))
            throw Exception('Harita açılamadı.');
        }),
        icon: const Icon(Icons.location_on_outlined),
        label: Text('${d['text']}'),
      );
    return RouteChatBubble(
      mine: mine,
      name: '${d['senderName'] ?? 'Katılımcı'}',
      text: '${d['text'] ?? ''}',
      time: _time(d['createdAt']),
      pending: doc.metadata.hasPendingWrites,
      replyText: reply is Map
          ? '${reply['name'] ?? ''}\n${reply['text'] ?? ''}'
          : null,
      attachment: attachment,
      onProfile: () => ProfileNameLink.open(context, '${d['senderId'] ?? ''}'),
      avatar:
          d['senderPhoto'] is String &&
              (d['senderPhoto'] as String).startsWith('https://')
          ? CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(d['senderPhoto']),
              onBackgroundImageError: (_, __) {},
            )
          : null,
      onReply: () {
        setState(
          () => _reply = {
            'id': doc.id,
            'name': d['senderName'] ?? 'Katılımcı',
            'text': '${d['text'] ?? ''}'.substring(
              0,
              '${d['text'] ?? ''}'.length.clamp(0, 180),
            ),
          },
        );
        _focus.requestFocus();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final e in _entries.entries)
        for (final doc in e.value) (e.key, doc),
    ];
    items.sort((a, b) {
      final ad = a.$2.data()['createdAt'], bd = b.$2.data()['createdAt'];
      final at = ad is Timestamp ? ad.millisecondsSinceEpoch : 8640000000000000;
      final bt = bd is Timestamp ? bd.millisecondsSinceEpoch : 8640000000000000;
      final c = bt.compareTo(at);
      return c != 0 ? c : a.$2.id.compareTo(b.$2.id);
    });
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          _summary(),
          if (_errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                userFacingError(_errors.values.first),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: _entries.isEmpty && _errors.isEmpty
                          ? const CircularProgressIndicator()
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 36,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Gezi burada başlıyor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Bir merhaba yaz, durak öner veya birlikte karar vermek için oylama aç.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return KeyedSubtree(
                        key: ValueKey('${item.$1}/${item.$2.id}'),
                        child: switch (item.$1) {
                          'proposals' => _proposal(item.$2),
                          'polls' => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            child: RoutePolls(
                              planId: widget.plan.id,
                              ownerId: widget.plan.ownerId,
                              onlyPollId: item.$2.id,
                              showCreateButton: false,
                            ),
                          ),
                          _ => _message(item.$2),
                        },
                      );
                    },
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_reply != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.reply,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_reply!['name']}: ${_reply!['text']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Yanıtı iptal et',
                            onPressed: () => setState(() => _reply = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    if (_busy) const LinearProgressIndicator(minHeight: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Fotoğraf, konum veya oylama ekle',
                          onPressed: _busy ? null : _plus,
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            focusNode: _focus,
                            maxLines: 4,
                            minLines: 1,
                            maxLength: 1000,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Gruba mesaj yaz',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_text.text.trim().isNotEmpty)
                          IconButton.filled(
                            tooltip: 'Gönder',
                            onPressed: _busy ? null : _send,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          )
                        else
                          ChatVoiceRecordButton(
                            disabled: _busy,
                            onError: _error,
                            onRecorded: (bytes, duration) async {
                              final reply = _reply;
                              setState(() => _busy = true);
                              try {
                                await RouteChatService.instance.audio(
                                  widget.plan.id,
                                  bytes,
                                  duration,
                                  reply: reply,
                                );
                                if (mounted)
                                  setState(() {
                                    if (identical(reply, _reply)) _reply = null;
                                  });
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMemberAvatar extends StatefulWidget {
  const _RouteMemberAvatar({required this.userId});
  final String userId;
  @override
  State<_RouteMemberAvatar> createState() => _RouteMemberAvatarState();
}

class _RouteMemberAvatarState extends State<_RouteMemberAvatar> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profile =
      FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
  @override
  void didUpdateWidget(covariant _RouteMemberAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId)
      _profile = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profile,
        builder: (_, s) {
          final photo = s.data?.data()?['photoUrl']?.toString() ?? '';
          return CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: photo.startsWith('https://')
                ? NetworkImage(photo)
                : null,
            onBackgroundImageError: photo.startsWith('https://')
                ? (_, __) {}
                : null,
            child: photo.startsWith('https://')
                ? null
                : const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.white60,
                  ),
          );
        },
      );
}
