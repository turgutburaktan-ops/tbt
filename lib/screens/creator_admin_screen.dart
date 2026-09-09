import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/tbt_dialog.dart';
import 'post_deep_link_screen.dart';
import 'user_profile_screen.dart';

final _creatorFunctions = FirebaseFunctions.instanceFor(region: 'europe-west1');
Future<Map<String, dynamic>> _admin(
  String action, [
  Map<String, dynamic> data = const {},
]) async {
  final result = await _creatorFunctions.httpsCallable('creatorAdmin').call({
    'action': action,
    ...data,
  });
  return Map<String, dynamic>.from(result.data as Map);
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
String _date(dynamic value) {
  final ms = (value as num? ?? 0).toInt();
  if (ms == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}.${d.month}.${d.year}';
}

void _error(BuildContext context, Object error) => ScaffoldMessenger.of(context)
    .showSnackBar(
      SnackBar(
        content: Text(
          error is FirebaseFunctionsException
              ? error.message ?? 'İşlem tamamlanamadı.'
              : 'Bağlantı kurulamadı. Yeniden dene.',
        ),
      ),
    );
Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted)
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
}

class CreatorAdminScreen extends StatefulWidget {
  const CreatorAdminScreen({super.key});
  @override
  State<CreatorAdminScreen> createState() => _CreatorAdminScreenState();
}

class _CreatorAdminScreenState extends State<CreatorAdminScreen> {
  String _section = 'creators';
  final _items = <Map<String, dynamic>>[];
  String? _cursor, _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await _admin(_section, {if (more) 'cursor': _cursor});
      if (mounted)
        setState(() {
          if (!more) _items.clear();
          _items.addAll(_rows(result['items']));
          _cursor = result['nextCursor'] as String?;
        });
    } catch (e) {
      if (mounted) {
        _error(context, e);
        setState(
          () => _failure =
              'Liste yüklenemedi. Yönetici hesabını ve bağlantını kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final data = await showTbtDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _InviteForm(),
    );
    if (data == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _creatorFunctions
          .httpsCallable('createCreatorInvite')
          .call(data);
      if (!mounted) return;
      final map = Map<String, dynamic>.from(result.data as Map);
      await showTbtDialog<void>(
        context: context,
        builder: (sheet) => TbtDialog(
          title: const Text('Creator daveti hazır'),
          content: SelectableText(
            '${map['url']}\n\nSon kullanım: ${_date(map['expiresAtMs'])} · ${map['maxUses']} kişi',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Kapat'),
            ),
            FilledButton(
              onPressed: () => _copy(sheet, '${map['url']}'),
              child: const Text('Bağlantıyı kopyala'),
            ),
          ],
        ),
      );
      _section = 'invites';
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _load();
      }
    }
  }

  Future<void> _disable(Map<String, dynamic> invite) async {
    final yes = await showTbtDialog<bool>(
      context: context,
      builder: (sheet) => TbtDialog(
        title: const Text('Daveti kapat'),
        content: const Text(
          'Bu bağlantı artık Creator kaydı açmayacak. Daha önce katılan hesaplar etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(sheet, true),
            child: const Text('Daveti kapat'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _admin('disableInvite', {'code': invite['code']});
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B172A),
    appBar: AppBar(
      title: const Text('Creator yönetimi'),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : _create,
      icon: const Icon(Icons.add_link),
      label: const Text('Creator daveti'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'creators', label: Text('Creator hesapları')),
            ButtonSegment(value: 'invites', label: Text('Davetler')),
          ],
          selected: {_section},
          onSelectionChanged: _busy
              ? null
              : (v) {
                  setState(() {
                    _section = v.first;
                    _items.clear();
                    _cursor = null;
                  });
                  _load();
                },
        ),
        const SizedBox(height: 16),
        const Text(
          'Creator daveti hesap yetkisi verir. Creator’ın profil paylaşım bağlantısı ise getirdiği kullanıcıları ölçer.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_failure != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_failure!)),
        if (!_busy && _items.isEmpty && _failure == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Henüz kayıt yok.'),
          ),
        ..._items.map((item) {
          if (_section == 'creators')
            return Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text('${item['name']}'),
                subtitle: Text(
                  '${item['tier'] == 'founding' ? 'İlk 100 Creator' : 'Creator'} · ${item['active'] == true && item['isCreator'] == true ? 'Aktif' : 'Pasif'}\nKatılım: ${_date(item['joinedAtMs'])} · ${item['code']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreatorAdminDetailScreen(uid: '${item['uid']}'),
                  ),
                ),
              ),
            );
          final usable =
              item['active'] == true &&
              (item['expiresAtMs'] as num) >
                  DateTime.now().millisecondsSinceEpoch &&
              (item['usesCount'] as num) < (item['maxUses'] as num);
          final state = item['active'] != true
              ? 'Kapatıldı'
              : (item['usesCount'] as num) >= (item['maxUses'] as num)
              ? 'Kullanım doldu'
              : usable
              ? 'Aktif'
              : 'Süresi doldu';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['label'].toString().isEmpty ? item['code'] : item['label']}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${item['code']} · $state\n${item['usesCount']}/${item['maxUses']} kullanım · Son tarih: ${_date(item['expiresAtMs'])}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _copy(context, '${item['url']}'),
                        icon: const Icon(Icons.copy),
                        label: const Text('Bağlantı'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CreatorPeopleScreen(
                              title: 'Daveti kullananlar',
                              action: 'redemptions',
                              query: {'code': item['code']},
                            ),
                          ),
                        ),
                        child: const Text('Kullananlar'),
                      ),
                      if (item['active'] == true)
                        TextButton(
                          onPressed: _busy ? null : () => _disable(item),
                          child: const Text('Daveti kapat'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (_cursor != null)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Daha fazla yükle'),
          ),
      ],
    ),
  );
}

