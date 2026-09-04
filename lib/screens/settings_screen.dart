import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'password_change_screen.dart';
import 'phone_verification_screen.dart';
import 'safety_privacy_center_screen.dart';
import 'social_events_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>>? get _userRef => _user == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_user!.uid);

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _setBool(String key, bool value) async {
    final ref = _userRef;
    if (ref == null) return;
    try {
      await ref.update({'settings.$key': value});
    } catch (_) {
      await ref.set({
        'settings': {key: value},
      }, SetOptions(merge: true));
    }
  }

  Future<void> _editProfile(Map<String, dynamic> data) async {
    final user = _user;
    final ref = _userRef;
    if (user == null || ref == null) return;
    final name = TextEditingController(
      text: (data['displayName'] ?? user.displayName ?? '').toString(),
    );
    final bio = TextEditingController(text: (data['bio'] ?? '').toString());
    var type = (data['profileType'] ?? 'personal').toString();
    const valid = {
      'personal',
      'creator',
      'business_owner',
      'venue_manager',
      'organizer',
    };
    if (!valid.contains(type)) type = 'personal';

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
                decoration: const InputDecoration(labelText: 'Görünen ad'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bio,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Biyografi'),
              ),
              const SizedBox(height: 8),
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
                onChanged: (v) {
                  if (v != null) setSheet(() => type = v);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil türü seçimi hesap veya işletme doğrulaması vermez.',
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
        await ref.set({
          'displayName': displayName,
          'bio': bio.text.trim(),
          'profileType': type,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await user.updateDisplayName(displayName);
        _message('Profil bilgilerin güncellendi.');
      }
    }
    name.dispose();
    bio.dispose();
  }

  Future<void> _security() async {
    final user = _user;
    if (user == null) return;
    final email = (user.email ?? '').trim();
    final passwordProvider = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
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
              (user.phoneNumber ?? '').isEmpty
                  ? 'Bağlı değil'
                  : user.phoneNumber!,
            ),
            if (passwordProvider && email.isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'change'),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Şifremi Değiştir'),
              ),
            ],
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'reset'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Şifre sıfırlama e-postası gönder'),
              ),
            ],
          ],
        ),
      ),
    );
    if (action == 'change') await _changePassword(email);
    if (action == 'reset' && email.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _message('Şifre sıfırlama bağlantısı gönderildi.');
      } on FirebaseAuthException catch (e) {
        _message(e.message ?? 'E-posta gönderilemedi.');
      }
    }
  }

  Future<void> _changePassword(String email) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PasswordChangeScreen(email: email)),
    );
    if (changed == true) {
      _message('Şifren başarıyla değiştirildi.');
    }
  }

  Future<void> _verification() async {
    await _user?.reload();
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Doğrulama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _verificationRow(
              'E-posta',
              user!.emailVerified,
              actionLabel: user.emailVerified ? null : 'Şimdi Doğrula',
              onAction: user.emailVerified
                  ? null
                  : () => Navigator.pop(dialogContext, 'email'),
            ),
            const SizedBox(height: 10),
            _verificationRow(
              'Telefon',
              (user.phoneNumber ?? '').isNotEmpty,
              actionLabel: (user.phoneNumber ?? '').isEmpty
                  ? 'Şimdi Doğrula'
                  : 'Değiştir',
              onAction: () => Navigator.pop(dialogContext, 'phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'check'),
            child: const Text('Durumu Kontrol Et'),
          ),
        ],
      ),
    );

    if (action == 'email') {
      try {
        await user.sendEmailVerification();
        _message('Doğrulama e-postası gönderildi.');
      } on FirebaseAuthException catch (e) {
        _message(e.message ?? 'Doğrulama e-postası gönderilemedi.');
      }
    }
    if (action == 'phone') {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
      );
      if (changed == true) {
        await FirebaseAuth.instance.currentUser?.reload();
        _message('Telefon doğrulaması tamamlandı.');
        if (mounted) setState(() {});
      }
    }
    if (action == 'check') {
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      _message('Doğrulama durumu güncellendi.');
      if (mounted) setState(() {});
    }
  }

  Future<void> _interests(Map<String, dynamic> settings) async {
    const choices = [
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
      builder: (sheetContext) => StatefulBuilder(
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: choices
                    .map(
                      (item) => FilterChip(
                        label: Text(item),
                        selected: selected.contains(item),
                        onSelected: (v) => setSheet(
                          () => v ? selected.add(item) : selected.remove(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true && _userRef != null) {
      try {
        await _userRef!.update({'settings.interests': selected.toList()});
      } catch (_) {
        await _userRef!.set({
          'settings': {'interests': selected.toList()},
        }, SetOptions(merge: true));
      }
      _message('İlgi alanların güncellendi.');
    }
  }

  void _storage() => showModalBottomSheet<void>(
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
          const SizedBox(height: 14),
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

  void _help() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Yardım ve destek'),
      content: const Text(
        'Bir hesabı, içeriği veya mekanı şikayet etmek için ilgili içerikteki üç nokta menüsünü kullan. Hesap güvenliği için Gizlilik ve Güvenlik bölümünü kullanabilirsin.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  void _about() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('TBT'),
      content: const Text(
        'TBT; içerik, mekan, gezi noktası ve etkinlikleri tek sosyal keşif deneyiminde bir araya getirir.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: user == null
          ? const Center(child: Text('Ayarlar için giriş yapmalısın.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userRef!.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final settings = Map<String, dynamic>.from(
                  data['settings'] is Map ? data['settings'] as Map : {},
                );
                final type = (data['profileType'] ?? 'personal').toString();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: [
                    _profile(data, user, type),
                    _section('Hesap'),
                    _tile(
                      Icons.person_outline_rounded,
                      'Profil bilgileri',
                      'Ad, biyografi ve profil türü',
                      () => _editProfile(data),
                    ),
                    _tile(
                      Icons.lock_outline_rounded,
                      'Şifre ve güvenlik',
                      'Mevcut şifrenle yeni şifre oluştur veya sıfırlama bağlantısı al',
                      _security,
                    ),
                    _tile(
                      Icons.verified_user_outlined,
                      'Doğrulama',
                      'E-posta ve telefon doğrulamasını yönet',
                      _verification,
                    ),
                    _section('Gizlilik'),
                    _switchTile(
                      Icons.lock_person_outlined,
                      'Gizli hesap',
                      'Yeni takipçileri sen onayla',
                      settings['privateAccount'] == true,
                      (v) => _setBool('privateAccount', v),
                    ),
                    _switchTile(
                      Icons.location_off_outlined,
                      'Konum görünürlüğü',
                      'Konumunu sosyal içeriklerde göster',
                      settings['locationVisible'] == true,
                      (v) => _setBool('locationVisible', v),
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
                    _section('Bildirimler'),
                    _switchTile(
                      Icons.chat_bubble_outline_rounded,
                      'Mesajlar',
                      'Yeni mesaj bildirimleri',
                      settings['notifyMessages'] != false,
                      (v) => _setBool('notifyMessages', v),
                    ),
                    _switchTile(
                      Icons.favorite_border_rounded,
                      'Beğeni ve yorumlar',
                      'İçerik etkileşimlerini bildir',
                      settings['notifyEngagement'] != false,
                      (v) => _setBool('notifyEngagement', v),
                    ),
                    _switchTile(
                      Icons.event_outlined,
                      'Etkinlikler',
                      'Daveti, katılımı ve hatırlatmaları bildir',
                      settings['notifyEvents'] != false,
                      (v) => _setBool('notifyEvents', v),
                    ),
                    _switchTile(
                      Icons.emoji_events_outlined,
                      'XP ve görevler',
                      'Puan, seviye ve görev gelişmelerini bildir',
                      settings['notifyRewards'] != false,
                      (v) => _setBool('notifyRewards', v),
                    ),
                    _section('İçerik ve Keşif'),
                    _tile(
                      Icons.archive_outlined,
                      'Story Arşivi',
                      'Süresi dolan Story’lerini gör ve yeniden paylaş',
                      () => Navigator.pushNamed(context, '/story-archive'),
                    ),
                    _switchTile(
                      Icons.play_circle_outline_rounded,
                      'Videoları otomatik oynat',
                      'Akış ve keşifte videolar otomatik başlasın',
                      settings['autoplayVideos'] != false,
                      (v) => _setBool('autoplayVideos', v),
                    ),
                    _switchTile(
                      Icons.visibility_off_outlined,
                      'Hassas içerik filtresi',
                      'Hassas olabilecek içerikleri azalt',
                      settings['sensitiveFilter'] != false,
                      (v) => _setBool('sensitiveFilter', v),
                    ),
                    _tile(
                      Icons.interests_outlined,
                      'İlgi alanları',
                      'Önerilerini şekillendiren konuları yönet',
                      () => _interests(settings),
                    ),
                    if (type == 'business_owner' ||
                        type == 'venue_manager') ...[
                      _section('Mekanlar ve Yönetim'),
                      _tile(
                        Icons.storefront_outlined,
                        'İşletme Yönetim Merkezi',
                        'Profil, menü, kampanya ve raporlarını internet sitesinden yönet',
                        () => launchUrl(
                          Uri.parse('https://trtbt.com/#/profil'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                    if (type == 'organizer') ...[
                      _section('Organizatör'),
                      _tile(
                        Icons.event_available_outlined,
                        'Etkinlik yönetimi',
                        'Etkinliklerini görüntüle ve katılımı takip et',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SocialEventsScreen(),
                          ),
                        ),
                      ),
                    ],
                    _section('Uygulama'),
                    _staticTile(Icons.language_rounded, 'Dil', 'Türkçe'),
                    _tile(
                      Icons.storage_outlined,
                      'Veri ve depolama',
                      'Önbellek ve veri tercihleri',
                      _storage,
                    ),
                    _tile(
                      Icons.help_outline_rounded,
                      'Yardım ve destek',
                      'Güvenlik, şikayet ve yardım yolları',
                      _help,
                    ),
                    _tile(
                      Icons.info_outline_rounded,
                      'TBT hakkında',
                      'Uygulama ve topluluk bilgileri',
                      _about,
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

  Widget _profile(Map<String, dynamic> data, User user, String type) {
    final name = (data['displayName'] ?? user.displayName ?? 'TBT Kullanıcısı')
        .toString();
    final username = (data['username'] ?? '').toString();
    final photo = (data['photoUrl'] ?? user.photoURL ?? '').toString();
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
                  _profileTypeLabel(type),
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

  String _profileTypeLabel(String v) => switch (v) {
    'creator' => 'İçerik Üreticisi',
    'business_owner' => 'İşletme Sahibi',
    'venue_manager' => 'Mekan Yöneticisi',
    'organizer' => 'Organizatör',
    _ => 'Kişisel',
  };

  Widget _verificationRow(
    String label,
    bool verified, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              verified ? 'Doğrulandı' : 'Doğrulanmadı',
              style: TextStyle(
                color: verified ? AppColors.cyan : Colors.white54,
              ),
            ),
          ],
        ),
      ),
      Icon(
        verified ? Icons.verified_rounded : Icons.error_outline_rounded,
        color: verified ? AppColors.cyan : Colors.white38,
      ),
      if (actionLabel != null) ...[
        const SizedBox(width: 8),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
  Widget _staticTile(IconData icon, String title, String subtitle) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    ),
  );
  Widget _switchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 7),
    child: SwitchListTile(
      secondary: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (next) async {
        await onChanged(next);
        if (mounted) setState(() {});
      },
    ),
  );
  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
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
}
