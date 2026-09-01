import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';

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
  void _message(BuildContext c, String t) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  String _error(Object e) => e is FirebaseFunctionsException
      ? (e.message ?? 'İşlem tamamlanamadı.')
      : e.toString().replaceFirst('Exception: ', '');

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
          if (snapshot.hasError)
            return const Center(child: Text('İçerikler yüklenemedi.'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) =>
                  ((b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0)
                      .compareTo(
                        (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0,
                      ),
            );
          if (docs.isEmpty) {
            final icon = switch (type) {
              'menu' => Icons.restaurant_menu_rounded,
              'campaign' => Icons.local_offer_outlined,
              _ => Icons.event_available_outlined,
            };
            final heading = switch (type) {
              'menu' => 'Menünü oluşturmaya başla',
              'campaign' => 'İlk kampanyanı yayınla',
              _ => 'Programını müşterilerinle paylaş',
            };
            final detail = switch (type) {
              'menu' => 'Ürünlerini fotoğraf, fiyat ve stok bilgisiyle profesyonel biçimde sergile.',
              'campaign' => 'Süreli fırsatlar ekle; bitiş tarihinde görünürlük otomatik kapansın.',
              _ => 'Etkinlik, canlı müzik veya özel programlarını tarih ve saat bilgisiyle ekle.',
            };
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: .12), shape: BoxShape.circle),
                      child: Icon(icon, size: 30, color: AppColors.cyan),
                    ),
                    const SizedBox(height: 16),
                    Text(heading, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.45)),
                    const SizedBox(height: 18),
                    FilledButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.add_rounded), label: const Text('Yeni içerik ekle')),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index], data = doc.data();
              final active = data['active'] != false;
              final expired =
                  type == 'campaign' &&
                  data['validUntil'] is Timestamp &&
                  (data['validUntil'] as Timestamp).toDate().isBefore(
                    DateTime.now(),
                  );
              final available = data['available'] != false;
              final image = (data['imageUrl'] ?? '').toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      if (type == 'menu')
                        Container(
                          width: 58,
                          height: 58,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surfaceStrong,
                          ),
                          child: image.isEmpty
                              ? const Icon(
                                  Icons.fastfood_outlined,
                                  color: Colors.white38,
                                )
                              : FirebaseMediaImage(
                                  imageUrl: image,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      if (type == 'menu') const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (data[type == 'menu' ? 'name' : 'title'] ??
                                            '')
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _Badge(
                                  text: expired
                                      ? 'Süresi Doldu'
                                      : !active
                                      ? 'Pasif'
                                      : type == 'menu' && !available
                                      ? 'Stokta Yok'
                                      : 'Aktif',
                                  active:
                                      active &&
                                      !expired &&
                                      (type != 'menu' || available),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _subtitle(data),
                              style: const TextStyle(
                                color: Colors.white60,
                                height: 1.35,
                              ),
                            ),
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
                              if (context.mounted)
                                _message(
                                  context,
                                  !active
                                      ? 'İçerik aktifleştirildi.'
                                      : 'İçerik pasife alındı.',
                                );
                            } catch (e) {
                              if (context.mounted) _message(context, _error(e));
                            }
                          } else if (value == 'availability' &&
                              type == 'menu') {
                            try {
                              await BusinessService.instance.updateContentItem(
                                category: category,
                                venueId: venueId,
                                type: type,
                                itemId: doc.id,
                                changes: {'available': !available},
                              );
                              if (context.mounted)
                                _message(
                                  context,
                                  !available
                                      ? 'Ürün tekrar satışta.'
                                      : 'Ürün stokta yok olarak işaretlendi.',
                                );
                            } catch (e) {
                              if (context.mounted) _message(context, _error(e));
                            }
                          } else if (value == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('İçeriği sil?'),
                                content: const Text('Bu işlem geri alınamaz.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('Vazgeç'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await BusinessService.instance
                                    .deleteContentItem(
                                      category: category,
                                      venueId: venueId,
                                      type: type,
                                      itemId: doc.id,
                                    );
                                if (context.mounted)
                                  _message(context, 'İçerik silindi.');
                              } catch (e) {
                                if (context.mounted)
                                  _message(context, _error(e));
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Düzenle'),
                            ),
                          ),
                          if (type == 'menu')
                            PopupMenuItem(
                              value: 'availability',
                              child: ListTile(
                                leading: Icon(
                                  available
                                      ? Icons.remove_shopping_cart_outlined
                                      : Icons.shopping_cart_checkout_outlined,
                                ),
                                title: Text(
                                  available ? 'Stokta yok' : 'Tekrar satışta',
                                ),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: ListTile(
                              leading: Icon(
                                active
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              title: Text(active ? 'Pasife al' : 'Aktifleştir'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Sil'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    final ts =
        data[type == 'campaign' ? 'validUntil' : 'startsAt'] as Timestamp?;
    final d = ts?.toDate();
    final date = d == null
        ? ''
        : '${d.day}.${d.month}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return [description, date].where((e) => e.isNotEmpty).join('\n');
  }

  Future<void> _edit(
    BuildContext c, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    if (type == 'menu') return _editMenu(c, id: id, data: data);
    if (type == 'campaign') return _editCampaign(c, id: id, data: data);
    return _editProgram(c, id: id, data: data);
  }

  Future<void> _editMenu(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final name = TextEditingController(text: (data?['name'] ?? '').toString()),
        section = TextEditingController(
          text: (data?['section'] ?? '').toString(),
        ),
        description = TextEditingController(
          text: (data?['description'] ?? '').toString(),
        );
    final old = ((data?['priceMinor'] as num?)?.toInt() ?? 0) / 100;
    final price = TextEditingController(
      text: id == null ? '' : old.toStringAsFixed(2),
    );
    bool available = data?['available'] != false;
    File? picked;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(id == null ? 'Menü ürünü ekle' : 'Menü ürününü düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ürün adı'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: section,
                  decoration: const InputDecoration(
                    labelText: 'Kategori / bölüm',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fiyat (TL)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Satışta / mevcut'),
                  value: available,
                  onChanged: (v) => setState(() => available = v),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 88,
                      maxWidth: 1600,
                      requestFullMetadata: false,
                    );
                    if (x != null) setState(() => picked = File(x.path));
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    picked != null
                        ? 'Yeni fotoğraf seçildi ✓'
                        : (data?['imageUrl'] ?? '').toString().isNotEmpty
                        ? 'Ürün fotoğrafını değiştir'
                        : 'Ürün fotoğrafı ekle',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                final parsed = double.tryParse(price.text.replaceAll(',', '.'));
                if (parsed == null || parsed < 0) return;
                try {
                  String itemId = id ?? '';
                  if (id == null) {
                    itemId = await BusinessService.instance.addMenuItem(
                      category: category,
                      venueId: venueId,
                      name: name.text,
                      section: section.text,
                      description: description.text,
                      priceMinor: (parsed * 100).round(),
                      available: available,
                    );
                  } else {
                    await BusinessService.instance.updateContentItem(
                      category: category,
                      venueId: venueId,
                      type: type,
                      itemId: id,
                      changes: {
                        'name': name.text,
                        'section': section.text,
                        'description': description.text,
                        'priceMinor': (parsed * 100).round(),
                        'available': available,
                      },
                    );
                  }
                  if (picked != null && itemId.isNotEmpty) {
                    final media = await BusinessService.instance
                        .uploadMenuImage(
                          category: category,
                          venueId: venueId,
                          itemId: itemId,
                          image: picked!,
                        );
                    await BusinessService.instance.updateContentItem(
                      category: category,
                      venueId: venueId,
                      type: 'menu',
                      itemId: itemId,
                      changes: media,
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted)
                    _message(
                      context,
                      id == null
                          ? 'Menü ürünü eklendi.'
                          : 'Menü ürünü güncellendi.',
                    );
                } catch (e) {
                  if (context.mounted) _message(context, _error(e));
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    section.dispose();
    description.dispose();
    price.dispose();
  }

  Future<void> _editCampaign(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final title = TextEditingController(
          text: (data?['title'] ?? '').toString(),
        ),
        description = TextEditingController(
          text: (data?['description'] ?? '').toString(),
        );
    var until =
        (data?['validUntil'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 7));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(id == null ? 'Kampanya ekle' : 'Kampanyayı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama ve koşullar',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    'Son gün: ${until.day}.${until.month}.${until.year}',
                  ),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: until.isBefore(DateTime.now())
                          ? DateTime.now()
                          : until,
                    );
                    if (p != null)
                      setState(
                        () => until = DateTime(p.year, p.month, p.day, 23, 59),
                      );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (id == null) {
                    await BusinessService.instance.addCampaign(
                      category: category,
                      venueId: venueId,
                      title: title.text,
                      description: description.text,
                      validUntil: until,
                    );
                  } else {
                    await BusinessService.instance.updateContentItem(
                      category: category,
                      venueId: venueId,
                      type: type,
                      itemId: id,
                      changes: {
                        'title': title.text,
                        'description': description.text,
                        'validUntilMs': until.millisecondsSinceEpoch,
                        'active': true,
                      },
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted)
                    _message(
                      context,
                      id == null
                          ? 'Kampanya yayınlandı.'
                          : 'Kampanya güncellendi.',
                    );
                } catch (e) {
                  if (context.mounted) _message(context, _error(e));
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
  }

  Future<void> _editProgram(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final title = TextEditingController(
          text: (data?['title'] ?? '').toString(),
        ),
        description = TextEditingController(
          text: (data?['description'] ?? '').toString(),
        );
    var starts =
        (data?['startsAt'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(hours: 2));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(id == null ? 'Program ekle' : 'Programı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(
                    '${starts.day}.${starts.month}.${starts.year} • ${starts.hour.toString().padLeft(2, '0')}:${starts.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: starts.isBefore(DateTime.now())
                          ? DateTime.now()
                          : starts,
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(starts),
                    );
                    if (time != null)
                      setState(
                        () => starts = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (id == null) {
                    await BusinessService.instance.addProgramItem(
                      category: category,
                      venueId: venueId,
                      title: title.text,
                      description: description.text,
                      startsAt: starts,
                    );
                  } else {
                    await BusinessService.instance.updateContentItem(
                      category: category,
                      venueId: venueId,
                      type: type,
                      itemId: id,
                      changes: {
                        'title': title.text,
                        'description': description.text,
                        'startsAtMs': starts.millisecondsSinceEpoch,
                      },
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted)
                    _message(
                      context,
                      id == null ? 'Program eklendi.' : 'Program güncellendi.',
                    );
                } catch (e) {
                  if (context.mounted) _message(context, _error(e));
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool active;
  const _Badge({required this.text, required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: active ? AppColors.cyan.withValues(alpha: .12) : Colors.white10,
    ),
    child: Text(
      text,
      style: TextStyle(
        color: active ? AppColors.cyan : Colors.white54,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