class _InviteForm extends StatefulWidget {
  const _InviteForm();
  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _form = GlobalKey<FormState>();
  String _label = '';
  int _uses = 1, _days = 30;
  @override
  Widget build(BuildContext context) => TbtDialog(
    title: const Text('Creator daveti oluştur'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Kişi / davet adı'),
            onSaved: (v) => _label = v?.trim() ?? '',
          ),
          TextFormField(
            initialValue: '1',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kullanım sınırı (1–20)',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 20
                  ? '1–20 arası bir sayı gir.'
                  : null;
            },
            onSaved: (v) => _uses = int.parse(v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '30',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Geçerlilik süresi (1–90 gün)',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 90
                  ? '1–90 arası bir sayı gir.'
                  : null;
            },
            onSaved: (v) => _days = int.parse(v!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          _form.currentState!.save();
          Navigator.pop(context, {
            'label': _label,
            'maxUses': _uses,
            'expiresInDays': _days,
          });
        },
        child: const Text('Oluştur'),
      ),
    ],
  );
}

class CreatorAdminDetailScreen extends StatefulWidget {
  const CreatorAdminDetailScreen({super.key, required this.uid});
  final String uid;
  @override
  State<CreatorAdminDetailScreen> createState() =>
      _CreatorAdminDetailScreenState();
}

