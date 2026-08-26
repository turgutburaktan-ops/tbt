import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _db = FirebaseFirestore.instance;
  bool _checking = true;
  bool _isAdmin = false;
  bool _loadingStats = false;
  Map<String, int> _stats = const {};
  Map<String, int> _gender = const {};
  String _range = '7d';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdTokenResult(true);
      final allowed = token?.claims?['admin'] == true;
      if (!mounted) return;
      setState(() {
        _isAdmin = allowed;
        _checking = false;
      });
      if (allowed) await _loadStats();
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  DateTime _fromDate() {
    final now = DateTime.now();
    return switch (_range) {
      '1d' => now.subtract(const Duration(days: 1)),
      '30d' => now.subtract(const Duration(days: 30)),
      _ => now.subtract(const Duration(days: 7)),
    };
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  Future<void> _loadStats() async {
    if (_loadingStats) return;
    setState(() => _loadingStats = true);
    try {
      final from = Timestamp.fromDate(_fromDate());
      final results = await Future.wait<int>([
        _count(_db.collection('users')),
        _count(
          _db
              .collection('users')
              .where('lastActiveAt', isGreaterThanOrEqualTo: from),
        ),
        _count(
          _db
              .collection('users')
              .where('createdAt', isGreaterThanOrEqualTo: from),
        ),
        _count(
          _db
              .collection('posts')
              .where('createdAt', isGreaterThanOrEqualTo: from),
        ),
        _count(
          _db
              .collection('stories')
              .where('createdAt', isGreaterThanOrEqualTo: from),
        ),
        _count(
          _db
              .collection('social_events')
              .where('createdAt', isGreaterThanOrEqualTo: from),
        ),
        _count(
          _db
              .collection('business_claims')
              .where('status', isEqualTo: 'pending_review'),
        ),
        _count(
          _db
              .collection('business_claims')
              .where('status', isEqualTo: 'verified'),
        ),
      ]);

      final genderValues = <String, String>{
        'Kadın': 'female',
        'Erkek': 'male',
        'Diğer': 'other',
        'Belirtmek istemiyor': 'prefer_not_to_say',
      };
      final genderCounts = <String, int>{};
      for (final item in genderValues.entries) {
        genderCounts[item.key] = await _count(
          _db.collection('users').where('gender', isEqualTo: item.value),
        );
      }

      if (!mounted) return;
      setState(() {
        _stats = {
          'Toplam kullanıcı': results[0],
          'Aktif kullanıcı': results[1],
          'Yeni kayıt': results[2],
          'Paylaşım': results[3],
          'Story': results[4],
          'Etkinlik': results[5],
          'Bekleyen işletme': results[6],
          'Doğrulanmış işletme': results[7],
        };
        _gender = genderCounts;
      });
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _reviewClaim(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) async {
    final data = doc.data() ?? const <String, dynamic>{};
    String reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Başvuruyu reddet'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Red gerekçesi',
              hintText: 'Eksik belge, eşleşmeyen bilgiler vb.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Reddet'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (result == null || result.trim().length < 3) return;
      reason = result.trim();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İşletmeyi doğrula?'),
          content: const Text(
            'Belge, iletişim bilgileri ve mekan eşleşmesini kontrol ettiğini onaylıyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kontrol Ettim'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final callableUrl = Uri.parse(
      'https://us-central1-en-iyi-cekim-noktasi.cloudfunctions.net/adminReviewBusinessClaim',
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    final body = Uri(
      queryParameters: {
        'claimId': doc.id,
        'action': approve ? 'approve' : 'reject',
        if (reason.isNotEmpty) 'reason': reason,
      },
    ).query;

    final launched = await launchUrl(
      callableUrl.replace(query: body),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: token,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama işlemi başlatılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu ekran yalnızca TBT yöneticilerine açıktır.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TBT Yönetim Paneli'),
        actions: [
          IconButton(
            onPressed: _loadingStats ? null : _loadStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1d', label: Text('Bugün')),
                ButtonSegment(value: '7d', label: Text('7 Gün')),
                ButtonSegment(value: '30d', label: Text('30 Gün')),
              ],
              selected: {_range},
              onSelectionChanged: (values) {
                setState(() => _range = values.first);
                _loadStats();
              },
            ),
            const SizedBox(height: 16),
            if (_loadingStats && _stats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.65,
                children: _stats.entries
                    .map(
                      (entry) =>
                          _MetricCard(label: entry.key, value: entry.value),
                    )
                    .toList(),
              ),
            const SizedBox(height: 22),
            const Text(
              'Eşitlik görünümü',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cinsiyet bilgisi yalnız toplu istatistik olarak gösterilir. 10 kişiden küçük gruplar gizlenir.',
              style: TextStyle(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 10),
            ..._gender.entries.map((entry) {
              final visible = entry.value >= 10;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                trailing: Text(
                  visible ? '${entry.value}' : '<10',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
            const Divider(height: 34),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'İşletme doğrulama kuyruğu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('business_claims')
                      .where('status', isEqualTo: 'pending_review')
                      .snapshots(),
                  builder: (_, snapshot) => Badge(
                    label: Text('${snapshot.data?.docs.length ?? 0}'),
                    child: const Icon(Icons.verified_user_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('business_claims')
                  .where('status', isEqualTo: 'pending_review')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Bekleyen işletme başvurusu yok.'),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data();
                    final legalName =
                        (d['legalName'] ?? d['venueName'] ?? 'İşletme')
                            .toString();
                    final proofUrl = (d['proofUrl'] ?? '').toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              legalName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('E-posta: ${d['businessEmail'] ?? '-'}'),
                            Text('Telefon: ${d['businessPhone'] ?? '-'}'),
                            Text('Vergi dairesi: ${d['taxOffice'] ?? '-'}'),
                            Text(
                              'Vergi no son 4: ${d['taxNumberLast4'] ?? '-'}',
                            ),
                            const SizedBox(height: 8),
                            if (proofUrl.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse(proofUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('Yetki kanıtını aç'),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _reviewClaim(doc, false),
                                    child: const Text('Reddet'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _reviewClaim(doc, true),
                                    icon: const Icon(Icons.verified_rounded),
                                    label: const Text('Doğrula'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
