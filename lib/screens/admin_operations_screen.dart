import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/admin_access.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _allowed = AdminAccess.tokenMatches(user, token));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true)
      return const Scaffold(
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Ad, kullanıcı adı veya e-posta ara',
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .limit(250)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final q = _search.text.trim().toLowerCase();
                final docs = snapshot.data!.docs.where((doc) {
                  if (q.isEmpty) return true;
                  final d = doc.data();
                  final haystack = [
                    d['displayName'],
                    d['username'],
                    d['email'],
                    doc.id,
                  ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
                  return haystack.contains(q);
                }).toList();
                if (docs.isEmpty)
                  return const Center(child: Text('Kullanıcı bulunamadı.'));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final name =
                        (d['displayName'] ?? d['username'] ?? 'Kullanıcı')
                            .toString();
                    final username = (d['username'] ?? '').toString();
                    final banned = d['banned'] == true;
                    final trust = (d['trustScore'] ?? d['trust'] ?? '')
                        .toString();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            if (username.isNotEmpty) '@$username',
                            if (trust.isNotEmpty) 'Güven: $trust',
                            if (banned) 'BANLI',
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          useSafeArea: true,
                          showDragHandle: true,
                          builder: (_) => ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'UID: ${doc.id}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                'Kullanıcı adı',
                                username.isEmpty ? '-' : '@$username',
                              ),
                              _InfoRow(
                                'E-posta',
                                (d['email'] ?? '-').toString(),
                              ),
                              _InfoRow('Şehir', (d['city'] ?? '-').toString()),
                              _InfoRow('Durum', banned ? 'Banlı' : 'Aktif'),
                              _InfoRow('Güven', trust.isEmpty ? '-' : trust),
                              const SizedBox(height: 14),
                              const Text(
                                'Yaptırım işlemleri Moderasyon ve Güvenlik ekranından uygulanır.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  bool? _allowed;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _allowed = AdminAccess.tokenMatches(user, token));
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true)
      return const Scaffold(
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('İşletmeler')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Tümü')),
                ButtonSegment(value: 'pending_review', label: Text('Bekleyen')),
                ButtonSegment(value: 'verified', label: Text('Onaylı')),
                ButtonSegment(value: 'rejected', label: Text('Red')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('business_claims')
                  .limit(250)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  final status = (doc.data()['status'] ?? '').toString();
                  return _filter == 'all' || status == _filter;
                }).toList();
                if (docs.isEmpty)
                  return const Center(child: Text('Bu filtrede işletme yok.'));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final status = (d['status'] ?? '').toString();
                    final venue =
                        (d['venueName'] ?? d['legalName'] ?? 'İşletme')
                            .toString();
                    final early =
                        (d['earlyBusinessAccessUntil'] ??
                                d['premiumUntil'] ??
                                '')
                            .toString();
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'verified'
                              ? Icons.verified_rounded
                              : Icons.storefront_outlined,
                          color: status == 'verified'
                              ? AppColors.cyan
                              : Colors.white60,
                        ),
                        title: Text(
                          venue,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            (d['category'] ?? '').toString(),
                            status,
                            if (early.isNotEmpty) 'Erken Premium aktif',
                          ].where((e) => e.isNotEmpty).join(' • '),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          useSafeArea: true,
                          builder: (_) => Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  venue,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _InfoRow('Durum', status),
                                _InfoRow(
                                  'Kategori',
                                  (d['category'] ?? '-').toString(),
                                ),
                                _InfoRow(
                                  'İşletme e-postası',
                                  (d['businessEmail'] ?? '-').toString(),
                                ),
                                _InfoRow(
                                  'Yetkili UID',
                                  (d['applicantUid'] ?? '-').toString(),
                                ),
                                _InfoRow(
                                  'Premium',
                                  early.isEmpty
                                      ? 'Standart'
                                      : 'Erken İşletme Premium',
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Onay/red işlemleri Genel Bakış içindeki işletme inceleme alanından yapılır.',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminGrowthScreen extends StatefulWidget {
  const AdminGrowthScreen({super.key});

  @override
  State<AdminGrowthScreen> createState() => _AdminGrowthScreenState();
}

