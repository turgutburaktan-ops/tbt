import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminMusicScreen extends StatefulWidget {
  const AdminMusicScreen({super.key});

  @override
  State<AdminMusicScreen> createState() => _AdminMusicScreenState();
}

class _AdminMusicScreenState extends State<AdminMusicScreen> {
  final _db = FirebaseFirestore.instance;
  final Set<String> _busy = <String>{};

  Future<void> _review(DocumentSnapshot<Map<String, dynamic>> doc, bool approve) async {
    if (_busy.contains(doc.id)) return;
    setState(() => _busy.add(doc.id));
    final data = doc.data() ?? const <String, dynamic>{};
    try {
      final batch = _db.batch();
      if (approve) {
        final rights = data['commercialUseAllowed'] == true &&
            data['derivativesAllowed'] == true &&
            data['catalogDistributionAllowed'] == true;
        final audioUrl = (data['audioUrl'] ?? '').toString();
        if (!rights || !audioUrl.startsWith('https://')) {
          throw Exception('Lisans izinleri veya HTTPS ses bağlantısı eksik.');
        }
        batch.set(_db.collection('music_tracks').doc(doc.id), <String, dynamic>{
          'title': data['title'],
          'artist': data['artist'],
          'audioUrl': audioUrl,
          'artworkUrl': data['artworkUrl'] ?? '',
          'sourceUrl': data['sourceUrl'] ?? '',
          'category': data['category'] ?? 'Türkçe',
          'mood': data['mood'] ?? 'Seyahat',
          'durationMs': (data['durationMs'] as num?)?.toInt() ?? 180000,
          'license': data['licenseType'] ?? 'DIRECT-TBT',
          'licenseType': data['licenseType'] ?? 'DIRECT-TBT',
          'attributionText': data['attributionText'] ?? '',
          'commercialUseAllowed': true,
          'derivativesAllowed': true,
          'catalogDistributionAllowed': true,
          'active': true,
          'trending': false,
          'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
          'verifiedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(doc.reference, <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  Future<void> _resolveTakedown(DocumentSnapshot<Map<String, dynamic>> doc, bool remove) async {
    if (_busy.contains(doc.id)) return;
    setState(() => _busy.add(doc.id));
    try {
      final data = doc.data() ?? const <String, dynamic>{};
      final batch = _db.batch();
      final trackId = (data['trackId'] ?? '').toString();
      if (remove && trackId.isNotEmpty && !trackId.startsWith('commons_')) {
        batch.set(_db.collection('music_tracks').doc(trackId), <String, dynamic>{
          'active': false,
          'disabledReason': 'rights_request',
          'disabledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      batch.update(doc.reference, <String, dynamic>{
        'status': remove ? 'removed' : 'dismissed',
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Müzik Yönetimi'),
        bottom: const TabBar(tabs: <Widget>[Tab(text: 'Başvurular'), Tab(text: 'Hak Bildirimleri')]),
      ),
      body: TabBarView(children: <Widget>[
        _queue(
          collection: 'music_submissions',
          empty: 'Bekleyen müzik başvurusu yok.',
          builder: (doc) {
            final d = doc.data()!;
            return _ReviewCard(
              title: (d['title'] ?? 'Müzik').toString(),
              subtitle: '${d['artist'] ?? ''} • ${d['licenseType'] ?? ''}',
              detail: '${d['category'] ?? ''} / ${d['mood'] ?? ''}\n${d['audioUrl'] ?? ''}',
              busy: _busy.contains(doc.id),
              approveLabel: 'Onayla',
              onReject: () => _review(doc, false),
              onApprove: () => _review(doc, true),
            );
          },
        ),
        _queue(
          collection: 'music_takedown_requests',
          empty: 'Bekleyen hak bildirimi yok.',
          builder: (doc) {
            final d = doc.data()!;
            return _ReviewCard(
              title: (d['title'] ?? d['trackId'] ?? 'Müzik').toString(),
              subtitle: (d['reporterEmail'] ?? '').toString(),
              detail: (d['reason'] ?? '').toString(),
              busy: _busy.contains(doc.id),
              approveLabel: 'Yayından kaldır',
              onReject: () => _resolveTakedown(doc, false),
              onApprove: () => _resolveTakedown(doc, true),
            );
          },
        ),
      ]),
    ),
  );

  Widget _queue({
    required String collection,
    required String empty,
    required Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) builder,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _db.collection(collection).where('status', isEqualTo: 'pending').limit(100).snapshots(),
    builder: (_, snap) {
      if (snap.hasError) return const Center(child: Text('Kuyruk yüklenemedi.'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return Center(child: Text(empty));
      return ListView(padding: const EdgeInsets.all(14), children: snap.data!.docs.map(builder).toList());
    },
  );
}

class _ReviewCard extends StatelessWidget {
  final String title, subtitle, detail, approveLabel;
  final bool busy;
  final VoidCallback onReject, onApprove;
  const _ReviewCard({required this.title, required this.subtitle, required this.detail, required this.busy, required this.approveLabel, required this.onReject, required this.onApprove});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        Text(subtitle, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        Text(detail, maxLines: 5, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: <Widget>[
          Expanded(child: OutlinedButton(onPressed: busy ? null : onReject, child: const Text('Reddet'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: busy ? null : onApprove, child: Text(approveLabel))),
        ]),
      ]),
    ),
  );
}
