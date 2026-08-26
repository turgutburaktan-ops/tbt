import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'managed_venues_screen.dart';
import 'safety_privacy_center_screen.dart';
import 'social_events_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>>? get ref => user == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(user!.uid);

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

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editProfile(Map<String, dynamic> data) async {
    final u = user;
    final document = ref;
    if (u == null || document == null) return;

    final name = TextEditingController(
      text: (data['displayName'] ?? u.displayName ?? '').toString(),
    );
    final bio = TextEditingController(text: (data['bio'] ?? '').toString());
    var type = (data['profileType'] ?? 'personal').toString();
    const allowed = <String>{
      'personal',
      'creator',
      'business_owner',
      'venue_manager',
      'organizer',
    };
    if (!allowed.contains(type)) type = 'personal';

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Profil bilgileri',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Görünen ad'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bio,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Biyografi'),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Profil türü'),
                items: const [
                  DropdownMenuItem(value: 'personal', child: Text('Kişisel')),
                  DropdownMenuItem(
                    value: 'creator',
                    child: Text('İçerik Üreticisi'),
                  ),
                  DropdownMenuItem(
                    value: 'business_owner',
                    child: Text('İşletme Sahibi'),
                  ),
                  DropdownMenuItem(
                    value: 'venue_manager',
                    child: Text('Mekan Yöneticisi'),
                  ),
                  DropdownMenuItem(
                    value: 'organizer',
                    child: Text('Organizatör'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setSheet(() => type = value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil türü yetki veya doğrulanmış rozet vermez. Mekan yönetimi ayrıca doğrulanır.',
                style: TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );

    if (save == true) {
      final displayName = name.text.trim();
      if (displayName.length < 2) {
        _message('Görünen ad en az 2 karakter olmalı.');
      } else {
        await document.set({
          'displayName': displayName,
          'bio': bio.text.trim(),
          'profileType': type,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await u.updateDisplayName(displayName);
        _message('Profil bilgilerin güncellendi.');
      }
    }
    name.dispose();
    bio.dispose();
  }

  Future<void> _openSecurity() async {
    final u = user;
    if (u == null) return;
    final email = (u.email ?? '').trim();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Şifre ve güvenlik',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _infoRow('E-posta', email.isEmpty ? 'Bağlı değil' : email),
            _infoRow(
              'Telefon',
              (u.phoneNumber ?? '').isEmpty ? 'Bağlı değil' : u.phoneNumber!,
            ),
            const SizedBox(height: 14),
            if (email.isNotEmpty)
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'reset'),
                icon: const Icon(Icons.password_rounded),
                label: const Text('Şifre sıfırlama e-postası gönder'),
              ),
          ],
        ),
      ),
    );
    if (action == 'reset' && email.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _message('Şifre sıfırlama bağlantısı e-posta adresine gönderildi.');
      } on FirebaseAuthException catch (e) {
        _message(e.message ?? 'Şifre sıfırlama e-postası gönderilemedi.');
      }
    }
  }

  Future<void> _openVerification() async {
    final u = user;
    if (u == null) return;
    await u.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    if (fresh == null) return;
    final verified = fresh.emailVerified;
    final phoneVerified = (fresh.phoneNumber ?? '').isNotEmpty;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Doğrulama durumu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusRow('E-posta', verified),
            const SizedBox(height: 9),
            _statusRow('Telefon', phoneVerified),
            const SizedBox(height: 10),
            const Text(
              'Profil türü seçmek, hesabı veya işletmeyi otomatik doğrulamaz.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          if (!verified && fresh.email != null)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'email'),
              child: const Text('E-postayı doğrula'),
            ),
        ],
      ),
    );
    if (action == 'email') {
      try {
        await fresh.sendEmailVerification();
        _message('Doğrulama e-postası gönderildi.');
      } on FirebaseAuthException catch (e) {
        _message(e.message ?? 'Doğrulama e-postası gönderilemedi.');
      }
    }
  }

  Future<void> _editInterests(Map<String, dynamic> settings) async {
    const choices = <String>[
      'Fotoğraf',
      'Gezi',
      'Doğa',
      'Şehir',
      'Etkinlik',
      'Kafe',
      'Lezzet',
      'Sanat',
      'Spor',
    ];
    final selected = <String>{
      ...((settings['interests'] is List)
          ? (settings['interests'] as List).map((e) => e.toString())
          : const <String>[]),
    };
    final save = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'İlgi alanları',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Keşfet ve öneriler bu seçimlerden yararlanır.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: choices.map((item) {
                  return FilterChip(
                    label: Text(item),
                    selected: selected.contains(item),
                    onSelected: (value) => setSheet(() {
                      value ? selected.add(item) : selected.remove(item);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true && ref != null) {
      try {
        await ref!.update({'settings.interests': selected.toList()});
      } catch (_) {
        await ref!.set({
          'settings': {'interests': selected.toList()},
        }, SetOptions(merge: true));
      }
      _message('İlgi alanların güncellendi.');
    }
  }

  void _openStorage() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Veri ve depolama',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Video otomatik oynatma tercihini Ayarlar > İçerik ve Keşif bölümünden değiştirebilirsin.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                Navigator.pop(sheetContext);
                _message('Görsel önbelleği temizlendi.');
              },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Görsel önbelleğini temizle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yardım ve destek'),
        content: const Text(
          'Bir hesabı, içeriği veya mekanı şikayet etmek için ilgili içerikteki üç nokta menüsünü kullan. Hesap güvenliği için Gizlilik ve Güvenlik bölümüne, işletme yönetimi için Yönettiğim Mekanlar bölümüne gidebilirsin.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TBT'),
        content: const Text(
          'TBT; içerik, mekan, gezi noktası ve etkinlikleri tek sosyal keşif deneyiminde bir araya getirir.\n\nTopluluk güvenliği için kullanıcı önerileri ve işletme sahiplikleri doğrulama süreçlerinden geçer.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

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
                    _tile(
                      Icons.person_outline_rounded,
                      'Profil bilgileri',
                      'Ad, biyografi ve profil türü',
                      () => _editProfile(data),
                    ),
                    _tile(
                      Icons.lock_outline_rounded,
                      'Şifre ve güvenlik',
                      'E-posta, telefon ve şifre güvenliği',
                      _openSecurity,
                    ),
                    _tile(
                      Icons.verified_user_outlined,
                      'Doğrulama',
                      'Hesap doğrulama durumunu gör',
                      _openVerification,
                    ),
                    _title('Gizlilik'),
                    _switch(
                      Icons.lock_person_outlined,
                      'Gizli hesap',
                      'Yeni takipçileri sen onayla',
                      settings['privateAccount'] == true,
                      (v) => _set('privateAccount', v),
                    ),
                    _switch(
                      Icons.location_off_outlined,
                      'Konum görünürlüğü',
                      'Konumunu sosyal içeriklerde göster',
                      settings['locationVisible'] == true,
                      (v) => _set('locationVisible', v),
                    ),
                    _tile(
                      Icons.shield_outlined,
                      'Gizlilik ve güvenlik',
                      'Mesaj, etiketleme, yorum ve engellenen hesaplar',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SafetyPrivacyCenterScreen(),
                        ),
                      ),
                    ),
                    _title('Bildirimler'),
                    _switch(
                      Icons.chat_bubble_outline_rounded,
                      'Mesajlar',
                      'Yeni mesaj bildirimleri',
                      settings['notifyMessages'] != false,
                      (v) => _set('notifyMessages', v),
                    ),
                    _switch(
                      Icons.favorite_border_rounded,
                      'Beğeni ve yorumlar',
                      'İçerik etkileşimlerini bildir',
                      settings['notifyEngagement'] != false,
                      (v) => _set('notifyEngagement', v),
                    ),
                    _switch(
                      Icons.event_outlined,
                      'Etkinlikler',
                      'Daveti, katılımı ve hatırlatmaları bildir',
                      settings['notifyEvents'] != false,
                      (v) => _set('notifyEvents', v),
                    ),
                    _switch(
                      Icons.emoji_events_outlined,
                      'XP ve görevler',
                      'Puan, seviye ve görev gelişmelerini bildir',
                      settings['notifyRewards'] != false,
                      (v) => _set('notifyRewards', v),
                    ),
                    _title('İçerik ve Keşif'),
                    _switch(
                      Icons.play_circle_outline_rounded,
                      'Videoları otomatik oynat',
                      'Akış ve keşifte videolar otomatik başlasın',
                      settings['autoplayVideos'] != false,
                      (v) => _set('autoplayVideos', v),
                    ),
                    _switch(
                      Icons.visibility_off_outlined,
                      'Hassas içerik filtresi',
                      'Hassas olabilecek içerikleri azalt',
                      settings['sensitiveFilter'] != false,
                      (v) => _set('sensitiveFilter', v),
                    ),
                    _tile(
                      Icons.interests_outlined,
                      'İlgi alanları',
                      'Önerilerini şekillendiren konuları yönet',
                      () => _editInterests(settings),
                    ),
                    if (type == 'business_owner' ||
                        type == 'venue_manager') ...[
                      _title('Mekanlar ve Yönetim'),
                      _tile(
                        Icons.storefront_outlined,
                        'Yönettiğim Mekanlar',
                        'Yetkili olduğun mekanları tek yerden yönet',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManagedVenuesScreen(),
                          ),
                        ),
                      ),
                    ],
                    if (type == 'organizer') ...[
                      _title('Organizatör'),
                      _tile(
                        Icons.event_available_outlined,
                        'Etkinlik yönetimi',
                        'Etkinliklerini görüntüle, katılımı takip et',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SocialEventsScreen(),
                          ),
                        ),
                      ),
                    ],
                    _title('Uygulama'),
                    _staticTile(Icons.language_rounded, 'Dil', 'Türkçe'),
                    _tile(
                      Icons.storage_outlined,
                      'Veri ve depolama',
                      'Önbellek ve veri tercihleri',
                      _openStorage,
                    ),
                    _tile(
                      Icons.help_outline_rounded,
                      'Yardım ve destek',
                      'Güvenlik, şikayet ve yardım yolları',
                      _showHelp,
                    ),
                    _tile(
                      Icons.info_outline_rounded,
                      'TBT hakkında',
                      'Uygulama ve topluluk bilgileri',
                      _showAbout,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () async {
                        await AuthService.instance.logout();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        }
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
    final name = (d['displayName'] ?? u.displayName ?? 'TBT Kullanıcısı')
        .toString();
    final username = (d['username'] ?? '').toString();
    final photo = (d['photoUrl'] ?? u.photoURL ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
            child: photo.isEmpty
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (username.isNotEmpty)
                  Text(
                    username.startsWith('@') ? username : '@$username',
                    style: const TextStyle(color: Colors.white60),
                  ),
                const SizedBox(height: 3),
                Text(
                  _type(type),
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );

  Widget _tile(IconData i, String t, String s, FutureOr<void> Function() tap) =>
      Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: ListTile(
          leading: Icon(i),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => tap(),
        ),
      );

  Widget _staticTile(IconData i, String t, String s) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: ListTile(
      leading: Icon(i),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(s),
    ),
  );

  Widget _switch(
    IconData i,
    String t,
    String s,
    bool value,
    Future<void> Function(bool) onChanged,
  ) => Card(
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

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _statusRow(String label, bool verified) => Row(
    children: [
      Expanded(child: Text(label)),
      Icon(
        verified ? Icons.verified_rounded : Icons.error_outline_rounded,
        color: verified ? AppColors.cyan : Colors.white38,
      ),
      const SizedBox(width: 5),
      Text(verified ? 'Doğrulandı' : 'Doğrulanmadı'),
    ],
  );
}
