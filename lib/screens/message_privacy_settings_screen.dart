import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class MessagePrivacySettingsScreen extends StatefulWidget {
  const MessagePrivacySettingsScreen({super.key});
  @override
  State<MessagePrivacySettingsScreen> createState() => _MessagePrivacySettingsScreenState();
}

class _MessagePrivacySettingsScreenState extends State<MessagePrivacySettingsScreen> {
  bool _saving = false;
  Future<void> _save(String key, bool enabled) async {
    setState(() => _saving = true);
    try {
      await ChatService.instance.action('messagePrivacy', {'key': key, 'enabled': enabled});
      if (key == 'showOnlineStatus' && enabled) await ChatService.instance.refreshPresence();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayar kaydedilemedi. Tekrar dene.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesaj ayarları')),
      body: uid == null ? const Center(child: Text('Giriş yapmalısın.')) : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Ayarlar yüklenemedi.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() ?? {};
          return ListView(children: [
            if (_saving) const LinearProgressIndicator(),
            SwitchListTile(
              secondary: const Icon(Icons.done_all),
              title: const Text('Görüldü bilgisi'),
              subtitle: const Text('Kapalıyken yeni okuduğun mesajlar için görüldü bilgisi gönderilmez. Birebir ve grup sohbetlerinde geçerlidir.'),
              value: data['showReadReceipts'] != false,
              onChanged: _saving ? null : (v) => _save('showReadReceipts', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.circle_outlined),
              title: const Text('Çevrimiçi durumu'),
              subtitle: const Text('Kapalıyken çevrimiçi olduğun ve son görülme zamanın gösterilmez.'),
              value: data['showOnlineStatus'] != false,
              onChanged: _saving ? null : (v) => _save('showOnlineStatus', v),
            ),
            const Padding(padding: EdgeInsets.all(16), child: Text('Bu tercihler hesabındaki tüm sohbetler için geçerlidir. Sohbete özel kapattığın görüldü ayarı da korunur.', style: TextStyle(color: Colors.grey))),
          ]);
        },
      ),
    );
  }
}
