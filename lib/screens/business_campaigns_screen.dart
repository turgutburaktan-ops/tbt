import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/business_service.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import 'business_management_screen.dart';

String businessDate(num? ms) {
  if (ms == null || ms == 0) return 'Belirtilmedi';
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt()).toLocal();
  return '${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const businessGoals = {
  'offer': 'Fırsat ve kupon',
  'reservation': 'Rezervasyon',
  'event': 'Etkinlik',
};
const businessDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

class BusinessCampaignsScreen extends StatefulWidget {
  final String venueKey, venueName;
  final bool coupons;
  const BusinessCampaignsScreen({
    super.key,
    required this.venueKey,
    required this.venueName,
    this.coupons = false,
  });
  @override
  State<BusinessCampaignsScreen> createState() =>
      _BusinessCampaignsScreenState();
}

class _BusinessCampaignsScreenState extends State<BusinessCampaignsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = false;
  final _busy = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BusinessService.instance.authenticatedCall(
        widget.coupons ? 'getBusinessWebTools' : 'getBusinessGrowthDashboard',
        {'venueKey': widget.venueKey},
      );
      final rows = (result[widget.coupons ? 'coupons' : 'items'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessCampaignEditor(
          venueKey: widget.venueKey,
          venueName: widget.venueName,
          coupon: widget.coupons,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _toggle(Map<String, dynamic> x) async {
    final id = x['id'].toString();
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await BusinessService.instance.authenticatedCall(
        'setBusinessGrowthCampaignActive',
        {
          'venueKey': widget.venueKey,
          'campaignId': id,
          'active': x['active'] == false,
        },
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String _status(Map<String, dynamic> x) {
    if (x['active'] == false) return 'Duraklatıldı';
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((x['validUntilMs'] as num? ?? 0) <= now) return 'Sona erdi';
    if ((x['startsAtMs'] as num? ?? 0) > now) return 'Planlandı';
    return 'Yayında';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.coupons ? 'Kuponlar' : 'Kampanyalar'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.venueName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: Text(
              widget.coupons ? 'Yeni kupon oluştur' : 'Yeni kampanya oluştur',
            ),
          ),
          if (widget.coupons)
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BusinessCouponScannerScreen(venueKey: widget.venueKey),
                  ),
                );
                if (mounted) await _load();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Müşteri kuponunu doğrula'),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!),
            ),
          if (_items != null && widget.coupons)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '${_items!.length} kupon · ${_items!.where((x) => _status(x) == 'Yayında').length} aktif · ${_items!.fold<num>(0, (n, x) => n + (x['useCount'] as num? ?? 0))} kullanım',
              ),
            ),
          if (_items?.isEmpty == true)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Henüz içerik yok. Yukarıdan ilkini oluşturabilirsin.',
              ),
            ),
          for (final x in _items ?? <Map<String, dynamic>>[])
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.coupons ? 'QR Kupon' : businessGoals[x['goal']] ?? 'Kampanya'} · ${_status(x)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${x['title'] ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('${x['description'] ?? ''}'),
                      if (!widget.coupons)
                        Text(
                          'Başlangıç: ${businessDate(x['startsAtMs'] as num?)}',
                        ),
                      Text('Bitiş: ${businessDate(x['validUntilMs'] as num?)}'),
                      if ((x['days'] as List? ?? []).isNotEmpty)
                        Text(
                          'Günler: ${(x['days'] as List).where((d) => d is num && d >= 1 && d <= 7).map((d) => businessDays[(d as num).toInt() - 1]).join(', ')}',
                        ),
                      if ((x['dailyStart'] ?? '').toString().isNotEmpty)
                        Text(
                          '${x['dailyStart']} – ${x['dailyEnd']} · Türkiye saati',
                        ),
                      if ((x['terms'] ?? '').toString().isNotEmpty)
                        Text('Koşullar: ${x['terms']}'),
                      const Divider(height: 24),
                      if (widget.coupons)
                        Text(
                          'Kontenjan: ${x['maxClaims'] ?? 0}\nAlınan: ${x['claimCount'] ?? 0} · Kullanılan: ${x['useCount'] ?? 0}',
                        )
                      else ...[
                        Text(
                          'Görüntüleme: ${x['views'] ?? 0} · Detay açılma: ${x['opens'] ?? 0}',
                        ),
                        if (x['goal'] == 'offer')
                          Text(
                            'Alınan kupon: ${x['claims'] ?? 0} · Kullanım: ${x['uses'] ?? 0}',
                          ),
                        if (x['goal'] == 'event')
                          Text('Katılımcı: ${x['participants'] ?? 0}'),
                        if (x['goal'] == 'reservation')
                          const Text(
                            'Rezervasyonları işletme panelindeki Talepler bölümünden yönetebilirsin.',
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Geliş kaynakları'),
                          children: [
                            const Text(
                              'Bağlantı etiketlerine göre detay açılmaları; kesin reklam etkisini göstermez.',
                            ),
                            for (final source in const {
                              'tbt': 'TBT',
                              'instagram': 'Instagram',
                              'whatsapp': 'WhatsApp',
                              'creator': 'Creator',
                              'direct': 'Doğrudan',
                            }.entries)
                              ListTile(
                                dense: true,
                                title: Text(source.value),
                                trailing: Text(
                                  '${((x['sources'] as Map?)?[source.key] as Map?)?['open'] ?? 0}',
                                ),
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BusinessCampaignShare(
                                    id: x['id'].toString(),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code),
                              label: const Text('Bağlantı / QR'),
                            ),
                            if ((x['validUntilMs'] as num? ?? 0) >
                                DateTime.now().millisecondsSinceEpoch)
                              TextButton(
                                onPressed: _busy.contains(x['id'])
                                    ? null
                                    : () => _toggle(x),
                                child: Text(
                                  x['active'] == false
                                      ? 'Yeniden yayınla'
                                      : 'Duraklat',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class BusinessCampaignEditor extends StatefulWidget {
  final String venueKey, venueName;
  final bool coupon;
  const BusinessCampaignEditor({
    super.key,
    required this.venueKey,
    required this.venueName,
    this.coupon = false,
  });
  @override
  State<BusinessCampaignEditor> createState() => _BusinessCampaignEditorState();
}

class _BusinessCampaignEditorState extends State<BusinessCampaignEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _terms = TextEditingController(),
      _capacity = TextEditingController(text: '100');
  final _requestId = _newRequestId();
  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  String _goal = 'offer';
  DateTime _start = DateTime.now(),
      _end = DateTime.now().add(const Duration(days: 7));
  TimeOfDay? _dailyStart, _dailyEnd;
  final _days = <int>{};
  Map<String, dynamic>? _payload;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _description, _terms, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  String _clock(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  Future<void> _pickDate(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime:
          (start ? _dailyStart : _dailyEnd) ??
          const TimeOfDay(hour: 12, minute: 0),
    );
    if (value != null && mounted)
      setState(() {
        if (start) {
          _dailyStart = value;
        } else {
          _dailyEnd = value;
        }
      });
  }

  Map<String, dynamic>? _validated() {
    if (!_form.currentState!.validate()) return null;
    if (!_end.isAfter(DateTime.now()) ||
        (!widget.coupon && !_end.isAfter(_start))) {
      setState(() => _error = 'Bitiş, başlangıçtan ve şu andan sonra olmalı.');
      return null;
    }
    if (!widget.coupon &&
        _goal == 'offer' &&
        ((_dailyStart == null) != (_dailyEnd == null) ||
            (_dailyStart != null &&
                _dailyStart!.hour * 60 + _dailyStart!.minute >=
                    _dailyEnd!.hour * 60 + _dailyEnd!.minute))) {
      setState(
        () => _error =
            'Geçerli saat aralığının başlangıç ve bitişini kontrol et.',
      );
      return null;
    }
    return {
      'venueKey': widget.venueKey,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'validUntilMs': _end.millisecondsSinceEpoch,
      'maxClaims': int.tryParse(_capacity.text) ?? 100,
      if (!widget.coupon) ...{
        'requestId': _requestId,
        'goal': _goal,
        'terms': _terms.text.trim(),
        'startsAtMs': _start.millisecondsSinceEpoch,
        'days': _goal == 'offer' ? (_days.toList()..sort()) : <int>[],
        'dailyStart': _goal == 'offer' ? _clock(_dailyStart) : '',
        'dailyEnd': _goal == 'offer' ? _clock(_dailyEnd) : '',
      },
    };
  }

  Future<void> _save() async {
    if (_busy) return;
    final payload = _payload ?? _validated();
    if (payload == null) return;
    setState(() {
      _busy = true;
      _error = null;
      if (!widget.coupon) _payload = payload;
    });
    try {
      await BusinessService.instance.authenticatedCall(
        widget.coupon ? 'createBusinessCoupon' : 'createBusinessGrowthCampaign',
        payload,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = userFacingError(e);
          if (e is BusinessCallException &&
              [
                'INVALID_ARGUMENT',
                'PERMISSION_DENIED',
                'UNAUTHENTICATED',
              ].contains(e.code))
            _payload = null;
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final p = _validated();
    if (p == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_title.text),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.venueName),
              Text(_description.text),
              if (!widget.coupon)
                Text(
                  'Başlangıç: ${businessDate(_start.millisecondsSinceEpoch)}',
                ),
              Text('Bitiş: ${businessDate(_end.millisecondsSinceEpoch)}'),
              if (_goal == 'offer' && _days.isNotEmpty)
                Text(_days.map((d) => businessDays[d - 1]).join(', ')),
              if (_dailyStart != null)
                Text(
                  '${_clock(_dailyStart)} – ${_clock(_dailyEnd)} · Türkiye saati',
                ),
              if (widget.coupon || _goal != 'reservation')
                Text('Kontenjan: ${_capacity.text}'),
              Text(_terms.text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Düzenlemeye dön'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _payload != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.coupon ? 'Yeni kupon' : 'Yeni kampanya'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.venueName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (!widget.coupon)
              DropdownButtonFormField<String>(
                initialValue: _goal,
                decoration: const InputDecoration(labelText: 'Kampanya hedefi'),
                items: businessGoals.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: locked
                    ? null
                    : (value) => setState(() {
                        _goal = value!;
                        if (_goal == 'event') {
                          _start = DateTime.now().add(const Duration(days: 1));
                          _end = _start.add(const Duration(hours: 3));
                        }
                      }),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              enabled: !locked,
              maxLength: widget.coupon ? 160 : 140,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                hintText: 'Örn. İkinci kahve bizden',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 3 ? 'En az 3 karakter yaz.' : null,
            ),
            TextFormField(
              controller: _description,
              enabled: !locked,
              maxLength: 700,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: widget.coupon
                    ? 'Açıklama (isteğe bağlı)'
                    : 'Açıklama',
              ),
              validator: (v) => !widget.coupon && (v?.trim().isEmpty ?? true)
                  ? 'Teklifini açıkla.'
                  : null,
            ),
            Card(
              child: Column(
                children: [
                  if (!widget.coupon)
                    ListTile(
                      title: const Text('Başlangıç tarihi ve saati'),
                      subtitle: Text(
                        businessDate(_start.millisecondsSinceEpoch),
                      ),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: locked ? null : () => _pickDate(true),
                    ),
                  ListTile(
                    title: const Text('Son kullanım tarihi ve saati'),
                    subtitle: Text(businessDate(_end.millisecondsSinceEpoch)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: locked ? null : () => _pickDate(false),
                  ),
                ],
              ),
            ),
            if (!widget.coupon && _goal == 'offer')
              ExpansionTile(
                title: const Text('Geçerli günler ve saatler'),
                children: [
                  const Text(
                    'Seçim yapmazsan tüm gün ve saatlerde geçerlidir. Saatler Türkiye saatidir.',
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var i = 1; i <= 7; i++)
                        FilterChip(
                          label: Text(businessDays[i - 1]),
                          selected: _days.contains(i),
                          onSelected: locked
                              ? null
                              : (v) => setState(() {
                                  if (v) {
                                    _days.add(i);
                                  } else {
                                    _days.remove(i);
                                  }
                                }),
                        ),
                    ],
                  ),
                  ListTile(
                    title: const Text('Saat başlangıcı'),
                    trailing: Text(
                      _dailyStart == null ? 'Seç' : _clock(_dailyStart),
                    ),
                    onTap: locked ? null : () => _pickTime(true),
                  ),
                  ListTile(
                    title: const Text('Saat bitişi'),
                    trailing: Text(
                      _dailyEnd == null ? 'Seç' : _clock(_dailyEnd),
                    ),
                    onTap: locked ? null : () => _pickTime(false),
                  ),
                  TextButton(
                    onPressed: locked
                        ? null
                        : () => setState(() {
                            _dailyStart = null;
                            _dailyEnd = null;
                            _days.clear();
                          }),
                    child: const Text('Gün ve saat sınırlamasını kaldır'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (widget.coupon || _goal != 'reservation')
              TextFormField(
                controller: _capacity,
                enabled: !locked,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _goal == 'event' && !widget.coupon
                      ? 'Katılımcı kapasitesi'
                      : 'Toplam kupon kontenjanı',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 100000
                      ? '1–100000 arasında tam sayı gir.'
                      : null;
                },
              ),
            const SizedBox(height: 12),
            if (!widget.coupon)
              TextFormField(
                controller: _terms,
                enabled: !locked,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Koşullar (isteğe bağlı)',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.liked),
                ),
              ),
            if (_payload != null && !_busy)
              const Text(
                'Yanıt alınamadıysa aynı bilgilerle tekrar deneyebilirsin. Aynı kampanya iki kez oluşturulmaz.',
              ),
            OutlinedButton(
              onPressed: locked ? null : _preview,
              child: const Text('Önizleme'),
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Yayınlanıyor…'
                    : _payload != null
                    ? 'Aynı bilgilerle tekrar dene'
                    : widget.coupon
                    ? 'Kuponu yayınla'
                    : 'Ücretsiz yayınla',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class BusinessCampaignShare extends StatefulWidget {
  final String id;
  const BusinessCampaignShare({super.key, required this.id});
  @override
  State<BusinessCampaignShare> createState() => _BusinessCampaignShareState();
}

class _BusinessCampaignShareState extends State<BusinessCampaignShare> {
  String _source = 'instagram';
  String get _link => Uri.https('trtbt.com', '/', {
    'tbt_source': _source,
  }).replace(fragment: '/firsat/${widget.id}').toString();
  bool _exporting = false;
  Future<void> _exportQr() async {
    if (_exporting) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      final painter = QrPainter(
        data: _link,
        version: QrVersions.auto,
        gapless: true,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.translate(48, 48);
      painter.paint(canvas, const Size(928, 928));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (bytes == null) throw Exception('QR görseli oluşturulamadı.');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/tbt-kampanya-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: _link,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kampanyanı paylaş')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _source,
          decoration: const InputDecoration(labelText: 'Paylaşım kanalı'),
          items: const [
            DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
            DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
            DropdownMenuItem(value: 'creator', child: Text('Creator')),
            DropdownMenuItem(value: 'direct', child: Text('Diğer / masa QR’ı')),
          ],
          onChanged: (v) => setState(() => _source = v!),
        ),
        const SizedBox(height: 20),
        Center(
          child: QrImageView(
            data: _link,
            size: 250,
            backgroundColor: Colors.white,
          ),
        ),
        SelectableText(_link),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _exportQr,
          icon: const Icon(Icons.download_outlined),
          label: Text(
            _exporting ? 'Hazırlanıyor…' : 'QR görselini kaydet / paylaş',
          ),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _link));
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bağlantı kopyalandı.')),
              );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Bağlantıyı kopyala'),
        ),
        OutlinedButton(
          onPressed: () async {
            final ok = await launchUrl(
              Uri.parse(_link),
              mode: LaunchMode.externalApplication,
            );
            if (!ok && context.mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sayfa açılamadı.')));
          },
          child: const Text('Müşteri görünümünü aç'),
        ),
      ],
    ),
  );
}
