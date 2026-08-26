import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/business_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'business_content_manager_screen.dart';
import 'business_hours_screen.dart';
import 'business_pro_dashboard_screen.dart';
import 'create_post_screen.dart';

class BusinessHubScreen extends StatefulWidget {
  final String initialCategory;
  final String initialVenueId;
  final String initialVenueName;
  final bool previewMode;
  const BusinessHubScreen({
    super.key,
    this.initialCategory = '',
    this.initialVenueId = '',
    this.initialVenueName = '',
    this.previewMode = false,
  });
  @override
  State<BusinessHubScreen> createState() => _BusinessHubScreenState();
}

class _BusinessHubScreenState extends State<BusinessHubScreen> {
  final _category = TextEditingController(),
      _venueId = TextEditingController(),
      _venueName = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _legalName = TextEditingController(),
      _taxOffice = TextEditingController(),
      _taxLast4 = TextEditingController();
  File? _evidence;
  bool _saving = false, _uploadingMedia = false;
  Map<String, dynamic>? _status;
  @override
  void initState() {
    super.initState();
    _category.text = widget.initialCategory;
    _venueId.text = widget.initialVenueId;
    _venueName.text = widget.initialVenueName;
    if (!widget.previewMode &&
        _category.text.isNotEmpty &&
        _venueId.text.isNotEmpty)
      _refreshStatus();
  }

