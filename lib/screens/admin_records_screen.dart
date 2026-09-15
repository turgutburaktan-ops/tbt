import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/admin_console_service.dart';
import '../services/user_facing_error.dart';
import '../widgets/profile_name_link.dart';
import 'post_deep_link_screen.dart';

class AdminRecordsScreen extends StatefulWidget {
  const AdminRecordsScreen({super.key, required this.kind});
  final String kind;
  @override
  State<AdminRecordsScreen> createState() => _AdminRecordsScreenState();
}

class _AdminRecordsScreenState extends State<AdminRecordsScreen> {
  final _items = <Map<String, dynamic>>[];
  String _query = '', _status = '';
  String? _error;
  dynamic _cursor;
  bool _loading = false, _more = true, _acting = false;
  int _generation = 0;
  Timer? _timer;
  bool get _reports => widget.kind == 'reports';
  @override
  void initState() {
    super.initState();
    _status = _reports
        ? 'open'
        : widget.kind == 'photo_spots'
        ? 'published'
        : '';
    _load(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    super.dispose();
  }

  Future<void> _load(bool reset) async {
    if (_loading && !reset) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _more = true;
      }
    });
    try {
      final result = await AdminConsoleService.instance.operation(
        _reports ? 'adminModerationPage' : 'adminDirectoryPage',
        {
          'kind': widget.kind,
          'status': _status,
          'search': _query,
          'cursor': _cursor,
        },
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(
          (result['items'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _cursor = result['cursor'];
        _more = _cursor != null;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() => _error = userFacingError(e));
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _action(Map<String, dynamic> item, String action) async {
    if (_acting) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(switch (action) {
          'remove_post' => 'Gönderiyi kaldır',
          'disable_user' => 'Hesabı kısıtla',
          'delete' => 'Mekânı sil',
          _ => 'İşlemi onayla',
        }),
        content: _reports
            ? TextField(
                controller: reason,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'İşlem gerekçesi'),
              )
            : Text('${item['name']} için bu işlem uygulansın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    final note = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    if (_reports && note.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az üç karakterlik gerekçe yaz.')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      if (_reports) {
        await AdminConsoleService.instance.operation('adminReviewReport', {
          'path': item['path'],
          'action': action,
          'reason': note,
        });
      } else if (action == 'delete') {
        await AdminConsoleService.instance.deleteVenue(
          collection: 'photo_spots',
          id: item['id'].toString(),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('photo_spots')
            .doc(item['id'].toString())
            .update({
              'status': action == 'archive' ? 'archived' : 'published',
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('İşlem tamamlandı.')));
        await _load(true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _record(Map<String, dynamic> item) {
    if (!_reports)
      return ListTile(
        title: Text((item['name'] ?? item['id']).toString()),
        subtitle: Text(
          widget.kind == 'users'
              ? '@${item['username']} · ${item['email']}\n${item['banned'] == true ? 'Kısıtlı' : 'Aktif'}'
              : '${item['city']} · ${item['district']} · ${item['category']}',
        ),
        onTap: widget.kind == 'users'
            ? () => ProfileNameLink.open(context, item['id'].toString())
            : null,
        trailing: widget.kind == 'photo_spots'
            ? PopupMenuButton<String>(
                enabled: !_acting,
                onSelected: (a) => _action(item, a),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _status == 'published' ? 'archive' : 'restore',
                    child: Text(
                      _status == 'published' ? 'Arşivle' : 'Yeniden yayınla',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Sil')),
                ],
              )
            : const Icon(Icons.chevron_right),
      );
    final type = item['targetType'],
        target = (item['targetId'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${switch (type) {
              'post' => 'Gönderi',
              'user' => 'Kullanıcı',
              'business' => 'İşletme',
              'event' => 'Etkinlik',
              'review' => 'Değerlendirme',
              _ => 'İçerik',
            }} · $target',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text((item['reason'] ?? '').toString()),
          if ((item['details'] ?? '').toString().isNotEmpty)
            Text(item['details'].toString()),
          if ((item['decisionReason'] ?? '').toString().isNotEmpty)
            Text('Karar: ${item['decisionReason']}'),
          Wrap(
            spacing: 8,
            children: [
              if (target.isNotEmpty && (type == 'post' || type == 'user'))
                TextButton(
                  onPressed: () => type == 'user'
                      ? ProfileNameLink.open(context, target)
                      : Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDeepLinkScreen(postId: target),
                          ),
                        ),
                  child: const Text('İçeriği aç'),
                ),
              if (item['status'] == 'open')
                TextButton(
                  onPressed: _acting ? null : () => _action(item, 'reviewing'),
                  child: const Text('İncelemeye al'),
                ),
              if (['open', 'reviewing'].contains(item['status'])) ...[
                TextButton(
                  onPressed: _acting ? null : () => _action(item, 'dismissed'),
                  child: const Text('Şikâyeti reddet'),
                ),
                if (type == 'post')
                  TextButton(
                    onPressed: _acting
                        ? null
                        : () => _action(item, 'remove_post'),
                    child: const Text('Gönderiyi kaldır'),
                  ),
                if (type == 'user')
                  TextButton(
                    onPressed: _acting
                        ? null
                        : () => _action(item, 'disable_user'),
                    child: const Text('Hesabı kısıtla'),
                  ),
                if (type != 'post' && type != 'user')
                  TextButton(
                    onPressed: _acting ? null : () => _action(item, 'actioned'),
                    child: const Text('İncelemeyi sonuçlandır'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _reports
            ? 'Moderasyon'
            : widget.kind == 'users'
            ? 'Kullanıcı Yönetimi'
            : 'Yayınlanan Mekânlar',
      ),
    ),
    body: Column(
      children: [
        if (!_reports)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (s) {
                _query = s;
                _timer?.cancel();
                _timer = Timer(
                  const Duration(milliseconds: 400),
                  () => _load(true),
                );
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tüm kayıtlarda ara',
              ),
            ),
          ),
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final option
                    in _reports
                        ? const [
                            ('open', 'Açık'),
                            ('reviewing', 'İnceleniyor'),
                            ('actioned', 'İşlem uygulanan'),
                            ('dismissed', 'Reddedilen'),
                          ]
                        : const [
                            ('published', 'Yayında'),
                            ('archived', 'Arşiv'),
                          ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _status == option.$1,
                    onSelected: (_) {
                      _status = option.$1;
                      _load(true);
                    },
                  ),
              ],
            ),
          ),
        if (_acting) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final item in _items) ...[
                  _record(item),
                  const Divider(height: 1),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => _load(_items.isEmpty),
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu filtreye uygun kayıt yok.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_more && !_loading && _error == null)
                  TextButton(
                    onPressed: () => _load(false),
                    child: const Text('Daha fazla yükle'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
