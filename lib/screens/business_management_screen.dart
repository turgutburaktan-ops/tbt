import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reservation_controls.dart';
import 'business_content_manager_screen.dart';
import 'business_profile_editor_screen.dart';
import 'business_hours_screen.dart';

class BusinessManagementScreen extends StatefulWidget {
  final String category, venueId, venueName;
  const BusinessManagementScreen({
    super.key,
    required this.category,
    required this.venueId,
    required this.venueName,
  });
  @override
  State<BusinessManagementScreen> createState() =>
      _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;
  final Set<String> _pending = {};
  String get _key => '${widget.category}:${widget.venueId}';
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BusinessService.instance.authenticatedCall(
        'getBusinessDashboard',
        {'venueKey': _key},
      );
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'İşletme bilgileri yüklenemedi. İnternet bağlantını kontrol edip yeniden dene.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh();
  }

  void _content(String type) => _open(
    BusinessContentManagerScreen(
      category: widget.category,
      venueId: widget.venueId,
      type: type,
    ),
  );
  Future<void> _respond(Map<String, dynamic> row, String decision) async {
    final id = row['id'].toString();
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      await BusinessService.instance.authenticatedCall(
        'respondBusinessReservation',
        {'venueKey': _key, 'reservationId': id, 'decision': decision},
      );
      await _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep güncellenemedi. Yeniden dene.')),
        );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Widget _tile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.cyan),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
  List<Map<String, dynamic>> get _rows =>
      ((_data?['reservations'] as List?) ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Widget _list(List<Widget> children) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final metrics = (_data?['metrics'] as Map?) ?? {};
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.venueName),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Özet'),
              Tab(text: 'Menü'),
              Tab(text: 'Talepler'),
              Tab(text: 'Diğer'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _list([
                    const Text(
                      'İşletmeni buradan yönet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_data != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${rows.where((r) => r['status'] == 'pending').length} bekleyen talep',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: AppColors.cyan,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_data!['followers'] ?? 0} takipçi · ${metrics['profile_view'] ?? 0} profil görüntüleme',
                              ),
                              const Text(
                                'Talep özeti son 100 kaydı kapsar.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    _tile(
                      'Menüyü düzenle',
                      'Ürün, fiyat ve fotoğraf ekle',
                      Icons.restaurant_menu,
                      () => _content('menu'),
                    ),
                    _tile(
                      'Kupon QR okut',
                      'Müşterinin kuponunu kontrol et ve kullan',
                      Icons.qr_code_scanner,
                      () => _open(BusinessCouponScannerScreen(venueKey: _key)),
                    ),
                    _tile(
                      'Kampanyalar',
                      'Oluştur, düzenle veya yayından kaldır',
                      Icons.local_offer_outlined,
                      () => _content('campaign'),
                    ),
                  ]),
                  _list([
                    _tile(
                      'Menü ve ürünler',
                      'Bölümlere göre ürün, fiyat, açıklama ve fotoğraf yönetimi',
                      Icons.restaurant_menu,
                      () => _content('menu'),
                    ),
                  ]),
                  _list([
                    const Text(
                      'Rezervasyonlar ve siparişler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_data != null && rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'Henüz talep yok. Yeni talepler burada görünecek.',
                        ),
                      ),
                    for (final row in rows) _reservation(row),
                  ]),
                  _list([
                    _tile(
                      'İşletme profili',
                      'Fotoğraflar, açıklama ve iletişim',
                      Icons.storefront,
                      () => _open(
                        BusinessProfileEditorScreen(
                          category: widget.category,
                          venueId: widget.venueId,
                          venueName: widget.venueName,
                        ),
                      ),
                    ),
                    _tile(
                      'Çalışma saatleri',
                      'Günlere göre açılış ve kapanış',
                      Icons.schedule,
                      () => _open(
                        BusinessHoursScreen(
                          category: widget.category,
                          venueId: widget.venueId,
                        ),
                      ),
                    ),
                    _tile(
                      'Kampanyalar',
                      'Tekliflerini yönet',
                      Icons.local_offer_outlined,
                      () => _content('campaign'),
                    ),
                    _tile(
                      'Etkinlikler',
                      'Program ekle ve düzenle',
                      Icons.event,
                      () => _content('program'),
                    ),
                    _tile(
                      'Kupon QR okut',
                      'Kamerayla okut veya kodu yaz',
                      Icons.qr_code_scanner,
                      () => _open(BusinessCouponScannerScreen(venueKey: _key)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reservation(Map<String, dynamic> row) {
    final at = DateTime.fromMillisecondsSinceEpoch(
      (row['atMs'] as num? ?? 0).toInt(),
    );
    final status =
        const {
          'pending': 'Onay bekliyor',
          'accepted': 'Onaylandı',
          'rejected': 'Reddedildi',
          'cancelled': 'İptal edildi',
        }[row['status']] ??
        'Sonuçlandı';
    final items = (row['orderItems'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['customerName'] ?? 'Misafir'} · ${row['partySize'] ?? 1} kişi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${at.day}.${at.month}.${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} · $status',
            ),
            if ((row['contactPhone'] ?? '').toString().isNotEmpty)
              Text(row['contactPhone'].toString()),
            if ((row['note'] ?? '').toString().isNotEmpty)
              Text(row['note'].toString()),
            for (final item in items)
              Text('${item['quantity']} × ${item['name']}'),
            if (items.isNotEmpty)
              Text(
                'Toplam: ${((row['orderTotalMinor'] as num? ?? 0) / 100).toStringAsFixed(2)} TL',
              ),
            if (row['status'] == 'pending')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _pending.contains(row['id'])
                        ? null
                        : () => _respond(row, 'accepted'),
                    child: const Text('Onayla'),
                  ),
                  OutlinedButton(
                    onPressed: _pending.contains(row['id'])
                        ? null
                        : () => _respond(row, 'rejected'),
                    child: const Text('Reddet'),
                  ),
                ],
              ),
            ReservationControls(
              data: {...row, 'venueKey': _key},
              owner: true,
              refresh: _refresh,
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessCouponScannerScreen extends StatefulWidget {
  final String venueKey;
  const BusinessCouponScannerScreen({super.key, required this.venueKey});
  @override
  State<BusinessCouponScannerScreen> createState() =>
      _BusinessCouponScannerScreenState();
}

class _BusinessCouponScannerScreenState
    extends State<BusinessCouponScannerScreen> {
  final _text = TextEditingController();
  bool _camera = false, _busy = false;
  String? _message;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _camera = false;
      _message = null;
    });
    try {
      final result = await BusinessService.instance.authenticatedCall(
        'validateBusinessCoupon',
        {'venueKey': widget.venueKey, 'token': _text.text.trim()},
      );
      if (mounted)
        setState(() {
          _message = '${result['title'] ?? 'Kupon'} kullanıldı.';
          _text.clear();
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _message = 'Kupon kullanılamadı. Kodu, geçerlilik süresini ve internet bağlantını kontrol et.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kupon doğrula')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_camera)
          SizedBox(
            height: 280,
            child: MobileScanner(
              onDetect: (capture) {
                if (!_camera || capture.barcodes.isEmpty) return;
                final raw = capture.barcodes.first.rawValue?.trim() ?? '';
                if (!RegExp(r'^TBT-[A-Fa-f0-9]{24}$').hasMatch(raw)) return;
                setState(() {
                  _text.text = raw;
                  _camera = false;
                  _message = 'QR okundu. Kullanmak için aşağıdan onayla.';
                });
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => setState(() => _camera = !_camera),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(_camera ? 'Kamerayı kapat' : 'Kamerayla QR okut'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Kupon kodu',
            hintText: 'TBT-…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _validate,
          child: Text(_busy ? 'Kontrol ediliyor…' : 'Kuponu doğrula ve kullan'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_message!),
          ),
      ],
    ),
  );
}
