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
    const validTypes = {
      'personal',
      'creator',
      'business_owner',
      'venue_manager',
      'organizer',
    };
    if (!validTypes.contains(type)) type = 'personal';

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                  DropdownMenuItem(value: 'creator', child: Text('İçerik Üreticisi')),
                  DropdownMenuItem(value: 'business_owner', child: Text('İşletme Sahibi')),
                  DropdownMenuItem(value: 'venue_manager', child: Text('Mekan Yöneticisi')),
                  DropdownMenuItem(value: 'organizer', child: Text('Organizatör')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => type = value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil türü seçimi hesap veya işletme doğrulaması vermez. Mekan yönetimi ayrıca onaylanır.',
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
      (provider) => provider.providerId == 'password',
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
              (user.phoneNumber ?? '').isEmpty ? 'Bağlı değil' : user.phoneNumber!,
            ),
            if (passwordProvider && email.isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'change'),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Şifremi Değiştir'),
              ),
              const SizedBox(height: 8),
            ],
            if (email.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'reset'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Şifre sıfırlama e-postası gönder'),
              ),
            if (!passwordProvider) ...[
              const SizedBox(height: 10),
              const Text(
                'Bu hesap Google/Apple gibi harici bir sağlayıcıyla açılmış. Uygulama içinden mevcut şifreyle değiştirme yalnızca e-posta ve şifre ile giriş yapan hesaplarda kullanılabilir.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );

    if (action == 'change' && passwordProvider && email.isNotEmpty) {
      await _changePassword(email);
    }
    if (action == 'reset' && email.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _message('Şifre sıfırlama bağlantısı e-posta adresine gönderildi.');
      } on FirebaseAuthException catch (error) {
        _message(error.message ?? 'Şifre sıfırlama e-postası gönderilemedi.');
      }
    }
  }

  Future<void> _changePassword(String email) async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                'Şifre Değiştir',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Önce mevcut şifreni doğrula, sonra yeni şifreni oluştur.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: currentPassword,
                obscureText: obscureCurrent,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mevcut şifre',
                  suffixIcon: IconButton(
                    onPressed: () => setSheetState(
                      () => obscureCurrent = !obscureCurrent,
                    ),
                    icon: Icon(
                      obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassword,
                obscureText: obscureNew,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Yeni şifre',
                  helperText: 'En az 6 karakter',
                  suffixIcon: IconButton(
                    onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                    icon: Icon(
                      obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassword,
                obscureText: obscureNew,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Yeni şifre tekrar'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final current = currentPassword.text;
                        final next = newPassword.text;
                        final confirm = confirmPassword.text;
                        if (current.isEmpty) {
                          _message('Mevcut şifreni gir.');
                          return;
                        }
                        if (next.length < 6) {
                          _message('Yeni şifre en az 6 karakter olmalı.');
                          return;
                        }
                        if (next != confirm) {
                          _message('Yeni şifreler aynı değil.');
                          return;
                        }
                        if (current == next) {
                          _message('Yeni şifre mevcut şifreden farklı olmalı.');
                          return;
                        }
                        setSheetState(() => saving = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;
                          final credential = EmailAuthProvider.credential(
                            email: email,
                            password: current,
                          );
                          await user.reauthenticateWithCredential(credential);
                          await user.updatePassword(next);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _message('Şifren başarıyla değiştirildi.');
                        } on FirebaseAuthException catch (error) {
                          final text = switch (error.code) {
                            'wrong-password' || 'invalid-credential' => 'Mevcut şifre yanlış.',
                            'weak-password' => 'Yeni şifre çok zayıf.',
                            'requires-recent-login' => 'Güvenlik için tekrar giriş yapıp yeniden dene.',
                            _ => error.message ?? 'Şifre değiştirilemedi.',
                          };
                          _message(text);
                          setSheetState(() => saving = false);
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Değiştiriliyor…' : 'Şifreyi Değiştir'),
              ),
            ],
          ),
        ),
      ),
    );

    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
  }

  Future<void> _verification() async {
    final user = _user;
    if (user == null) return;
    await user.reload();
    var fresh = FirebaseAuth.instance.currentUser;
    if (fresh == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Doğrulama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusRow('E-posta', fresh!.emailVerified),
            const SizedBox(height: 9),
            _statusRow('Telefon', (fresh.phoneNumber ?? '').isNotEmpty),
            const SizedBox(height: 12),
            Text(
              fresh.emailVerified
                  ? 'E-posta hesabın doğrulanmış durumda.'
                  : 'Şimdi Doğrula ile e-posta adresine doğrulama bağlantısı gönderilir. Bağlantıya dokunduktan sonra Durumu Kontrol Et ile sonucu yenileyebilirsin.',
              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
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
          if (!fresh.emailVerified && fresh.email != null)
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'send'),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Şimdi Doğrula'),
            ),
        ],
      ),
    );

    if (action == 'send') {
      try {
        await fresh.sendEmailVerification();
        _message('Doğrulama e-postası gönderildi. Bağlantıya dokunduktan sonra durumu kontrol et.');
      } on FirebaseAuthException catch (error) {
        _message(error.message ?? 'Doğrulama e-postası gönderilemedi.');
      }
    }
    if (action == 'check') {
      await fresh.reload();
      fresh = FirebaseAuth.instance.currentUser;
      if (fresh?.emailVerified == true) {
        _message('E-posta doğrulaması tamamlandı.');
      } else {
        _message('E-posta henüz doğrulanmamış görünüyor.');
      }
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
          ? (settings['interests'] as List).map((item) => item.toString())
          : const <String>[]),
    };

    final save = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('İlgi alanları', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Keşfet ve öneriler bu seçimlerden yararlanır.', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: choices.map((item) {
                  return FilterChip(
                    label: Text(item),
                    selected: selected.contains(item),
                    onSelected: (value) => setSheetState(() {
                      value ? selected.add(item) : selected.remove(item);
                    }),
                  );
                }).toList(),
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

    final ref = _userRef;
    if (save == true && ref != null) {
      try {
        await ref.update({'settings.interests': selected.toList()});
      } catch (_) {
        await ref.set({
          'settings': {'interests': selected.toList()},
        }, SetOptions(merge: true));
      }
      _message('İlgi alanların güncellendi.');
    }
  }

  void _storage() {
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
            const Text('Veri ve depolama', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Video otomatik oynatma tercihini İçerik ve Keşif bölümünden değiştirebilirsin.', style: TextStyle(color: Colors.white60, height: 1.4)),
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

  void _help() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yardım ve destek'),
        content: const Text(
          'Bir hesabı, içeriği veya mekanı şikayet etmek için ilgili içerikteki üç nokta menüsünü kullan. Hesap güvenliği için Gizlilik ve Güvenlik bölümüne, işletme yönetimi için Yönettiğim Mekanlar bölümüne gidebilirsin.',
          style: TextStyle(height: 1.45),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam'))],
      ),
    );
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TBT'),
        content: const Text(
          'TBT; içerik, mekan, gezi noktası ve etkinlikleri tek sosyal keşif deneyiminde bir araya getirir.\n\nKullanıcı yer önerileri ve işletme sahiplikleri doğrulama süreçlerinden geçer.',
          style: TextStyle(height: 1.45),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Kapat'))],
      ),
    );
  }

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
                    _tile(Icons.person_outline_rounded, 'Profil bilgileri', 'Ad, biyografi ve profil türü', () => _editProfile(data)),
                    _tile(Icons.lock_outline_rounded, 'Şifre ve güvenlik', 'Mevcut şifrenle yeni şifre oluştur veya sıfırlama bağlantısı al', _security),
                    _tile(
                      Icons.verified_user_outlined,
                      'Doğrulama',
                      user.emailVerified ? 'E-posta doğrulandı' : 'Doğrulanmadı • Şimdi Doğrula',
                      _verification,
                    ),
                    _section('Gizlilik'),
                    _switchTile(Icons.lock_person_outlined, 'Gizli hesap', 'Yeni takipçileri sen onayla', settings['privateAccount'] == true, (value) => _setBool('privateAccount', value)),
                    _switchTile(Icons.location_off_outlined, 'Konum görünürlüğü', 'Konumunu sosyal içeriklerde göster', settings['locationVisible'] == true, (value) => _setBool('locationVisible', value)),
                    _tile(Icons.shield_outlined, 'Gizlilik ve güvenlik', 'Mesaj, etiketleme, yorum ve engellenen hesaplar', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyPrivacyCenterScreen()));
                    }),
                    _section('Bildirimler'),
                    _switchTile(Icons.chat_bubble_outline_rounded, 'Mesajlar', 'Yeni mesaj bildirimleri', settings['notifyMessages'] != false, (value) => _setBool('notifyMessages', value)),
                    _switchTile(Icons.favorite_border_rounded, 'Beğeni ve yorumlar', 'İçerik etkileşimlerini bildir', settings['notifyEngagement'] != false, (value) => _setBool('notifyEngagement', value)),
                    _switchTile(Icons.event_outlined, 'Etkinlikler', 'Daveti, katılımı ve hatırlatmaları bildir', settings['notifyEvents'] != false, (value) => _setBool('notifyEvents', value)),
                    _switchTile(Icons.emoji_events_outlined, 'XP ve görevler', 'Puan, seviye ve görev gelişmelerini bildir', settings['notifyRewards'] != false, (value) => _setBool('notifyRewards', value)),
                    _section('İçerik ve Keşif'),
                    _switchTile(Icons.play_circle_outline_rounded, 'Videoları otomatik oynat', 'Akış ve keşifte videolar otomatik başlasın', settings['autoplayVideos'] != false, (value) => _setBool('autoplayVideos', value)),
                    _switchTile(Icons.visibility_off_outlined, 'Hassas içerik filtresi', 'Hassas olabilecek içerikleri azalt', settings['sensitiveFilter'] != false, (value) => _setBool('sensitiveFilter', value)),
                    _tile(Icons.interests_outlined, 'İlgi alanları', 'Önerilerini şekillendiren konuları yönet', () => _interests(settings)),
                    if (type == 'business_owner' || type == 'venue_manager') ...[
                      _section('Mekanlar ve Yönetim'),
                      _tile(Icons.storefront_outlined, 'Yönettiğim Mekanlar', 'Yetkili olduğun mekanları tek yerden yönet', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagedVenuesScreen()));
                      }),
                    ],
                    if (type == 'organizer') ...[
                      _section('Organizatör'),
                      _tile(Icons.event_available_outlined, 'Etkinlik yönetimi', 'Etkinliklerini görüntüle ve katılımı takip et', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialEventsScreen()));
                      }),
                    ],
                    _section('Uygulama'),
                    _staticTile(Icons.language_rounded, 'Dil', 'Türkçe'),
                    _tile(Icons.storage_outlined, 'Veri ve depolama', 'Önbellek ve veri tercihleri', _storage),
                    _tile(Icons.help_outline_rounded, 'Yardım ve destek', 'Güvenlik, şikayet ve yardım yolları', _help),
                    _tile(Icons.info_outline_rounded, 'TBT hakkında', 'Uygulama ve topluluk bilgileri', _about),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () async {
                        await AuthService.instance.logout();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
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
    final name = (data['displayName'] ?? user.displayName ?? 'TBT Kullanıcısı').toString();
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
            child: photo.isEmpty ? const Icon(Icons.person_outline_rounded) : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                if (username.isNotEmpty)
                  Text(username.startsWith('@') ? username : '@$username', style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 3),
                Text(_profileTypeLabel(type), style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _profileTypeLabel(String value) => switch (value) {
    'creator' => 'İçerik Üreticisi',
    'business_owner' => 'İşletme Sahibi',
    'venue_manager' => 'Mekan Yöneticisi',
    'organizer' => 'Organizatör',
    _ => 'Kişisel',
  };

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 13)),
  );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 82, child: Text(label, style: const TextStyle(color: Colors.white54))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
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