  @override
  void dispose() {
    for (final c in [
      _category,
      _venueId,
      _venueName,
      _email,
      _phone,
      _legalName,
      _taxOffice,
      _taxLast4,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String v) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(v)));
  }

  String _error(Object e) => e is FirebaseFunctionsException
      ? (e.message ?? 'İşlem tamamlanamadı.')
      : e.toString().replaceFirst('Exception: ', '');
  Future<void> _refreshStatus() async {
    if (widget.previewMode ||
        _category.text.trim().isEmpty ||
        _venueId.text.trim().isEmpty)
      return;
    try {
      final s = await BusinessService.instance.claimStatus(
        _category.text.trim(),
        _venueId.text.trim(),
      );
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _showNewBusinessDialog() async {
    final name = TextEditingController(),
        address = TextEditingController(),
        city = TextEditingController();
    var category = 'cafe';
    var loading = false, locating = false;
    double? latitude, longitude;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('İşletmem listede yok'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'cafe', child: Text('Kafe')),
                    DropdownMenuItem(
                      value: 'dining',
                      child: Text('Restoran / Yeme-İçme'),
                    ),
                    DropdownMenuItem(
                      value: 'hotel',
                      child: Text('Otel / Konaklama'),
                    ),
                  ],
                  onChanged: (v) => setD(() => category = v ?? 'cafe'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'İşletme adı'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Açık adres'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: locating
                      ? null
                      : () async {
                          setD(() => locating = true);
                          final p = await LocationService.getCurrentPosition();
                          if (p == null) {
                            setD(() => locating = false);
                            _message(
                              'Konum alınamadı. Konum servisini ve uygulama iznini kontrol et.',
                            );
                            return;
                          }
                          setD(() {
                            latitude = p.latitude;
                            longitude = p.longitude;
                            locating = false;
                          });
                        },
                  icon: Icon(
                    latitude == null
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                  ),
                  label: Text(
                    locating
                        ? 'Konum alınıyor…'
                        : latitude == null
                        ? 'İşletme konumunu kullan'
                        : 'Konum seçildi ✓',
                  ),
                ),
                if (latitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'İşletmenin gerçek konumundayken konumu seç. Kayıt oluşturulduktan sonra sahiplik doğrulaması gerekir.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (latitude == null || longitude == null) {
                        _message('Önce işletme konumunu seç.');
                        return;
                      }
                      setD(() => loading = true);
                      try {
                        final created = await BusinessService.instance
                            .createBusinessCandidate(
                              category: category,
                              venueName: name.text.trim(),
                              address: address.text.trim(),
                              city: city.text.trim(),
                              latitude: latitude!,
                              longitude: longitude!,
                            );
                        if (!mounted) return;
                        setState(() {
                          _category.text = (created['category'] ?? category)
                              .toString();
                          _venueId.text = (created['venueId'] ?? '').toString();
                          _venueName.text =
                              (created['venueName'] ?? name.text.trim())
                                  .toString();
                          _status = {'status': ''};
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _message(
                          'İşletme eklendi. Şimdi sahiplik doğrulamasını tamamla.',
                        );
                      } catch (e) {
                        _message(_error(e));
                        setD(() => loading = false);
                      }
                    },
              child: Text(loading ? 'Ekleniyor…' : 'İşletmeyi Ekle'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    address.dispose();
    city.dispose();
  }

  Future<void> _pickEvidence() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (x != null && mounted) setState(() => _evidence = File(x.path));
  }

  bool _previewGuard(String f) {
    if (!widget.previewMode) return false;
    _message('$f önizlemesi aktif. Önizleme modunda gerçek veriye yazılmaz.');
    return true;
  }

  Future<void> _pickProfileImage(String kind) async {
    if (_previewGuard(kind == 'logo' ? 'İşletme logosu' : 'Kapak fotoğrafı') ||
        _uploadingMedia)
      return;
    final p = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: kind == 'logo' ? 1400 : 2400,
      requestFullMetadata: false,
    );
    if (p == null || !mounted) return;
    setState(() => _uploadingMedia = true);
    try {
      await BusinessService.instance.updateProfileImage(
        category: _category.text.trim(),
        venueId: _venueId.text.trim(),
        kind: kind,
        image: File(p.path),
      );
      _message(
        kind == 'logo'
            ? 'İşletme logosu güncellendi.'
            : 'Kapak fotoğrafı güncellendi.',
      );
    } catch (e) {
      _message(_error(e));
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
        category: _category.text.trim(),
        venueId: _venueId.text.trim(),
        venueName: _venueName.text.trim(),
        businessEmail: _email.text.trim(),
        businessPhone: _phone.text.trim(),
        legalName: _legalName.text.trim(),
        taxOffice: _taxOffice.text.trim(),
        taxNumberLast4: _taxLast4.text.trim(),
        evidenceImage: _evidence!,
      );
      _message(
        'Başvuru alındı. Manuel doğrulama tamamlanmadan işletme yetkisi açılmaz.',
      );
      await _refreshStatus();
    } catch (e) {
      _message(_error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openManager(String type) {
    if (_previewGuard(
      type == 'menu'
          ? 'Menü yönetimi'
          : type == 'campaign'
          ? 'Kampanya yönetimi'
          : 'Program yönetimi',
    ))
      return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessContentManagerScreen(
          category: _category.text.trim(),
          venueId: _venueId.text.trim(),
          type: type,
        ),
      ),
    );
  }

  void _openPro() {
    if (_previewGuard('TBT Business Pro')) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProDashboardScreen(
          category: _category.text.trim(),
          venueId: _venueId.text.trim(),
          venueName: _venueName.text.trim(),
        ),
      ),
    );
  }

  void _openHours() {
    if (_previewGuard('Çalışma saatleri')) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessHoursScreen(
          category: _category.text.trim(),
          venueId: _venueId.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.previewMode
            ? 'verified'
            : (_status?['status'] ?? '').toString(),
        verified = widget.previewMode || status == 'verified',
        hasVenue =
            _category.text.trim().isNotEmpty &&
            _venueId.text.trim().isNotEmpty &&
            _venueName.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.previewMode ? 'İşletme Paneli Önizleme' : 'İşletmem',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            if (widget.previewMode) ...[
              const _PreviewBanner(),
              const SizedBox(height: 12),
            ],
            _StatusCard(status: status, verified: verified),
            const SizedBox(height: 18),
            if (!hasVenue)
              _ChooseVenueState(onCreate: _showNewBusinessDialog)
            else if (!verified)
              _claimForm(status)
            else
              _management(),
          ],
        ),
      ),
    );
  }

  Widget _claimForm(String status) {
    final rejection = (_status?['rejectionReason'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.storefront_rounded,
              color: AppColors.cyan,
            ),
            title: Text(
              _venueName.text,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(_categoryLabel(_category.text)),
            trailing: const Icon(Icons.lock_outline_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Yetki ve Şirket Bilgileri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _legalName,
          decoration: const InputDecoration(labelText: 'Yasal işletme unvanı'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'İşletme e-postası'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'İşletme telefonu'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _taxOffice,
          decoration: const InputDecoration(labelText: 'Vergi dairesi'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _taxLast4,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Vergi numarasının son 4 hanesi',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickEvidence,
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(
            _evidence == null
                ? 'Yetki kanıtı fotoğrafı ekle'
                : 'Kanıt seçildi ✓',
          ),
        ),
        if (status == 'pending_review')
          const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_top_rounded, color: AppColors.cyan),
              title: Text('Başvurun incelemede'),
              subtitle: Text(
                'Sonuçlanana kadar tekrar başvuru göndermen gerekmez.',
              ),
            ),
          ),
        if (status == 'rejected' && rejection.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Reddedilme nedeni'),
              subtitle: Text(rejection),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving || status == 'pending_review' ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: Text(
            _saving
                ? 'Başvuru gönderiliyor…'
                : status == 'rejected'
                ? 'Düzelterek Tekrar Gönder'
                : 'Doğrulama Başvurusu Gönder',
          ),
        ),
      ],
    );
  }

  Widget _management() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.previewMode ? _venueName.text : 'İşletme Yönetimi',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      if (widget.previewMode)
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Doğrulanmış işletme sahibinin panel görünümü.',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      const SizedBox(height: 10),
      _Tile(
        Icons.workspace_premium_rounded,
        'TBT Business Pro',
        'İstatistikler, rezervasyonlar ve Boost.',
        _openPro,
        true,
      ),
      _Tile(
        Icons.store_mall_directory_outlined,
        'Profil Bilgileri',
        'Açıklama, telefon ve web sitesini düzenle.',
        () {
          if (!_previewGuard('Profil bilgileri')) _showProfileDialog();
        },
      ),
      _Tile(
        Icons.schedule_rounded,
        'Çalışma Saatleri',
        'Pazartesi–Pazar; Açık/Kapalı otomatik.',
        _openHours,
      ),
      _Tile(
        Icons.account_circle_outlined,
        'İşletme Logosu',
        _uploadingMedia ? 'Görsel yükleniyor…' : 'Profil logosunu değiştir.',
        () => _pickProfileImage('logo'),
      ),
      _Tile(
        Icons.panorama_outlined,
        'Kapak Fotoğrafı',
        _uploadingMedia ? 'Görsel yükleniyor…' : 'Kapak görselini değiştir.',
        () => _pickProfileImage('cover'),
      ),
      _Tile(
        Icons.restaurant_menu_rounded,
        'Menü Yönetimi',
        'Fotoğraf, stok, fiyat ve görünürlük.',
        () => _openManager('menu'),
      ),
      _Tile(
        Icons.local_offer_outlined,
        'Kampanya Yönetimi',
        'Süreli kampanyalar otomatik kapanır.',
        () => _openManager('campaign'),
      ),
      _Tile(
        Icons.calendar_month_rounded,
        'Program / Etkinlik',
        'Ekle, düzenle, görünürlüğü yönet.',
        () => _openManager('program'),
      ),
      _Tile(
        Icons.add_to_photos_outlined,
        'Fotoğraf / Video Paylaş',
        'İşletme profilinde ve ana akışta yayınla.',
        () {
          if (_previewGuard('Fotoğraf / Video paylaşımı')) return;
          Navigator.push(
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
          );
        },
      ),
    ],
  );

  Future<void> _showProfileDialog() async {
    final key = BusinessService.instance.venueKey(
      _category.text.trim(),
      _venueId.text.trim(),
    );
    Map<String, dynamic> existing = const {};
    try {
      existing =
          (await FirebaseFirestore.instance
                  .collection('business_venues')
                  .doc(key)
                  .get())
              .data() ??
          const {};
    } catch (_) {}
    if (!mounted) return;
    final d = TextEditingController(
          text: (existing['description'] ?? '').toString(),
        ),
        p = TextEditingController(text: (existing['phone'] ?? '').toString()),
        w = TextEditingController(text: (existing['website'] ?? '').toString());
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Profil bilgilerini düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: d,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'İşletme hakkında',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: p,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: w,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Web sitesi'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await BusinessService.instance.updateProfile(
                  category: _category.text.trim(),
                  venueId: _venueId.text.trim(),
                  description: d.text,
                  phone: p.text,
                  website: w.text,
                  openingHours: (existing['openingHours'] ?? '').toString(),
                );
                if (dc.mounted) Navigator.pop(dc);
                _message('İşletme profili güncellendi.');
              } catch (e) {
                _message(_error(e));
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    d.dispose();
    p.dispose();
    w.dispose();
  }

  String _categoryLabel(String v) => switch (v) {
    'cafe' => 'Kafe',
    'hotel' => 'Otel / Konaklama',
    'dining' => 'Restoran / Yeme-İçme',
    _ => 'İşletme',
  };
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: AppColors.accentGradient,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.visibility_rounded, color: Color(0xFF07080C)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'ADMIN ÖNİZLEME • Gerçek veriyi değiştirmez.',
            style: TextStyle(
              color: Color(0xFF07080C),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusCard extends StatelessWidget {
  final String status;
  final bool verified;
  const _StatusCard({required this.status, required this.verified});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: verified ? AppColors.cyan : AppColors.border),
    ),
    child: Row(
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.verified_user_outlined,
          color: verified ? AppColors.cyan : Colors.white60,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                verified
                    ? 'Doğrulanmış İşletme'
                    : status == 'pending_review'
                    ? 'İnceleme Bekliyor'
                    : status == 'rejected'
                    ? 'Başvuru Reddedildi'
                    : 'İşletme Doğrulaması',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                verified
                    ? 'İşletme araçları aktif.'
                    : 'Yetki doğrulamadan sonra açılır.',
                style: const TextStyle(color: Colors.white60, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ChooseVenueState extends StatelessWidget {
  final VoidCallback onCreate;
  const _ChooseVenueState({required this.onCreate});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const Icon(Icons.storefront_outlined, size: 58, color: AppColors.cyan),
        const SizedBox(height: 14),
        const Text(
          'Önce işletmeni seç',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mekanlar bölümünde işletmen varsa profilindeki doğrulama bağlantısını kullan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('İşletmem listede yok'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Yeni kayıt da doğrulama gerektirir; otomatik sahiplenme yapılmaz.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11.5),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool highlighted;
  const _Tile(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, [
    this.highlighted = false,
  ]);
  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: highlighted ? AppColors.cyan : AppColors.border),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: highlighted ? AppColors.cyan : null),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
