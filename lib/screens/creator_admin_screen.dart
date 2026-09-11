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
  String _section = 'members';
  String _role = 'creator';
  Map<String, dynamic> _overview = const {};
  final _items = <Map<String, dynamic>>[];
  String? _cursor, _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _loadOverview();
    _load();
  }

  Future<void> _loadOverview() async {
    try {
      final data = await _admin('overview');
      if (mounted) setState(() => _overview = data);
    } catch (_) {}
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final action = _section == 'members' ? 'members' : 'roleInvites';
      final result = await _admin(action, {
        'role': _role,
        if (more) 'cursor': _cursor,
      });
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
          .httpsCallable('createRoleInvite')
          .call(data);
      if (!mounted) return;
      final map = Map<String, dynamic>.from(result.data as Map);
      await showTbtDialog<void>(
        context: context,
        builder: (sheet) => TbtDialog(
          title: Text('${map['roleLabel']} daveti hazır'),
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
      _role = '${map['role']}';
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
          'Bu özel bağlantı artık hesap türü vermeyecek. Daha önce kabul eden hesaplar etkilenmez.',
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
      await _admin('disableRoleInvite', {'code': invite['code']});
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
      title: const Text('Hesap türleri'),
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
      label: const Text('Özel davet'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'members', label: Text('Hesaplar')),
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
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Hesap türü'),
          items: const [
            DropdownMenuItem(value: 'creator', child: Text('TBT Creator')),
            DropdownMenuItem(value: 'explorer', child: Text('TBT Kâşif')),
            DropdownMenuItem(value: 'social', child: Text('TBT Sosyal')),
            DropdownMenuItem(value: 'gourmet', child: Text('TBT Gurme')),
          ],
          onChanged: _busy ? null : (value) {
            if (value == null) return;
            setState(() {
              _role = value;
              _items.clear();
              _cursor = null;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        if (_overview.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: 'Creator', value: _overview['roleCounts']?['creator']),
              _MetricChip(label: 'Kâşif', value: _overview['roleCounts']?['explorer']),
              _MetricChip(label: 'Sosyal', value: _overview['roleCounts']?['social']),
              _MetricChip(label: 'Gurme', value: _overview['roleCounts']?['gourmet']),
              _MetricChip(label: 'Doğrulanmış', value: _overview['verified']),
              _MetricChip(label: 'TBT Elçisi', value: _overview['ambassadors']),
            ],
          ),
        const SizedBox(height: 12),
        const Text(
          'Davetler gizlidir. Yalnızca gönderdiğin özel bağlantıyı açan kişi seçilen hesap türünü puan şartı olmadan alır.',
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
          if (_section == 'members')
            return Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text('${item['name']}'),
                subtitle: Text(
                  '${item['roleLabel']} · ${item['source'] == 'invite' ? 'Davetle' : 'Puanla'}\n${item['score']} puan · Toplam ${item['total']}${item['ambassador'] == true ? ' · TBT Elçisi' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _RoleAdminDetailScreen(
                      uid: '${item['uid']}',
                      role: _role,
                    ),
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
                    '${item['roleLabel']} · ${item['code']} · $state\n${item['usesCount']}/${item['maxUses']} kullanım · Son tarih: ${_date(item['expiresAtMs'])}${item['recipientBound'] == true ? ' · Kişiye özel' : ''}',
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
                              action: 'roleRedemptions',
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
  String _label = '', _email = '', _role = 'creator';
  int _uses = 1, _days = 30;
  @override
  Widget build(BuildContext context) => TbtDialog(
    title: const Text('Özel hesap daveti'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Verilecek hesap'),
            items: const [
              DropdownMenuItem(value: 'creator', child: Text('TBT Creator')),
              DropdownMenuItem(value: 'explorer', child: Text('TBT Kâşif')),
              DropdownMenuItem(value: 'social', child: Text('TBT Sosyal')),
              DropdownMenuItem(value: 'gourmet', child: Text('TBT Gurme')),
            ],
            onChanged: (value) => setState(() => _role = value ?? 'creator'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Kişi / davet adı'),
            onSaved: (v) => _label = v?.trim() ?? '',
          ),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Kişinin e-postası (önerilir)',
              helperText: 'Davet uygulama kurulurken kaybolsa bile hesaba bağlanır.',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              return value.contains('@') ? null : 'Geçerli bir e-posta gir.';
            },
            onSaved: (v) => _email = v?.trim() ?? '',
          ),
          const SizedBox(height: 12),
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
            'role': _role,
            'label': _label,
            'recipientEmail': _email,
            'maxUses': _uses,
            'expiresInDays': _days,
          });
        },
        child: const Text('Oluştur'),
      ),
    ],
  );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$label: ${(value as num?)?.toInt() ?? 0}'),
        avatar: const Icon(Icons.verified_outlined, size: 17),
      );
}

