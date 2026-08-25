import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';

class BusinessHubScreen extends StatefulWidget {
  final String initialCategory;
  final String initialVenueId;
  final String initialVenueName;

  const BusinessHubScreen({
    super.key,
    this.initialCategory = '',
    this.initialVenueId = '',
    this.initialVenueName = '',
  });

  @override
  State<BusinessHubScreen> createState() => _BusinessHubScreenState();
}

class _BusinessHubScreenState extends State<BusinessHubScreen> {
  final _category = TextEditingController();
  final _venueId = TextEditingController();
  final _venueName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _legalName = TextEditingController();
  final _taxOffice = TextEditingController();
  final _taxLast4 = TextEditingController();
  File? _evidence;
  bool _saving = false;
  bool _uploadingMedia = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _category.text = widget.initialCategory;
    _venueId.text = widget.initialVenueId;
    _venueName.text = widget.initialVenueName;
    if (_category.text.isNotEmpty && _venueId.text.isNotEmpty) _refreshStatus();
  }

  @override
  void dispose() {
    for (final c in [_category, _venueId, _venueName, _email, _phone, _legalName, _taxOffice, _taxLast4]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Oturumun doğrulanamadı. Çıkış yapıp yeniden giriş yaptıktan sonra tekrar dene.';
        case 'permission-denied':
          return error.message ?? 'Bu işlem için yetkin yok.';
        case 'failed-precondition':
        case 'invalid-argument':
        case 'already-exists':
          return error.message ?? 'Başvuru bilgilerini kontrol et.';
        case 'not-found':
          return 'İşletme doğrulama servisi bulunamadı. Uygulama yöneticisine bildir.';
      }
      return error.message ?? 'İşlem tamamlanamadı. Biraz sonra tekrar dene.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _refreshStatus() async {
    if (_category.text.trim().isEmpty || _venueId.text.trim().isEmpty) return;
    try {
      final status = await BusinessService.instance.claimStatus(
        _category.text.trim(),
        _venueId.text.trim(),
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {}
  }

  Future<void> _pickEvidence() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (file != null && mounted) setState(() => _evidence = File(file.path));
  }

  Future<void> _pickProfileImage(String kind) async {
    if (_uploadingMedia) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: kind == 'logo' ? 1400 : 2400,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingMedia = true);
    try {
      await BusinessService.instance.updateProfileImage(
        category: _category.text.trim(),
        venueId: _venueId.text.trim(),
        kind: kind,
        image: File(picked.path),
      );
      _message(kind == 'logo' ? 'İşletme logosu güncellendi.' : 'Kapak fotoğrafı güncellendi.');
    } catch (e) {
      _message(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_evidence == null) {
      _message('Yetki kanıtı görselini ekle.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BusinessService.instance.submitClaim(
        category: _category.text,
        venueId: _venueId.text,
        venueName: _venueName.text,
        businessEmail: _email.text,
        businessPhone: _phone.text,
        legalName: _legalName.text,
        taxOffice: _taxOffice.text,
        taxNumberLast4: _taxLast4.text,
        evidenceImage: _evidence!,
      );
      _message('Başvuru alındı. Manuel doğrulama tamamlanmadan işletme yetkisi açılmaz.');
      await _refreshStatus();
    } catch (e) {
      _message(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_status?['status'] ?? '').toString();
    final verified = status == 'verified';
    final hasSelectedVenue = widget.initialCategory.isNotEmpty &&
        widget.initialVenueId.isNotEmpty &&
        widget.initialVenueName.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('İşletmem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: verified ? AppColors.cyan : AppColors.border),
            ),
            child: Row(children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.verified_user_outlined,
                color: verified ? AppColors.cyan : Colors.white60,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    verified
                        ? 'Doğrulanmış İşletme'
                        : status == 'pending_review'
                            ? 'İnceleme Bekliyor'
                            : status == 'rejected'
                                ? 'Başvuru Reddedildi'
                                : 'İşletme Doğrulaması',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    verified
                        ? 'Profil, menü, kampanya, etkinlik ve paylaşımlarını yönetebilirsin.'
                        : 'Yetki yalnız manuel inceleme ve kanıt doğrulamasından sonra açılır.',
                    style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          if (!verified && !hasSelectedVenue) ...[
            const SizedBox(height: 10),
            const Icon(Icons.storefront_outlined, size: 58, color: AppColors.cyan),
            const SizedBox(height: 14),
            const Text(
              'Önce işletmeni seç',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mekanlar bölümünden işletmeni aç ve profilindeki “Bu işletme benim” seçeneğine dokun. Böylece mekan adı ve kimliği güvenli biçimde otomatik doldurulur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.45),
            ),
          ] else if (!verified) ...[
            const Text('Mekan Bilgisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.storefront_rounded, color: AppColors.cyan),
              title: Text(_venueName.text, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(_categoryLabel(_category.text)),
              trailing: const Icon(Icons.lock_outline_rounded, size: 18),
            ),
            const SizedBox(height: 18),
            const Text('Yetki ve Şirket Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: _legalName, decoration: const InputDecoration(labelText: 'Yasal işletme unvanı')),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'İşletme e-postası')),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'İşletme telefonu')),
            const SizedBox(height: 10),
            TextField(controller: _taxOffice, decoration: const InputDecoration(labelText: 'Vergi dairesi')),
            const SizedBox(height: 10),
            TextField(controller: _taxLast4, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Vergi numarasının son 4 hanesi')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickEvidence,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(_evidence == null ? 'Yetki kanıtı fotoğrafı ekle' : 'Kanıt seçildi ✓'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kabul edilebilir kanıt: işletme ruhsatı/vergi levhası üzerinde işletme adı görünür fotoğraf veya yetkili olduğunuzu gösteren resmi belge. Hassas alanları gereksiz yere paylaşmayın; yalnız doğrulama için gereken bilgiler incelenir.',
              style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.4),
            ),
            if (status == 'pending_review') ...[
              const SizedBox(height: 14),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.hourglass_top_rounded, color: AppColors.cyan),
                  title: Text('Başvurun incelemede', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('Sonuçlanana kadar tekrar başvuru göndermen gerekmez.'),
                ),
              ),
            ],
            if (status == 'rejected' && (_status?['rejectionReason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Reddedilme nedeni', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text((_status?['rejectionReason'] ?? '').toString()),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving || status == 'pending_review' ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined),
              label: Text(_saving ? 'Başvuru gönderiliyor…' : status == 'rejected' ? 'Düzelterek Tekrar Gönder' : 'Doğrulama Başvurusu Gönder'),
            ),
          ] else ...[
            const Text('İşletme Yönetimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _ManagementTile(
              icon: Icons.store_mall_directory_outlined,
              title: 'Profil Bilgileri',
              subtitle: 'Açıklama, telefon, web sitesi ve çalışma saatlerini düzenle.',
              onTap: _showProfileDialog,
            ),
            _ManagementTile(
              icon: Icons.account_circle_outlined,
              title: 'İşletme Logosu',
              subtitle: _uploadingMedia ? 'Görsel yükleniyor…' : 'Profilde görünen işletme logosunu değiştir.',
              onTap: () => _pickProfileImage('logo'),
            ),
            _ManagementTile(
              icon: Icons.panorama_outlined,
              title: 'Kapak Fotoğrafı',
              subtitle: _uploadingMedia ? 'Görsel yükleniyor…' : 'İşletme profilinin kapak görselini değiştir.',
              onTap: () => _pickProfileImage('cover'),
            ),
            _ManagementTile(
              icon: Icons.restaurant_menu_rounded,
              title: 'Menü Yönetimi',
              subtitle: 'Ürün, bölüm, açıklama ve fiyat ekle.',
              onTap: () => _showMenuDialog(),
            ),
            _ManagementTile(
              icon: Icons.calendar_month_rounded,
              title: 'Program / Takvim',
              subtitle: 'Canlı müzik, workshop, maç yayını ve özel program ekle.',
              onTap: () => _showProgramDialog(),
            ),
            _ManagementTile(
              icon: Icons.local_offer_outlined,
              title: 'Kampanyalar',
              subtitle: 'Süreli fırsat ve duyuru yayınla.',
              onTap: () => _showCampaignDialog(),
            ),
            _ManagementTile(
              icon: Icons.add_to_photos_outlined,
              title: 'Fotoğraf / Video Paylaş',
              subtitle: 'İşletme profilinde ve ana akışta yayınla.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostScreen(
                    businessVenueKey: BusinessService.instance.venueKey(
                      _category.text.trim(),
                      _venueId.text.trim(),
                    ),
                    businessVenueName: _venueName.text.trim(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String value) => switch (value) {
        'cafe' => 'Kafe',
        'hotel' => 'Otel / Konaklama',
        'dining' => 'Restoran / Yeme-İçme',
        _ => 'İşletme',
      };

  Future<void> _showProfileDialog() async {
    final key = BusinessService.instance.venueKey(_category.text.trim(), _venueId.text.trim());
    Map<String, dynamic> existing = const {};
    try {
      final snap = await FirebaseFirestore.instance.collection('business_venues').doc(key).get();
      existing = snap.data() ?? const {};
    } catch (_) {}
    if (!mounted) return;

    final description = TextEditingController(text: (existing['description'] ?? '').toString());
    final phone = TextEditingController(text: (existing['phone'] ?? '').toString());
    final website = TextEditingController(text: (existing['website'] ?? '').toString());
    final openingHours = TextEditingController(text: (existing['openingHours'] ?? '').toString());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profil bilgilerini düzenle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'İşletme hakkında')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
            const SizedBox(height: 10),
            TextField(controller: website, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Web sitesi')),
            const SizedBox(height: 10),
            TextField(controller: openingHours, maxLines: 3, decoration: const InputDecoration(labelText: 'Çalışma saatleri', hintText: 'Pzt-Cum 08:00-22:00\nCmt-Paz 09:00-23:00')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              try {
                await BusinessService.instance.updateProfile(
                  category: _category.text.trim(),
                  venueId: _venueId.text.trim(),
                  description: description.text,
                  phone: phone.text,
                  website: website.text,
                  openingHours: openingHours.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _message('İşletme profili güncellendi.');
              } catch (e) {
                _message(_friendlyError(e));
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    description.dispose();
    phone.dispose();
    website.dispose();
    openingHours.dispose();
  }

  Future<void> _showCampaignDialog() async {
    final title = TextEditingController();
    final description = TextEditingController();
    var validUntil = DateTime.now().add(const Duration(days: 7));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kampanya yayınla'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Kampanya başlığı')),
              TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama ve koşullar')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text('Son gün: ${validUntil.day}.${validUntil.month}.${validUntil.year}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: validUntil,
                  );
                  if (picked != null) setDialogState(() => validUntil = picked.add(const Duration(hours: 23, minutes: 59)));
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                try {
                  await BusinessService.instance.addCampaign(
                    category: _category.text.trim(),
                    venueId: _venueId.text.trim(),
                    title: title.text,
                    description: description.text,
                    validUntil: validUntil,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _message('Kampanya yayınlandı.');
                } catch (e) {
                  _message(_friendlyError(e));
                }
              },
              child: const Text('Yayınla'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenuDialog() async {
    final name = TextEditingController();
    final section = TextEditingController();
    final desc = TextEditingController();
    final price = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Menü ürünü ekle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Ürün adı')),
          TextField(controller: section, decoration: const InputDecoration(labelText: 'Bölüm (Kahveler, Tatlılar...)')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Açıklama')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fiyat (TL)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            final value = double.tryParse(price.text.replaceAll(',', '.')) ?? -1;
            if (value < 0) return;
            try {
              await BusinessService.instance.addMenuItem(
                category: _category.text,
                venueId: _venueId.text,
                name: name.text,
                section: section.text,
                description: desc.text,
                priceMinor: (value * 100).round(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _message('Menü ürünü eklendi.');
            } catch (e) {
              _message(_friendlyError(e));
            }
          }, child: const Text('Ekle')),
        ],
      ),
    );
  }

  Future<void> _showProgramDialog() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    var startsAt = DateTime.now().add(const Duration(hours: 2));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Program ekle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Program başlığı')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Açıklama')),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: Text('${startsAt.day}.${startsAt.month}.${startsAt.year} • ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'),
            onTap: () async {
              final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: startsAt);
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
              if (time == null) return;
              setState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            try {
              await BusinessService.instance.addProgramItem(
                category: _category.text,
                venueId: _venueId.text,
                title: title.text,
                description: desc.text,
                startsAt: startsAt,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _message('Program eklendi.');
            } catch (e) {
              _message(_friendlyError(e));
            }
          }, child: const Text('Ekle')),
        ],
      )),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ManagementTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: AppColors.cyan),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
