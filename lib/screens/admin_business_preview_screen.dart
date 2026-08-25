import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'business_hub_screen.dart';

class AdminBusinessPreviewScreen extends StatefulWidget {
  const AdminBusinessPreviewScreen({super.key});

  @override
  State<AdminBusinessPreviewScreen> createState() => _AdminBusinessPreviewScreenState();
}

class _AdminBusinessPreviewScreenState extends State<AdminBusinessPreviewScreen> {
  bool? _allowed;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    if (mounted) setState(() => _allowed = token?.claims?['admin'] == true);
  }

  void _openPreview(BuildContext context, Map<String, dynamic> d) {
    final category = (d['category'] ?? 'cafe').toString();
    final venueId = (d['venueId'] ?? '').toString();
    final venueName = (d['venueName'] ?? d['legalName'] ?? 'Örnek İşletme').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessHubScreen(
          initialCategory: category,
          initialVenueId: venueId.isEmpty ? 'admin_preview' : venueId,
          initialVenueName: venueName,
          previewMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_allowed != true) return const Scaffold(body: Center(child: Text('Yönetici yetkisi gerekli.')));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('İşletme Paneli Önizleme')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF112229), Color(0xFF1A1428)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cyan.withValues(alpha: .35)),
          ),
          child: const Row(children: [
            Icon(Icons.visibility_rounded, color: AppColors.cyan),
            SizedBox(width: 10),
            Expanded(child: Text('Bir işletme seç. Panel işletme sahibinin gördüğü şekilde açılır; önizleme modunda gerçek veri değişmez.', style: TextStyle(color: Colors.white70, height: 1.35))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'İşletme ara'),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront_rounded)),
            title: const Text('Demo İşletme', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Gerçek işletme kaydı olmadan paneli test et.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPreview(context, {'category':'cafe','venueId':'admin_demo','venueName':'TBT Demo İşletme'}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('business_claims').limit(250).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.where((doc) {
                final d = doc.data();
                final text = '${d['venueName'] ?? ''} ${d['legalName'] ?? ''} ${d['category'] ?? ''}'.toLowerCase();
                return _query.isEmpty || text.contains(_query);
              }).toList();
              if (docs.isEmpty) return const Center(child: Text('İşletme bulunamadı.'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final status = (d['status'] ?? '').toString();
                  return Card(
                    child: ListTile(
                      leading: Icon(status == 'verified' ? Icons.verified_rounded : Icons.storefront_outlined, color: status == 'verified' ? AppColors.cyan : Colors.white60),
                      title: Text((d['venueName'] ?? d['legalName'] ?? 'İşletme').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('${d['category'] ?? ''} • $status'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => _openPreview(context, d),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