class _RoleAdminDetailScreen extends StatefulWidget {
  const _RoleAdminDetailScreen({required this.uid, required this.role});
  final String uid;
  final String role;

  @override
  State<_RoleAdminDetailScreen> createState() =>
      _RoleAdminDetailScreenState();
}

class _RoleAdminDetailScreenState extends State<_RoleAdminDetailScreen> {
  Map<String, dynamic>? _data;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _admin('roleDetail', {
        'userId': widget.uid,
        'role': widget.role,
      });
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      _data?['profile'] as Map? ?? const {},
    );
    final reputation = Map<String, dynamic>.from(
      _data?['reputation'] as Map? ?? const {},
    );
    final scores = Map<String, dynamic>.from(
      reputation['scores'] as Map? ?? const {},
    );
    final stats = Map<String, dynamic>.from(
      reputation['stats'] as Map? ?? const {},
    );
    final source = switch (profile['source']) {
      'invite' || 'admin' => 'Özel davet',
      'legacy_creator' => 'Eski Creator sistemi',
      'founding' => 'Kurucu Creator',
      _ => 'Puan ve şartlarla',
    };
    return Scaffold(
      appBar: AppBar(title: Text('${profile['roleLabel'] ?? 'Hesap türü'}')),
      body: _failure != null
          ? Center(
              child: FilledButton(
                onPressed: _load,
                child: const Text('Yeniden dene'),
              ),
            )
          : _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.workspace_premium_rounded),
                    ),
                    title: Text(
                      '${profile['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '$source · ${profile['score'] ?? 0} puan\n'
                      'Toplam ${profile['total'] ?? 0} gerçek katkı puanı',
                    ),
                    trailing: profile['verified'] == true
                        ? const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF52D8FF),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dört alanın puanı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(label: 'Creator', value: scores['creator']),
                    _MetricChip(label: 'Kâşif', value: scores['explorer']),
                    _MetricChip(label: 'Sosyal', value: scores['social']),
                    _MetricChip(label: 'Gurme', value: scores['gourmet']),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Doğrulanmış katkılar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (stats.isEmpty)
                  const Text('Henüz ayrıntılı katkı kaydı yok.')
                else
                  ...stats.entries.map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_statLabel(entry.key)),
                      trailing: Text(
                        entry.value is List
                            ? '${(entry.value as List).length}'
                            : '${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                if (profile['ambassador'] == true)
                  const Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD166),
                      ),
                      title: Text('TBT Elçisi'),
                      subtitle: Text('Dört hesap türü ve doğrulama tamamlandı.'),
                    ),
                  ),
                if (widget.role == 'creator')
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatorAdminDetailScreen(
                          uid: widget.uid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Creator içerik istatistikleri'),
                  ),
              ],
            ),
    );
  }
}

String _statLabel(String key) => switch (key) {
  'creatorContent' => 'Özgün içerik',
  'creatorStories' => 'Story',
  'creatorQualityBonuses' => 'Kalite bonusu',
  'explorerApprovedSpots' => 'Onaylı yer',
  'explorerLocatedPosts' => 'Konumlu paylaşım',
  'explorerCities' => 'Farklı şehir',
  'explorerRoutes' => 'Yayınlanan rota',
  'socialHostedCompleted' => 'Gerçekleşen etkinlik',
  'socialAttendance' => 'Doğrulanmış katılım',
  'socialMemories' => 'Etkinlik anısı',
  'gourmetVenues' => 'Farklı mekân',
  'gourmetPhotoReviews' => 'Fotoğraflı deneyim',
  'gourmetCoupons' => 'Kullanılan kupon',
  'gourmetReservations' => 'Tamamlanan rezervasyon',
  _ => key,
};

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