class _CreatorAdminDetailScreenState extends State<CreatorAdminDetailScreen> {
  Map<String, dynamic>? _data;
  final _posts = <Map<String, dynamic>>[];
  String? _cursor;
  int _days = 30;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = await _admin('detail', {
        'creatorId': widget.uid,
        'days': _days,
        if (more) 'cursor': _cursor,
      });
      if (mounted)
        setState(() {
          _data = d;
          if (!more) _posts.clear();
          _posts.addAll(_rows(d['posts']));
          _cursor = d['nextCursor'] as String?;
        });
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(_data?['profile'] as Map? ?? {}),
        totals = Map<String, dynamic>.from(_data?['totals'] as Map? ?? {});
    return Scaffold(
      backgroundColor: const Color(0xFF0B172A),
      appBar: AppBar(
        title: Text('${p['name'] ?? 'Creator istatistikleri'}'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_data != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${p['tier'] == 'founding' ? 'İlk 100 Creator' : 'Creator'} · ${p['active'] == true && p['isCreator'] == true ? 'Aktif' : 'Pasif'}',
              ),
              subtitle: Text(
                'Katılım: ${_date(p['joinedAtMs'])} · Davet: ${p['code']}',
              ),
              trailing: const Icon(Icons.person_outline),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: widget.uid),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _copy(context, '${_data!['referralUrl']}'),
                  icon: const Icon(Icons.link),
                  label: const Text('Profil davet bağlantısı'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _CreatorPeopleScreen(
                        title: 'Bağlantıdan gelen kullanıcılar',
                        action: 'referrals',
                        query: {'creatorId': widget.uid},
                      ),
                    ),
                  ),
                  child: Text('${_data!['referrals']} kullanıcı getirdi'),
                ),
              ],
            ),
            Text('Güncel takipçi: ${_data!['followers']}'),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<int>(
            initialValue: _days,
            decoration: const InputDecoration(
              labelText: 'Görüntülenme ve profil geçişi dönemi',
            ),
            items: const [
              DropdownMenuItem(value: 7, child: Text('Son 7 gün')),
              DropdownMenuItem(value: 30, child: Text('Son 30 gün')),
              DropdownMenuItem(value: 90, child: Text('Son 90 gün')),
              DropdownMenuItem(value: 0, child: Text('Tüm zamanlar')),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _days = v!);
                    _load();
                  },
          ),
          if (_data != null) ...[
            const SizedBox(height: 12),
            Text(
              '${totals['views'] ?? 0} görüntülenme · ${totals['profileVisits'] ?? 0} profil geçişi',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            if (_days != 0)
              Text(
                (_data!['dailyTrackingSinceMs'] as num? ?? 0) > 0
                    ? 'Günlük ölçüm başlangıcı: ${_date(_data!['dailyTrackingSinceMs'])}. Öncesi yalnız tüm zamanlar toplamında yer alır.'
                    : 'Günlük ölçüm henüz başlamadı. Önceki ölçümler tüm zamanlar seçeneğinde.',
              ),
            const SizedBox(height: 24),
            const Text(
              'En çok görüntülenen içerikler · Tüm zamanlar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._rows(_data!['top']).map(
              (post) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${post['title']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${post['views']}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDeepLinkScreen(postId: '${post['id']}'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'İçerik istatistikleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Görüntülenme ve profil geçişleri seçili döneme aittir. Beğeni, yorum, kaydetme, yeniden paylaşım ve aktif hikâyeler güncel sayılardır.',
            ),
            ..._posts.map(
              (post) => Card(
                child: ListTile(
                  title: Text('${post['title']}'),
                  subtitle: Text(
                    '${post['mediaType']} · ${_date(post['createdAtMs'])}\n${post['views']} görüntülenme · ${post['profileVisits']} profil geçişi\n${post['likes']} beğeni · ${post['comments']} yorum · ${post['saves']} kaydetme\n${post['reposts']} yeniden paylaşım · ${post['activeStoryShares']} aktif hikâye',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostDeepLinkScreen(postId: '${post['id']}'),
                    ),
                  ),
                ),
              ),
            ),
            if (_cursor != null)
              TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Daha fazla içerik'),
              ),
          ],
        ],
      ),
    );
  }
}

class _CreatorPeopleScreen extends StatefulWidget {
  const _CreatorPeopleScreen({
    required this.title,
    required this.action,
    required this.query,
  });
  final String title, action;
  final Map<String, dynamic> query;
  @override
  State<_CreatorPeopleScreen> createState() => _CreatorPeopleScreenState();
}

class _CreatorPeopleScreenState extends State<_CreatorPeopleScreen> {
  final _items = <Map<String, dynamic>>[];
  String? _cursor;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = await _admin(widget.action, {
        ...widget.query,
        if (more) 'cursor': _cursor,
      });
      if (mounted)
        setState(() {
          if (!more) _items.clear();
          _items.addAll(_rows(d['items']));
          _cursor = d['nextCursor'] as String?;
        });
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (!_busy && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Henüz kayıt yok.'),
          ),
        ..._items.map(
          (p) => ListTile(
            title: Text('${p['name']}'),
            subtitle: Text('Katılım: ${_date(p['joinedAtMs'])}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: '${p['uid']}'),
              ),
            ),
          ),
        ),
        if (_cursor != null)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Daha fazla yükle'),
          ),
      ],
    ),
  );
}
