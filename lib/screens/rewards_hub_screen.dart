import 'retention_hub_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RewardsHubScreen extends StatefulWidget {
  const RewardsHubScreen({super.key});

  @override
  State<RewardsHubScreen> createState() => _RewardsHubScreenState();
}

class _RewardsHubScreenState extends State<RewardsHubScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || FirebaseAuth.instance.currentUser == null) return;
    setState(() => _refreshing = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getMyReputation')
          .call();
    } catch (_) {
      // Firestore'daki son güvenilir durum çevrimdışıyken de gösterilir.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('TBT Yolculuğunu görmek için giriş yapmalısın.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071426),
        title: const Text('TBT Yolculuğum'),
        actions: [
          IconButton(onPressed: _refreshing ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = snapshot.data?.data() ?? const <String, dynamic>{};
          final reputation = _map(user['reputation']);
          final scores = _map(reputation['scores']);
          final roles = _map(user['accountTypes'] ?? reputation['roles']);
          final total = _number(user['reputationTotal'] ?? reputation['total']);
          final verified = user['tbtVerified'] == true || reputation['verified'] == true;
          final ambassador = user['tbtAmbassador'] == true || reputation['ambassador'] == true;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              children: [
                _JourneyHeader(total: total, verified: verified, ambassador: ambassador),
                TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RetentionHubScreen())), icon: const Icon(Icons.local_fire_department_rounded), label: const Text('Bugün TBT')),
                const SizedBox(height: 18),
                const Text('Hesap türlerin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text(
                  'Her alan kendi puanıyla ilerler. Özel davet yalnızca davet edildiğin hesabın şartlarını kaldırır ve ücretsiz puan vermez.',
                  style: TextStyle(color: Color(0xFF9FB0C5), height: 1.45),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  label: 'TBT Creator', icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFFA66BFF), score: _number(scores['creator']), threshold: 500,
                  state: _map(roles['creator']),
                  requirement: '25 özgün içerik ve en az 60 günlük hesap',
                  earning: 'Fotoğraf +5 · Reels +8 · kaliteli içerik bonusu +15',
                ),
                _RoleCard(
                  label: 'TBT Kâşif', icon: Icons.explore_rounded,
                  color: const Color(0xFF42D6C7), score: _number(scores['explorer']), threshold: 400,
                  state: _map(roles['explorer']),
                  requirement: '10 onaylı yer, 20 konumlu paylaşım ve 3 şehir',
                  earning: 'Onaylı yer +30 · konumlu paylaşım +8 · rota +10',
                ),
                _RoleCard(
                  label: 'TBT Sosyal', icon: Icons.groups_rounded,
                  color: const Color(0xFFFF8A65), score: _number(scores['social']), threshold: 350,
                  state: _map(roles['social']),
                  requirement: '5 gerçekleşen etkinlik ve 10 doğrulanmış katılım',
                  earning: 'Gerçekleşen etkinlik +25 · doğrulanmış katılım +10 · anı +5',
                ),
                _RoleCard(
                  label: 'TBT Gurme', icon: Icons.restaurant_rounded,
                  color: const Color(0xFFFFC857), score: _number(scores['gourmet']), threshold: 400,
                  state: _map(roles['gourmet']),
                  requirement: '15 farklı mekân katkısı ve 10 fotoğraflı deneyim',
                  earning: 'Mekân paylaşımı +7 · yorum +8 · rezervasyon/kupon +5',
                ),
                const SizedBox(height: 18),
                _TrustCard(total: total, verified: verified),
                const SizedBox(height: 10),
                _AmbassadorCard(active: ambassador, roles: roles, verified: verified),
              ],
            ),
          );
        },
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _number(dynamic value) => (value as num?)?.toInt() ?? 0;

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.total, required this.verified, required this.ambassador});
  final int total;
  final bool verified;
  final bool ambassador;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF112C4C), Color(0xFF0C2038)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2B4C70)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: ambassador ? const Color(0x33FFD166) : const Color(0x2242D6C7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ambassador ? Icons.explore_rounded : Icons.route_rounded,
                color: ambassador ? const Color(0xFFFFD166) : const Color(0xFF73E4D6),
                size: 31,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ambassador ? 'TBT Elçisi' : verified ? 'Doğrulanmış TBT hesabı' : 'TBT İtibar Puanı',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text('$total gerçek katkı puanı', style: const TextStyle(color: Color(0xFFB6C7DA))),
                ],
              ),
            ),
            if (verified) const Icon(Icons.verified_rounded, color: Color(0xFF52D8FF)),
          ],
        ),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label, required this.icon, required this.color,
    required this.score, required this.threshold, required this.state,
    required this.requirement, required this.earning,
  });
  final String label, requirement, earning;
  final IconData icon;
  final Color color;
  final int score, threshold;
  final Map<String, dynamic> state;

  @override
  Widget build(BuildContext context) {
    final active = state['active'] == true;
    final invited = state['source'] == 'invite';
    final progress = (score / threshold).clamp(0.0, 1.0).toDouble();
    return Card(
      color: const Color(0xFF102139),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                if (active) Icon(Icons.check_circle_rounded, color: color),
              ],
            ),
            const SizedBox(height: 12),
            if (active && invited)
              Text('Özel TBT davetiyle aktif · $score gerçek puan', style: TextStyle(color: color, fontWeight: FontWeight.w700))
            else ...[
              LinearProgressIndicator(value: progress, minHeight: 7, color: color, backgroundColor: Colors.white10),
              const SizedBox(height: 7),
              Text(active ? 'Hesap aktif · $score puan' : '$score / $threshold puan', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 8),
            Text(active ? earning : '$requirement\n$earning', style: const TextStyle(color: Color(0xFF9FB0C5), height: 1.4, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.total, required this.verified});
  final int total;
  final bool verified;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF102139),
        child: ListTile(
          leading: Icon(Icons.verified_user_rounded, color: verified ? const Color(0xFF52D8FF) : Colors.white54),
          title: Text(verified ? 'Doğrulanmış hesap' : 'Doğrulanmış hesap ilerlemesi', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(verified ? 'Güven ve katkı şartlarını tamamladın.' : '${total.clamp(0, 1000)} / 1000 puan · Telefon, e-posta, hesap yaşı ve temiz kullanım şartları aranır.'),
        ),
      );
}

class _AmbassadorCard extends StatelessWidget {
  const _AmbassadorCard({required this.active, required this.roles, required this.verified});
  final bool active, verified;
  final Map<String, dynamic> roles;

  @override
  Widget build(BuildContext context) {
    final completed = const ['creator', 'explorer', 'social', 'gourmet']
        .where((key) => _map(roles[key])['active'] == true)
        .length;
    return Card(
      color: const Color(0xFF18233A),
      child: ListTile(
        leading: Icon(Icons.explore_rounded, color: active ? const Color(0xFFFFD166) : Colors.white54),
        title: const Text('TBT Elçisi', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(active ? 'Dört hesap türünü ve doğrulamayı tamamladın.' : '$completed/4 hesap türü · ${verified ? 'Doğrulama tamam' : 'Doğrulama bekleniyor'}'),
        trailing: active ? const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD166)) : null,
      ),
    );
  }
}
