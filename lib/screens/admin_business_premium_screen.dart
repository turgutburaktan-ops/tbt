import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminBusinessPremiumScreen extends StatefulWidget {
  const AdminBusinessPremiumScreen({super.key});

  @override
  State<AdminBusinessPremiumScreen> createState() =>
      _AdminBusinessPremiumScreenState();
}

class _AdminBusinessPremiumScreenState
    extends State<AdminBusinessPremiumScreen> {
  final _search = TextEditingController();
  bool? _allowed;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _allowed = token?.claims?['admin'] == true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _category(String value) => switch (value) {
    'cafe' => 'Kafe',
    'dining' => 'Lezzet',
    'hotel' => 'Otel',
    _ => 'İşletme',
  };

  Future<void> _setPremium(
    String venueKey,
    bool enabled,
    int days,
    String note,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = venueKey);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminSetBusinessPremium')
          .call({
            'venueKey': venueKey,
            'enabled': enabled,
            'days': days,
            'note': note,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Business Pro ücretsiz olarak tanımlandı.'
                : 'Admin Premium kaldırıldı.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openGrantDialog(String venueKey, String name) async {
    var days = 30;
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('$name • Ücretsiz Pro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: days,
                decoration: const InputDecoration(labelText: 'Süre'),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 gün')),
                  DropdownMenuItem(value: 30, child: Text('30 gün')),
                  DropdownMenuItem(value: 90, child: Text('90 gün')),
                  DropdownMenuItem(value: 180, child: Text('6 ay')),
                  DropdownMenuItem(value: 365, child: Text('1 yıl')),
                  DropdownMenuItem(value: 3650, child: Text('10 yıl')),
                ],
                onChanged: (value) => setLocal(() => days = value ?? 30),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Admin notu'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ücretsiz Pro Ver'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _setPremium(venueKey, true, days, note.text.trim());
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed != true) {
      return const Scaffold(
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Business Pro Yönetimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'İşletme adı veya mekan kimliği ara',
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // business_claims yalnızca başvuru kayıtlarını içerir. Pro yönetimi
              // gerçek mekan profillerini temel alır; böylece onaylanan işletmeler
              // başvuru belgesi değişse/silinse bile burada görünmeye devam eder.
              stream: FirebaseFirestore.instance
                  .collection('business_venues')
                  .limit(500)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 46),
                          const SizedBox(height: 10),
                          const Text(
                            'İşletmeler yüklenemedi.',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            snapshot.error.toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _search.text.trim().toLowerCase();
                final docs =
                    snapshot.data!.docs.where((doc) {
                      final d = doc.data();
                      final hay =
                          '${d['venueName'] ?? d['name'] ?? ''} ${d['category'] ?? ''} ${d['ownerEmail'] ?? ''} ${doc.id}'
                              .toLowerCase();
                      return q.isEmpty || hay.contains(q);
                    }).toList()..sort((a, b) {
                      final an =
                          (a.data()['venueName'] ?? a.data()['name'] ?? '')
                              .toString();
                      final bn =
                          (b.data()['venueName'] ?? b.data()['name'] ?? '')
                              .toString();
                      return an.compareTo(bn);
                    });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        q.isEmpty
                            ? 'Henüz kayıtlı işletme profili yok.'
                            : 'Aramana uygun işletme bulunamadı.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data();
                    final name = (d['venueName'] ?? d['name'] ?? 'İşletme')
                        .toString();
                    final until = d['adminPremiumUntil'] as Timestamp?;
                    final adminActive =
                        d['adminPremiumStatus'] == 'active' &&
                        until != null &&
                        until.toDate().isAfter(DateTime.now());
                    final early = d['earlyAccessStatus'] == 'active';
                    final paid = d['subscriptionStatus'] == 'active';
                    final verified = d['verified'] == true;
                    final busy = _busyId == doc.id;
                    final category = _category(
                      (d['category'] ?? '').toString(),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          adminActive || paid || early
                              ? Icons.workspace_premium_rounded
                              : verified
                              ? Icons.verified_rounded
                              : Icons.storefront_outlined,
                          color: adminActive || paid || early || verified
                              ? AppColors.cyan
                              : Colors.white54,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            category,
                            verified ? 'Doğrulanmış' : 'Doğrulanmamış',
                            if (paid) 'Ücretli Pro',
                            if (adminActive) 'Admin Pro',
                            if (!adminActive && !paid && early) 'Kurucu Pro',
                          ].join(' • '),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'grant') {
                                    await _openGrantDialog(doc.id, name);
                                  } else if (value == 'remove') {
                                    await _setPremium(
                                      doc.id,
                                      false,
                                      1,
                                      'Admin tarafından kaldırıldı',
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'grant',
                                    child: Text('Ücretsiz Pro ver / uzat'),
                                  ),
                                  if (adminActive)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Admin Pro’yu kaldır'),
                                    ),
                                ],
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
