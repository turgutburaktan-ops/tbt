import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';

class BusinessContentManagerScreen extends StatelessWidget {
  final String category;
  final String venueId;
  final String type;

  const BusinessContentManagerScreen({
    super.key,
    required this.category,
    required this.venueId,
    required this.type,
  });

  String get _venueKey => BusinessService.instance.venueKey(category, venueId);
  String get _collection => switch (type) {
        'menu' => 'menu',
        'campaign' => 'campaigns',
        _ => 'program',
      };
  String get _title => switch (type) {
        'menu' => 'Menü Yönetimi',
        'campaign' => 'Kampanya Yönetimi',
        _ => 'Program / Etkinlik Yönetimi',
      };

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _error(Object e) {
    if (e is FirebaseFunctionsException) return e.message ?? 'İşlem tamamlanamadı.';
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('business_venues')
        .doc(_venueKey)
        .collection(_collection)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('İçerikler yüklenemedi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = a.data()['createdAt'] as Timestamp?;
              final bd = b.data()['createdAt'] as Timestamp?;
              return (bd?.millisecondsSinceEpoch ?? 0)
                  .compareTo(ad?.millisecondsSinceEpoch ?? 0);
            });
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inbox_outlined, size: 56, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text('Henüz içerik yok. Yeni Ekle ile başlayabilirsin.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54)),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final active = data['active'] != false;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                (data[type == 'menu' ? 'name' : 'title'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: active ? AppColors.cyan.withValues(alpha: .12) : Colors.white10,
                              ),
                              child: Text(active ? 'Aktif' : 'Pasif',
                                  style: TextStyle(
                                    color: active ? AppColors.cyan : Colors.white54,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Text(_subtitle(data), style: const TextStyle(color: Colors.white60, height: 1.35)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _edit(context, id: doc.id, data: data);
                        } else if (value == 'toggle') {
                          try {
                            await BusinessService.instance.setContentActive(
                              category: category,
                              venueId: venueId,
                              type: type,
                              itemId: doc.id,
                              active: !active,
                            );
                            if (context.mounted) _message(context, !active ? 'İçerik aktifleştirildi.' : 'İçerik pasife alındı.');
                          } catch (e) {
                            if (context.mounted) _message(context, _error(e));
                          }
                        } else if (value == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('İçeriği sil?'),
                              content: const Text('Bu işlem geri alınamaz.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
                                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await BusinessService.instance.deleteContentItem(
                                category: category,
                                venueId: venueId,
                                type: type,
                                itemId: doc.id,
                              );
                              if (context.mounted) _message(context, 'İçerik silindi.');
                            } catch (e) {
                              if (context.mounted) _message(context, _error(e));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Düzenle'))),
                        PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(active ? Icons.visibility_off_outlined : Icons.visibility_outlined), title: Text(active ? 'Pasife al' : 'Aktifleştir'))),
                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Sil'))),
                      ],
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _subtitle(Map<String, dynamic> data) {
    if (type == 'menu') {
      final price = ((data['priceMinor'] as num?)?.toInt() ?? 0) / 100;
      return [
        (data['section'] ?? '').toString(),
        (data['description'] ?? '').toString(),
        '${price.toStringAsFixed(2)} ₺',
      ].where((e) => e.isNotEmpty).join('\n');
    }
    final description = (data['description'] ?? '').toString();
    final ts = data[type == 'campaign' ? 'validUntil' : 'startsAt'] as Timestamp?;
    final d = ts?.toDate();
    final dateText = d == null
        ? ''
        : '${d.day}.${d.month}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return [description, dateText].where((e) => e.isNotEmpty).join('\n');
  }

  Future<void> _edit(BuildContext context, {String? id, Map<String, dynamic>? data}) async {
    if (type == 'menu') return _editMenu(context, id: id, data: data);
    if (type == 'campaign') return _editCampaign(context, id: id, data: data);
    return _editProgram(context, id: id, data: data);
  }

  Future<void> _editMenu(BuildContext context, {String? id, Map<String, dynamic>? data}) async {
    final name = TextEditingController(text: (data?['name'] ?? '').toString());
    final section = TextEditingController(text: (data?['section'] ?? '').toString());
    final description = TextEditingController(text: (data?['description'] ?? '').toString());
    final oldPrice = ((data?['priceMinor'] as num?)?.toInt() ?? 0) / 100;
    final price = TextEditingController(text: id == null ? '' : oldPrice.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(id == null ? 'Menü ürünü ekle' : 'Menü ürününü düzenle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Ürün adı')),
          TextField(controller: section, decoration: const InputDecoration(labelText: 'Bölüm')),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fiyat (TL)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            final parsed = double.tryParse(price.text.replaceAll(',', '.'));
            if (parsed == null || parsed < 0) return;
            try {
              if (id == null) {
                await BusinessService.instance.addMenuItem(category: category, venueId: venueId, name: name.text, section: section.text, description: description.text, priceMinor: (parsed * 100).round());
              } else {
                await BusinessService.instance.updateContentItem(category: category, venueId: venueId, type: type, itemId: id, changes: {'name': name.text, 'section': section.text, 'description': description.text, 'priceMinor': (parsed * 100).round()});
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) _message(context, id == null ? 'Menü ürünü eklendi.' : 'Menü ürünü güncellendi.');
            } catch (e) {
              if (context.mounted) _message(context, _error(e));
            }
          }, child: const Text('Kaydet')),
        ],
      ),
    );
  }

  Future<void> _editCampaign(BuildContext context, {String? id, Map<String, dynamic>? data}) async {
    final title = TextEditingController(text: (data?['title'] ?? '').toString());
    final description = TextEditingController(text: (data?['description'] ?? '').toString());
    var until = (data?['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7));
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(id == null ? 'Kampanya ekle' : 'Kampanyayı düzenle'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık')),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama ve koşullar')),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_available_outlined), title: Text('Son gün: ${until.day}.${until.month}.${until.year}'), onTap: () async {
          final picked = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: until);
          if (picked != null) setState(() => until = DateTime(picked.year, picked.month, picked.day, 23, 59));
        }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
        FilledButton(onPressed: () async {
          try {
            if (id == null) {
              await BusinessService.instance.addCampaign(category: category, venueId: venueId, title: title.text, description: description.text, validUntil: until);
            } else {
              await BusinessService.instance.updateContentItem(category: category, venueId: venueId, type: type, itemId: id, changes: {'title': title.text, 'description': description.text, 'validUntilMs': until.millisecondsSinceEpoch});
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) _message(context, id == null ? 'Kampanya yayınlandı.' : 'Kampanya güncellendi.');
          } catch (e) {
            if (context.mounted) _message(context, _error(e));
          }
        }, child: const Text('Kaydet')),
      ],
    )));
  }

  Future<void> _editProgram(BuildContext context, {String? id, Map<String, dynamic>? data}) async {
    final title = TextEditingController(text: (data?['title'] ?? '').toString());
    final description = TextEditingController(text: (data?['description'] ?? '').toString());
    var startsAt = (data?['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 2));
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(id == null ? 'Program ekle' : 'Programı düzenle'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık')),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama')),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule_rounded), title: Text('${startsAt.day}.${startsAt.month}.${startsAt.year} • ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'), onTap: () async {
          final date = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: startsAt);
          if (date == null || !context.mounted) return;
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
          if (time != null) setState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
        }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
        FilledButton(onPressed: () async {
          try {
            if (id == null) {
              await BusinessService.instance.addProgramItem(category: category, venueId: venueId, title: title.text, description: description.text, startsAt: startsAt);
            } else {
              await BusinessService.instance.updateContentItem(category: category, venueId: venueId, type: type, itemId: id, changes: {'title': title.text, 'description': description.text, 'startsAtMs': startsAt.millisecondsSinceEpoch});
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) _message(context, id == null ? 'Program eklendi.' : 'Program güncellendi.');
          } catch (e) {
            if (context.mounted) _message(context, _error(e));
          }
        }, child: const Text('Kaydet')),
      ],
    )));
  }
}
