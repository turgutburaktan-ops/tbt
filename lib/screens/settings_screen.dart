import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'managed_venues_screen.dart';
import 'safety_privacy_center_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>>? get ref =>
      user == null ? null : FirebaseFirestore.instance.collection('users').doc(user!.uid);

  Future<void> _set(String key, bool value) async {
    final document = ref;
    if (document == null) return;
    try {
      await document.update({'settings.$key': value});
    } catch (_) {
      await document.set({
        'settings': {key: value},
      }, SetOptions(merge: true));
    }
  }

  void _soon(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$text yakında kullanıma açılacak.')),
      );

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: u == null
          ? const Center(child: Text('Ayarlar için giriş yapmalısın.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ref!.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final settings = Map<String, dynamic>.from(
                  data['settings'] is Map ? data['settings'] as Map : {},
                );
                final type = (data['profileType'] ?? 'personal').toString();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: [
                    _profile(data, u, type),
                    _title('Hesap'),
                    _tile(Icons.person_outline_rounded, 'Profil bilgileri', 'Ad, kullanıcı adı, biyografi ve profil türü', () => _soon('Profil düzenleme')),
                    _tile(Icons.lock_outline_rounded, 'Şifre ve güvenlik', 'E-posta, telefon ve şifre güvenliği', () => _soon('Hesap güvenliği')),
                    _tile(Icons.verified_user_outlined, 'Doğrulama', 'Hesap ve doğrulama durumunu gör', () => _soon('Doğrulama merkezi')),
                    _title('Gizlilik'),
                    _switch(Icons.lock_person_outlined, 'Gizli hesap', 'Yeni takipçileri sen onayla', settings['privateAccount'] == true, (v) => _set('privateAccount', v)),
                    _switch(Icons.location_off_outlined, 'Konum görünürlüğü', 'Konumunu sosyal içeriklerde göster', settings['locationVisible'] == true, (v) => _set('locationVisible', v)),
                    _tile(Icons.shield_outlined, 'Gizlilik ve güvenlik', 'Mesaj, etiketleme, yorum ve engellenen hesaplar', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyPrivacyCenterScreen()))),
                    _title('Bildirimler'),
                    _switch(Icons.chat_bubble_outline_rounded, 'Mesajlar', 'Yeni mesaj bildirimleri', settings['notifyMessages'] != false, (v) => _set('notifyMessages', v)),
                    _switch(Icons.favorite_border_rounded, 'Beğeni ve yorumlar', 'İçerik etkileşimlerini bildir', settings['notifyEngagement'] != false, (v) => _set('notifyEngagement', v)),
                    _switch(Icons.event_outlined, 'Etkinlikler', 'Daveti, katılımı ve hatırlatmaları bildir', settings['notifyEvents'] != false, (v) => _set('notifyEvents', v)),
                    _switch(Icons.emoji_events_outlined, 'XP ve görevler', 'Puan, seviye ve görev gelişmelerini bildir', settings['notifyRewards'] != false, (v) => _set('notifyRewards', v)),
                    _title('İçerik ve Keşif'),
                    _switch(Icons.play_circle_outline_rounded, 'Videoları otomatik oynat', 'Akış ve keşifte videolar otomatik başlasın', settings['autoplayVideos'] != false, (v) => _set('autoplayVideos', v)),
                    _switch(Icons.visibility_off_outlined, 'Hassas içerik filtresi', 'Hassas olabilecek içerikleri azalt', settings['sensitiveFilter'] != false, (v) => _set('sensitiveFilter', v)),
                    _tile(Icons.interests_outlined, 'İlgi alanları', 'Önerilerini şekillendiren konuları yönet', () => _soon('İlgi alanları')),
                    if (type == 'business_owner' || type == 'venue_manager') ...[
                      _title('Mekanlar ve Yönetim'),
                      _tile(Icons.storefront_outlined, 'Yönettiğim Mekanlar', 'Yetkili olduğun mekanları tek yerden yönet', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagedVenuesScreen()))),
                      _tile(Icons.fact_check_outlined, 'Mekan taleplerim', 'Sahiplik ve yönetici taleplerinin durumunu gör', () => _soon('Mekan talepleri')),
                    ],
                    if (type == 'organizer') ...[
                      _title('Organizatör'),
                      _tile(Icons.event_available_outlined, 'Etkinlik yönetimi', 'Oluşturduğun ve yönettiğin etkinlikleri kontrol et', () => _soon('Etkinlik yönetimi')),
                    ],
                    _title('Uygulama'),
                    _tile(Icons.language_rounded, 'Dil', 'Türkçe', () => _soon('Dil seçimi')),
                    _tile(Icons.storage_outlined, 'Veri ve depolama', 'Video kalitesi, mobil veri ve önbellek', () => _soon('Veri ve depolama')),
                    _tile(Icons.help_outline_rounded, 'Yardım ve destek', 'Yardım merkezi, kurallar ve geri bildirim', () => _soon('Yardım merkezi')),
                    _tile(Icons.info_outline_rounded, 'TBT hakkında', 'Gizlilik, kullanım şartları ve sürüm bilgisi', () => _soon('TBT hakkında')),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () async {
                        await AuthService.instance.logout();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Çıkış Yap'),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _profile(Map<String, dynamic> d, User u, String type) {
    final name = (d['displayName'] ?? u.displayName ?? 'TBT Kullanıcısı').toString();
    final username = (d['username'] ?? '').toString();
    final photo = (d['photoUrl'] ?? u.photoURL ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: AppColors.surfaceStrong,
          backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
          child: photo.isEmpty ? const Icon(Icons.person_outline_rounded) : null,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if (username.isNotEmpty)
              Text(username.startsWith('@') ? username : '@$username', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 3),
            Text(_type(type), style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  String _type(String v) => switch (v) {
        'creator' => 'İçerik Üreticisi',
        'business_owner' => 'İşletme Sahibi',
        'venue_manager' => 'Mekan Yöneticisi',
        'organizer' => 'Organizatör',
        _ => 'Kişisel',
      };

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(t, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 13)),
      );

  Widget _tile(IconData i, String t, String s, VoidCallback tap) => Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: ListTile(
          leading: Icon(i),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: tap,
        ),
      );

  Widget _switch(IconData i, String t, String s, bool value, ValueChanged<bool> onChanged) => Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: SwitchListTile(
          secondary: Icon(i),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(s),
          value: value,
          onChanged: (v) async {
            await onChanged(v);
            if (mounted) setState(() {});
          },
        ),
      );
}
