import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/trust_safety_service.dart';

class SafetyPrivacyCenterScreen extends StatefulWidget {
  const SafetyPrivacyCenterScreen({super.key});

  @override
  State<SafetyPrivacyCenterScreen> createState() => _SafetyPrivacyCenterScreenState();
}

class _SafetyPrivacyCenterScreenState extends State<SafetyPrivacyCenterScreen> {
  bool _messages = true;
  bool _likes = true;
  bool _comments = true;
  bool _events = true;
  bool _social = true;
  bool _marketing = false;
  bool _attendeesOnly = true;
  bool _analyticsConsent = true;
  String _locationVisibility = 'approximate';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final prefs = data['notificationPreferences'];
    final privacy = data['privacy'];
    if (!mounted) return;
    setState(() {
      if (prefs is Map) {
        _messages = prefs['messages'] != false;
        _likes = prefs['likes'] != false;
        _comments = prefs['comments'] != false;
        _events = prefs['events'] != false;
        _social = prefs['social'] != false;
        _marketing = prefs['marketing'] == true;
      }
      if (privacy is Map) {
        _attendeesOnly = privacy['preciseEventLocationOnlyForAttendees'] != false;
        _analyticsConsent = privacy['analyticsConsent'] != false;
        final visibility = privacy['locationVisibility']?.toString();
        if (visibility == 'hidden' || visibility == 'approximate' || visibility == 'precise') {
          _locationVisibility = visibility!;
        }
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    await TrustSafetyService.instance.updateNotificationPreferences({
      'messages': _messages,
      'likes': _likes,
      'comments': _comments,
      'events': _events,
      'social': _social,
      'marketing': _marketing,
    });
    await TrustSafetyService.instance.updatePrivacy(
      locationVisibility: _locationVisibility,
      preciseEventLocationOnlyForAttendees: _attendeesOnly,
      analyticsConsent: _analyticsConsent,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tercihler kaydedildi.')));
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesap silme talebi'),
        content: const Text('Talebin güvenli şekilde işleme alınır. Kimlik doğrulaması ve gerekli saklama süreleri tamamlandıktan sonra hesap verileri silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Talep Oluştur')),
        ],
      ),
    );
    if (confirmed != true) return;
    await TrustSafetyService.instance.requestAccountDeletion();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hesap silme talebin alındı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik ve Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          const Text('Bildirim tercihleri', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          SwitchListTile(value: _messages, onChanged: (v) => setState(() => _messages = v), title: const Text('Mesajlar')),
          SwitchListTile(value: _likes, onChanged: (v) => setState(() => _likes = v), title: const Text('Beğeniler')),
          SwitchListTile(value: _comments, onChanged: (v) => setState(() => _comments = v), title: const Text('Yorumlar')),
          SwitchListTile(value: _events, onChanged: (v) => setState(() => _events = v), title: const Text('Etkinlikler ve Radar')),
          SwitchListTile(value: _social, onChanged: (v) => setState(() => _social = v), title: const Text('Sosyal hareketler')),
          SwitchListTile(value: _marketing, onChanged: (v) => setState(() => _marketing = v), title: const Text('Tanıtım ve kampanyalar')),
          const Divider(height: 28),
          const Text('Konum gizliliği', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          RadioListTile<String>(value: 'hidden', groupValue: _locationVisibility, onChanged: (v) => setState(() => _locationVisibility = v!), title: const Text('Konumumu gizle')),
          RadioListTile<String>(value: 'approximate', groupValue: _locationVisibility, onChanged: (v) => setState(() => _locationVisibility = v!), title: const Text('Yaklaşık konum')),
          RadioListTile<String>(value: 'precise', groupValue: _locationVisibility, onChanged: (v) => setState(() => _locationVisibility = v!), title: const Text('Kesin konum')),
          SwitchListTile(
            value: _attendeesOnly,
            onChanged: (v) => setState(() => _attendeesOnly = v),
            title: const Text('Etkinlikte kesin konumu yalnız katılımcılara göster'),
          ),
          const Divider(height: 28),
          const Text('Veri ve hesap', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          SwitchListTile(
            value: _analyticsConsent,
            onChanged: (v) => setState(() => _analyticsConsent = v),
            title: const Text('Kullanım analitiği'),
            subtitle: const Text('Ürün geliştirme amaçlı kullanım olaylarının kaydı.'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Verilerim neden kullanılıyor?'),
            subtitle: const Text('Konum, profil ve etkinlik verileri yalnız ilgili özellikleri sunmak ve güvenliği sağlamak için işlenir.'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Hesabımı silme talebi oluştur'),
            onTap: _requestDeletion,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Tercihleri Kaydet')),
        ],
      ),
    );
  }
}
