import '../widgets/tbt_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/trust_safety_service.dart';

class SafetyPrivacyCenterScreen extends StatefulWidget {
  const SafetyPrivacyCenterScreen({super.key});

  @override
  State<SafetyPrivacyCenterScreen> createState() =>
      _SafetyPrivacyCenterScreenState();
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
  bool _accountBusy = false;
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
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
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
        _attendeesOnly =
            privacy['preciseEventLocationOnlyForAttendees'] != false;
        _analyticsConsent = privacy['analyticsConsent'] != false;
        final visibility = privacy['locationVisibility']?.toString();
        if (visibility == 'hidden' ||
            visibility == 'approximate' ||
            visibility == 'precise') {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tercihler kaydedildi.')));
    }
  }

  Future<void> _manageAccount() async {
    if (_accountBusy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hesap işlemleri',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.ac_unit_rounded),
              title: const Text('Hesabı dondur'),
              subtitle: const Text(
                'Süre sınırı yoktur. Tekrar giriş yaparak hesabını istediğin zaman açabilirsin.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'freeze'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
              ),
              title: const Text('Hesabı kalıcı sil'),
              subtitle: const Text(
                'Admin onayı veya bekleme olmadan hesabın ve verilerin silinir.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'freeze') {
      final confirmed = await showTbtDialog<bool>(
        context: context,
        builder: (dialogContext) => TbtDialog(
          title: const Text('Hesabı dondur'),
          content: const Text(
            'Hesabın süre sınırı olmadan dondurulacak. İstediğin zaman yeniden açabilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Dondur'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        setState(() => _accountBusy = true);
        try {
          await TrustSafetyService.instance.freezeAccount();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(_accountError(error))));
          }
        } finally {
          if (mounted) setState(() => _accountBusy = false);
        }
      }
      return;
    }

    final confirmed = await showTbtDialog<bool>(
      context: context,
      builder: (dialogContext) => TbtDialog(
        title: const Text('Hesabı kalıcı sil'),
        content: const Text(
          'Bu işlem geri alınamaz. Hesabın admin onayı veya bekleme süresi olmadan kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hemen sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _accountBusy = true);
      try {
        await TrustSafetyService.instance.deleteAccountNow();
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_accountError(error))));
        }
      } finally {
        if (mounted) setState(() => _accountBusy = false);
      }
    }
  }

  String _accountError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Hesap işlemi tamamlanamadı.';
    }
    return 'Hesap işlemi tamamlanamadı. Lütfen tekrar dene.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenlik ve Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          const Text(
            'Bildirim tercihleri',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          SwitchListTile(
            value: _messages,
            onChanged: (v) => setState(() => _messages = v),
            title: const Text('Mesajlar'),
          ),
          SwitchListTile(
            value: _likes,
            onChanged: (v) => setState(() => _likes = v),
            title: const Text('Beğeniler'),
          ),
          SwitchListTile(
            value: _comments,
            onChanged: (v) => setState(() => _comments = v),
            title: const Text('Yorumlar'),
          ),
          SwitchListTile(
            value: _events,
            onChanged: (v) => setState(() => _events = v),
            title: const Text('Etkinlikler ve Radar'),
          ),
          SwitchListTile(
            value: _social,
            onChanged: (v) => setState(() => _social = v),
            title: const Text('Sosyal hareketler'),
          ),
          SwitchListTile(
            value: _marketing,
            onChanged: (v) => setState(() => _marketing = v),
            title: const Text('Tanıtım ve kampanyalar'),
          ),
          const Divider(height: 28),
          const Text(
            'Konum gizliliği',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          RadioListTile<String>(
            value: 'hidden',
            groupValue: _locationVisibility,
            onChanged: (v) => setState(() => _locationVisibility = v!),
            title: const Text('Konumumu gizle'),
          ),
          RadioListTile<String>(
            value: 'approximate',
            groupValue: _locationVisibility,
            onChanged: (v) => setState(() => _locationVisibility = v!),
            title: const Text('Yaklaşık konum'),
          ),
          RadioListTile<String>(
            value: 'precise',
            groupValue: _locationVisibility,
            onChanged: (v) => setState(() => _locationVisibility = v!),
            title: const Text('Kesin konum'),
          ),
          SwitchListTile(
            value: _attendeesOnly,
            onChanged: (v) => setState(() => _attendeesOnly = v),
            title: const Text(
              'Etkinlikte kesin konumu yalnız katılımcılara göster',
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Veri ve hesap',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          SwitchListTile(
            value: _analyticsConsent,
            onChanged: (v) => setState(() => _analyticsConsent = v),
            title: const Text('Kullanım analitiği'),
            subtitle: const Text(
              'Ürün geliştirme amaçlı kullanım olaylarının kaydı.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Verilerim neden kullanılıyor?'),
            subtitle: const Text(
              'Konum, profil ve etkinlik verileri yalnız ilgili özellikleri sunmak ve güvenliği sağlamak için işlenir.',
            ),
          ),
          ListTile(
            enabled: !_accountBusy,
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Hesabı dondur veya sil'),
            subtitle: const Text('Süresiz dondurma veya doğrudan kalıcı silme'),
            onTap: _manageAccount,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Tercihleri Kaydet'),
          ),
        ],
      ),
    );
  }
}
