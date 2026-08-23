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
    return snap.count;
  }

  Future<void> _loadStats() async {
    if (_loadingStats) return;
    setState(() => _loadingStats = true);
    try {
      final from = Timestamp.fromDate(_fromDate());
      final results = await Future.wait<int>([
        _count(_db.collection('users')),
        _count(_db.collection('users').where('lastActiveAt', isGreaterThanOrEqualTo: from)),
        _count(_db.collection('users').where('createdAt', isGreaterThanOrEqualTo: from)),
        _count(_db.collection('posts').where('createdAt', isGreaterThanOrEqualTo: from)),
        _count(_db.collection('stories').where('createdAt', isGreaterThanOrEqualTo: from)),
        _count(_db.collection('social_events').where('createdAt', isGreaterThanOrEqualTo: from)),
        _count(_db.collection('business_claims').where('status', isEqualTo: 'pending_review')),
        _count(_db.collection('business_claims').where('status', isEqualTo: 'verified')),
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
            decoration: const InputDecoration(labelText: 'Ret nedeni'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Reddet'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (result == null || result.length < 3) return;
      reason = result;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İşletmeyi doğrula?'),
          content: const Text('Belge, iletişim ve mekan eşleşmesini kontrol ettiğini onaylıyorsun.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Doğrula')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final adminUid = FirebaseAuth.instance.currentUser!.uid;
    final batch = _db.batch();
    batch.update(doc.reference, {
      'status': approve ? 'verified' : 'rejected',
      'verificationLevel': approve ? 'manual_strong' : 'none',
      'verifiedBy': approve ? adminUid : null,
      'verifiedAt': approve ? FieldValue.serverTimestamp() : null,
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (approve) {
      batch.set(
        _db.collection('business_venues').doc(doc.id),
        {
          'venueKey': doc.id,
          'venueId': data['venueId'],
          'category': data['category'],
          'venueName': data['venueName'],
          'ownerUid': data['applicantUid'],
          'verified': true,
          'verificationLevel': 'manual_strong',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': adminUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text('Bu alan yalnız TBT yöneticilerine açıktır.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TBT Yönetim Paneli'),
        actions: [
          IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1d', label: Text('Bugün')),
                ButtonSegment(value: '7d', label: Text('7 Gün')),
                ButtonSegment(value: '30d', label: Text('30 Gün')),
              ],
              selected: {_range},
              showSelectedIcon: false,
              onSelectionChanged: (value) async {
                setState(() => _range = value.first);
                await _loadStats();
              },
            ),
            const SizedBox(height: 16),
            if (_loadingStats && _stats.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _stats.entries
                    .map((e) => _MetricCard(label: e.key, value: e.value))
                    .toList(),
              ),
            const SizedBox(height: 24),
            const Text('Eşitlik görünümü', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text(
              'Cinsiyet dağılımı yalnız toplu olarak gösterilir. 10 kişiden küçük gruplar gizlenir.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _GenderCard(values: _gender),
            const SizedBox(height: 24),
            const Text('İşletme doğrulama kuyruğu', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('business_claims').where('status', isEqualTo: 'pending_review').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const _EmptyCard(text: 'Bekleyen işletme başvurusu yok.');
                }
                return Column(
                  children: docs.map((doc) => _ClaimCard(
                    doc: doc,
                    onApprove: () => _reviewClaim(doc, true),
                    onReject: () => _reviewClaim(doc, false),
                  )).toList(),
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
  Widget build(BuildContext context) => Container(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ]),
      );
}

class _GenderCard extends StatelessWidget {
  final Map<String, int> values;
  const _GenderCard({required this.values});

  @override
  Widget build(BuildContext context) {
    final visible = values.entries.where((e) => e.value >= 10).toList();
    final hidden = values.entries.where((e) => e.value > 0 && e.value < 10).length;
    final total = visible.fold<int>(0, (sum, e) => sum + e.value);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (visible.isEmpty)
            const Text('Henüz güvenli biçimde gösterilecek yeterli veri yok.', style: TextStyle(color: Colors.white54))
          else
            ...visible.map((e) {
              final ratio = total == 0 ? 0.0 : e.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${e.value} • %${(ratio * 100).round()}'),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: ratio, minHeight: 7, borderRadius: BorderRadius.circular(8)),
                ]),
              );
            }),
          if (hidden > 0)
            Text('$hidden küçük grup gizlendi.', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ClaimCard({required this.doc, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? const <String, dynamic>{};
    final evidence = (d['evidenceUrl'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((d['venueName'] ?? 'Mekan').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text('Yasal unvan: ${d['legalName'] ?? '-'}'),
        Text('İşletme e-posta: ${d['businessEmail'] ?? '-'}'),
        Text('Telefon: ${d['businessPhone'] ?? '-'}'),
        Text('Vergi dairesi: ${d['taxOffice'] ?? '-'}'),
        Text('Vergi no son 4: ${d['taxNumberLast4'] ?? '-'}'),
        const SizedBox(height: 10),
        if (evidence.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(evidence), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Yetki kanıtını aç'),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Reddet'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: onApprove, child: const Text('Doğrula'))),
        ]),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white54))),
      );
}