class _AdminGrowthScreenState extends State<AdminGrowthScreen> {
  bool? _allowed;
  bool _loading = true;
  Map<String, int> _metrics = const {};
  List<MapEntry<String, int>> _cities = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(
      true,
    );
    final allowed = AdminAccess.tokenMatches(user, token);
    if (!allowed) {
      if (mounted)
        setState(() {
          _allowed = false;
          _loading = false;
        });
      return;
    }
    final db = FirebaseFirestore.instance;
    final counts = await Future.wait<int>([
      _count(db.collection('users')),
      _count(db.collection('posts')),
      _count(db.collection('social_events')),
      _count(
        db.collection('business_claims').where('status', isEqualTo: 'verified'),
      ),
      _count(
        db
            .collection('business_claims')
            .where('status', isEqualTo: 'pending_review'),
      ),
    ]);
    final users = await db.collection('users').limit(1000).get();
    final cityCounts = <String, int>{};
    for (final doc in users.docs) {
      final city = (doc.data()['city'] ?? '').toString().trim();
      if (city.isEmpty) continue;
      cityCounts[city] = (cityCounts[city] ?? 0) + 1;
    }
    final cities = cityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (mounted) {
      setState(() {
        _allowed = true;
        _loading = false;
        _metrics = {
          'Toplam kullanıcı': counts[0],
          'Toplam paylaşım': counts[1],
          'Toplam etkinlik': counts[2],
          'Doğrulanmış işletme': counts[3],
          'İşletme adayı': counts[4],
        };
        _cities = cities.take(15).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true)
      return const Scaffold(
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Büyüme ve Dönüşüm'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: _metrics.entries
                .map((e) => _MetricCard(label: e.key, value: e.value))
                .toList(),
          ),
          const SizedBox(height: 22),
          const Text(
            'Şehir bazlı kullanıcı yoğunluğu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ..._cities.map(
            (e) => Card(
              child: ListTile(
                title: Text(e.key),
                trailing: Text(
                  '${e.value}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bu ekranı ileride kayıt → aktif kullanıcı, etkinlik katılımı, reklam ve işletme → premium dönüşüm oranlarıyla genişletebiliriz. Veri geldikçe oranlar gerçek zamanlı hesaplanacak.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminRolePreviewScreen extends StatefulWidget {
  const AdminRolePreviewScreen({super.key});

  @override
  State<AdminRolePreviewScreen> createState() => _AdminRolePreviewScreenState();
}

class _AdminRolePreviewScreenState extends State<AdminRolePreviewScreen> {
  bool? _allowed;
  String _role = 'guest';

  static const _roles = <String, ({String label, IconData icon})>{
    'guest': (label: 'Misafir', icon: Icons.visibility_outlined),
    'user': (label: 'Normal Kullanıcı', icon: Icons.person_outline_rounded),
    'organizer': (
      label: 'Etkinlik Düzenleyici',
      icon: Icons.event_available_outlined,
    ),
    'business': (label: 'İşletme', icon: Icons.storefront_outlined),
    'verified': (label: 'Doğrulanmış İşletme', icon: Icons.verified_outlined),
    'premium': (
      label: 'Premium İşletme',
      icon: Icons.workspace_premium_outlined,
    ),
  };

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _allowed = AdminAccess.tokenMatches(user, token));
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true)
      return const Scaffold(
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rol Önizleme')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(gradient: AppColors.accentGradient),
            child: Text(
              'ÖNİZLEME MODU • ${_roles[_role]!.label} • Gerçek veriye yazılmaz',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF07080C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              children: _roles.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _role == e.key,
                        avatar: Icon(e.value.icon, size: 18),
                        label: Text(e.value.label),
                        onSelected: (_) => setState(() => _role = e.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(child: _RolePreviewBody(role: _role)),
        ],
      ),
    );
  }
}

class _RolePreviewBody extends StatelessWidget {
  final String role;
  const _RolePreviewBody({required this.role});

  @override
  Widget build(BuildContext context) {
    final data = switch (role) {
      'guest' => (
        title: 'Misafir görünümü',
        subtitle: 'Kayıt olmadan uygulamayı gezen kişinin deneyimi.',
        items: const [
          ('Ana akışı görüntüle', 'Fotoğraf/video içeriklerini görebilir.'),
          (
            'Mekanları gez',
            'Gezilecek yer, kafe, yeme-içme ve otelleri görebilir.',
          ),
          ('Çevrende', 'Yakındaki plan ve etkinlikleri inceleyebilir.'),
          ('Kişisel işlem', 'Beğeni, yorum, mesaj ve katılımda giriş istenir.'),
        ],
      ),
      'user' => (
        title: 'Normal kullanıcı görünümü',
        subtitle: 'Sosyal özellikleri kullanan kayıtlı kullanıcı.',
        items: const [
          ('Paylaşım', 'Fotoğraf, Story ve Reels paylaşabilir.'),
          ('Etkileşim', 'Beğeni, yorum, mesaj ve paylaşım kullanabilir.'),
          (
            'Etkinlik',
            'Katılabilir, ilgileniyorum diyebilir ve etkinlik oluşturabilir.',
          ),
          ('Profil', 'Gönderiler, takip, etiketler ve kaydedilenler.'),
        ],
      ),
      'organizer' => (
        title: 'Etkinlik düzenleyici görünümü',
        subtitle: 'Etkinlik oluşturma ve yönetme akışı.',
        items: const [
          ('Kapak fotoğrafı', 'Kamera veya galeriden etkinlik görseli ekler.'),
          ('Konum', 'Haritadan gerçek konum seçer.'),
          ('Kapasite', 'Katılımcı sayısı ve görünürlük belirler.'),
          ('Takip', 'Katılım ve etkinlik hareketlerini izler.'),
        ],
      ),
      'business' => (
        title: 'İşletme başvuru görünümü',
        subtitle: 'Henüz doğrulanmamış işletmenin gördüğü süreç.',
        items: const [
          ('Mekan bilgisi', 'Mekan adı, kategori ve mekan kimliği.'),
          (
            'Şirket bilgileri',
            'Yasal unvan, e-posta, telefon ve vergi bilgisi.',
          ),
          (
            'Yetki kanıtı',
            'Belge/fotoğraf yükleyerek manuel doğrulamaya gönderir.',
          ),
          ('Bekleme durumu', 'Onaylanana kadar yönetim araçları kapalıdır.'),
        ],
      ),
      'verified' => (
        title: 'Doğrulanmış işletme görünümü',
        subtitle: 'İşletme panelinin açılmış hali.',
        items: const [
          ('Menü Yönetimi', 'Ürün, bölüm, açıklama ve fiyat ekler.'),
          ('Program / Takvim', 'Canlı müzik, workshop, maç yayını vb. ekler.'),
          ('Etkinlik oluştur', 'İşletme adına fotoğraflı etkinlik oluşturur.'),
          (
            'İstatistikler',
            'Görüntülenme ve etkileşim metriklerini takip eder.',
          ),
        ],
      ),
      _ => (
        title: 'Premium işletme görünümü',
        subtitle: 'İlk işletmelere ücretsiz sunduğumuz ileri araçlar.',
        items: const [
          ('İşletme Premium', 'İlk 3 ay ücretsiz Premium erişimi.'),
          (
            'Gelişmiş istatistik',
            'İçerik ve etkinlik performansını karşılaştırır.',
          ),
          (
            'Öne çıkarma araçları',
            'İleride ücretli olacak görünürlük seçenekleri.',
          ),
          (
            'Kampanya yönetimi',
            'İleride reklam ve promosyon yönetimine bağlanır.',
          ),
        ],
      ),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      children: [
        Text(
          data.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(data.subtitle, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        ...data.items.map(
          (item) => _PreviewTile(title: item.$1, subtitle: item.$2),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: AppColors.cyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu mod yalnız görünüm ve akış kontrolü içindir. Gerçek mesaj, ödeme, doğrulama, ban veya veri oluşturma işlemi yapmaz.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PreviewTile({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(
        Icons.check_circle_outline_rounded,
        color: AppColors.cyan,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.visibility_outlined),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  const _MetricCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
