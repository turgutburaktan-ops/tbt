import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppOnboardingScreen extends StatefulWidget {
  const AppOnboardingScreen({super.key});

  @override
  State<AppOnboardingScreen> createState() => _AppOnboardingScreenState();
}

class _AppOnboardingScreenState extends State<AppOnboardingScreen> {
  final Set<String> _interests = {};
  final _city = TextEditingController();
  bool _eventAlerts = true;
  bool _socialAlerts = true;
  bool _preciseLocationForAttendeesOnly = true;
  bool _analyticsConsent = true;
  bool _saving = false;

  static const _choices = [
    'Fotoğraf', 'Gezi', 'Kahve', 'Doğa', 'Spor', 'Müzik', 'Kamp', 'Yemek',
  ];

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'city': _city.text.trim(),
        'interests': _interests.toList(),
        'appOnboardingCompleted': true,
        'notificationPreferences': {
          'events': _eventAlerts,
          'social': _socialAlerts,
          'messages': true,
          'likes': true,
          'comments': true,
          'marketing': false,
        },
        'privacy': {
          'locationVisibility': 'approximate',
          'preciseEventLocationOnlyForAttendees': _preciseLocationForAttendeesOnly,
          'analyticsConsent': _analyticsConsent,
        },
        'onboardingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TBT’yi Sana Göre Ayarla')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Neler ilgini çekiyor?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _choices.map((value) => FilterChip(
              label: Text(value),
              selected: _interests.contains(value),
              onSelected: (selected) => setState(() {
                selected ? _interests.add(value) : _interests.remove(value);
              }),
            )).toList(),
          ),
          const SizedBox(height: 20),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Şehir')),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _eventAlerts,
            onChanged: (v) => setState(() => _eventAlerts = v),
            title: const Text('Yakındaki etkinlikleri haber ver'),
            subtitle: const Text('Radar ve sosyal hayat önerileri için.'),
          ),
          SwitchListTile(
            value: _socialAlerts,
            onChanged: (v) => setState(() => _socialAlerts = v),
            title: const Text('Sosyal bildirimler'),
            subtitle: const Text('Takip, yorum, beğeni ve topluluk hareketleri.'),
          ),
          SwitchListTile(
            value: _preciseLocationForAttendeesOnly,
            onChanged: (v) => setState(() => _preciseLocationForAttendeesOnly = v),
            title: const Text('Kesin etkinlik konumunu yalnız katılımcılar görsün'),
          ),
          SwitchListTile(
            value: _analyticsConsent,
            onChanged: (v) => setState(() => _analyticsConsent = v),
            title: const Text('Anonim kullanım analitiğine izin ver'),
            subtitle: const Text('TBT’nin hangi bölümlerinin geliştirilmesi gerektiğini anlamamıza yardım eder.'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _finish,
            child: Text(_saving ? 'Kaydediliyor…' : 'TBT’ye Başla'),
          ),
        ],
      ),
    );
  }
}
