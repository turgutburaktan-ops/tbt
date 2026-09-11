import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../services/admin_access.dart';
import '../theme/app_theme.dart';
import 'admin_business_sandbox_screen.dart';

class AdminBusinessPreviewScreen extends StatefulWidget {
  const AdminBusinessPreviewScreen({super.key});

  @override
  State<AdminBusinessPreviewScreen> createState() =>
      _AdminBusinessPreviewScreenState();
}

class _AdminBusinessPreviewScreenState
    extends State<AdminBusinessPreviewScreen> {
  bool? _allowed;
  bool _loading = true;
  String _query = '';
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(
      true,
    );
    final allowed = AdminAccess.tokenMatches(user, token);
    if (!allowed) {
      if (mounted) {
        setState(() {
          _allowed = false;
          _loading = false;
        });
      }
      return;
    }
    try {
      final items = await AdminConsoleService.instance.businessClaims();
      if (mounted) {
        setState(() {
          _allowed = true;
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allowed = true;
          _items = const [];
          _loading = false;
        });
      }
    }
  }

  void _openSandbox(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'cafe').toString();
    final venueName =
        (data['venueName'] ?? data['legalName'] ?? 'TBT Demo İşletme')
            .toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBusinessSandboxScreen(
          venueName: venueName,
          category: category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    }

    final docs = _items.where((data) {
      final text =
          '${data['venueName'] ?? ''} ${data['legalName'] ?? ''} ${data['category'] ?? ''}'
              .toLowerCase();
      return _query.isEmpty || text.contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletme Test Merkezi'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF112229), Color(0xFF1A1428)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cyan.withValues(alpha: .35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: AppColors.cyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bir işletme seç ve sahibi gibi paneli dene. Menü, kampanya, etkinlik, çalışma saati ve profil değişiklikleri yalnızca test ekranında tutulur; gerçek işletmeye veya Firebase’e kaydolmaz.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'İşletme ara',
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.science_outlined)),
              title: const Text(
                'TBT Demo İşletme',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Gerçek işletme seçmeden tüm panel işlemlerini dene.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openSandbox({
                'category': 'cafe',
                'venueName': 'TBT Demo İşletme',
              }),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : docs.isEmpty
                ? const Center(child: Text('İşletme bulunamadı.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final status = (data['status'] ?? '').toString();
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
                              (data['venueName'] ??
                                      data['legalName'] ??
                                      'İşletme')
                                  .toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${data['category'] ?? 'işletme'} • ${status.isEmpty ? 'kayıtlı' : status}',
                            ),
                            trailing: const Icon(Icons.science_outlined),
                            onTap: () => _openSandbox(data),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
