import '../widgets/tbt_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessReservationScreen extends StatefulWidget {
  final String venueKey;
  const BusinessReservationScreen({super.key, required this.venueKey});
  @override
  State<BusinessReservationScreen> createState() =>
      _BusinessReservationScreenState();
}

class _BusinessReservationScreenState extends State<BusinessReservationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.displayName ?? '',
  );
  final _phone = TextEditingController(), _note = TextEditingController();
  final _requestId = DateTime.now().microsecondsSinceEpoch.toString();
  final Map<String, int> _quantities = {};
  late Future<QuerySnapshot<Map<String, dynamic>>> _menu;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rows = [];
  DateTime _at = DateTime.now().add(const Duration(hours: 2));
  int _people = 2;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _menu = _loadMenu();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadMenu() => FirebaseFirestore
      .instance
      .collection('business_venues')
      .doc(widget.venueKey)
      .collection('menu')
      .get();
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  int _price(Map<String, dynamic> d) => d['priceMinor'] is num
      ? (d['priceMinor'] as num).toInt()
      : ((d['price'] as num? ?? 0) * 100).round();
  Future<void> _date() async {
    final date = await showDatePicker(
      context: context,
      builder: (context, child) =>
          Theme(data: tbtDialogTheme(Theme.of(context)), child: child!),
      initialDate: _at,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      builder: (context, child) =>
          Theme(data: tbtDialogTheme(Theme.of(context)), child: child!),
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time != null && mounted)
      setState(
        () => _at = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_at.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gelecek bir tarih ve saat seç.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('requestBusinessReservation')
          .call({
            'venueKey': widget.venueKey,
            'requestId': _requestId,
            'partySize': _people,
            'atMs': _at.millisecondsSinceEpoch,
            'customerName': _name.text.trim(),
            'contactPhone': _phone.text.trim(),
            'note': _note.text.trim(),
            'orderItems': _rows
                .where((d) => (_quantities[d.id] ?? 0) > 0)
                .map(
                  (d) => {
                    'itemId': d.id,
                    'quantity': _quantities[d.id],
                    'expectedUnitPriceMinor': _price(d.data()),
                  },
                )
                .toList(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Talebin gönderildi. Profil → Rezervasyonlarım bölümünden takip edebilirsin.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Talep gönderilemedi.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep gönderilemedi. Yeniden dene.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rezervasyon ve sipariş')),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Adını ve soyadını gir.' : null,
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'İletişim telefonu'),
              validator: (v) =>
                  RegExp(r'^\+?[0-9 ()-]{8,30}$').hasMatch((v ?? '').trim())
                  ? null
                  : 'Geçerli telefon numarası gir.',
            ),
            const Text(
              'Adın ve bu telefon numarası rezervasyon yaptığın işletmeyle paylaşılır.',
            ),
            DropdownButtonFormField<int>(
              initialValue: _people,
              decoration: const InputDecoration(labelText: 'Kişi sayısı'),
              items: List.generate(
                50,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('${i + 1} kişi'),
                ),
              ),
              onChanged: (v) => setState(() => _people = v ?? 2),
            ),
            ListTile(
              title: Text(
                '${_at.day}.${_at.month}.${_at.year} ${_at.hour.toString().padLeft(2, '0')}:${_at.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _date,
            ),
            TextFormField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rezervasyon / sipariş notu',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sipariş ekle (isteğe bağlı)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _menu,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return TextButton(
                    onPressed: () => setState(() => _menu = _loadMenu()),
                    child: const Text('Menü yüklenemedi. Yeniden dene.'),
                  );
                if (!snapshot.hasData) return const LinearProgressIndicator();
                _rows = snapshot.data!.docs
                    .where(
                      (d) =>
                          d.data()['available'] != false &&
                          d.data()['active'] != false &&
                          (d.data()['priceMinor'] is num ||
                              d.data()['price'] is num),
                    )
                    .toList();
                if (_rows.isEmpty)
                  return const Text('Siparişe uygun menü ürünü bulunmuyor.');
                final total = _rows.fold<int>(
                  0,
                  (sum, d) => sum + _price(d.data()) * (_quantities[d.id] ?? 0),
                );
                return Column(
                  children: [
                    ..._rows.map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${d.data()['name'] ?? d.data()['title'] ?? 'Ürün'}',
                        ),
                        subtitle: Text(
                          '${(_price(d.data()) / 100).toStringAsFixed(2)} TL',
                        ),
                        trailing: DropdownButton<int>(
                          value: _quantities[d.id] ?? 0,
                          items: List.generate(
                            21,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('$i adet'),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _quantities[d.id] = v ?? 0),
                        ),
                      ),
                    ),
                    Text(
                      'Sipariş toplamı: ${(total / 100).toStringAsFixed(2)} TL',
                    ),
                    const Text(
                      'Rezervasyona 15 dakika kala hazırlık onayın istenir. Onay vermeden hazırlık başlamaz. Hazırlık sonrası iptal ve doğrulanmış gelmeme geçmişin sonraki taleplerini alan işletmelere gösterilir. Ödeme işletmede yapılır.',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Gönderiliyor…' : 'Talebi gönder'),
            ),
          ],
        ),
      ),
    ),
  );
}
