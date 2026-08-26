import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminBusinessSandboxScreen extends StatefulWidget {
  final String venueName;
  final String category;

  const AdminBusinessSandboxScreen({
    super.key,
    required this.venueName,
    required this.category,
  });

  @override
  State<AdminBusinessSandboxScreen> createState() =>
      _AdminBusinessSandboxScreenState();
}

class _AdminBusinessSandboxScreenState
    extends State<AdminBusinessSandboxScreen> {
  String _description = '';
  String _phone = '';
  String _website = '';
  final Map<String, String> _hours = {
    'Pazartesi': '09:00 - 22:00',
    'Salı': '09:00 - 22:00',
    'Çarşamba': '09:00 - 22:00',
    'Perşembe': '09:00 - 22:00',
    'Cuma': '09:00 - 23:00',
    'Cumartesi': '10:00 - 23:00',
    'Pazar': '10:00 - 22:00',
  };
  final List<Map<String, dynamic>> _menu = [];
  final List<Map<String, dynamic>> _campaigns = [];
  final List<Map<String, dynamic>> _program = [];
  final List<Map<String, dynamic>> _posts = [];

  String get _categoryLabel => switch (widget.category) {
    'cafe' => 'Kafe',
    'dining' => 'Restoran / Yeme-İçme',
    'hotel' => 'Otel / Konaklama',
    _ => 'İşletme',
  };

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editProfile() async {
    final d = TextEditingController(text: _description);
    final p = TextEditingController(text: _phone);
    final w = TextEditingController(text: _website);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profil bilgilerini düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: d,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'İşletme hakkında'),
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      setState(() {
        _description = d.text.trim();
        _phone = p.text.trim();
        _website = w.text.trim();
      });
      _message('Demo profil güncellendi. Uygulamadan çıkınca silinir.');
    }
    d.dispose();
    p.dispose();
    w.dispose();
  }

  Future<void> _editHours() async {
    final copy = Map<String, String>.from(_hours);
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Çalışma Saatleri',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...copy.keys.map((day) {
                final controller = TextEditingController(text: copy[day]);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controller,
                    onChanged: (value) => copy[day] = value,
                    decoration: InputDecoration(labelText: day),
                  ),
                );
              }),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, copy),
                child: const Text('Demo Saatleri Uygula'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _hours
          ..clear()
          ..addAll(result);
      });
      _message('Demo çalışma saatleri değiştirildi. Kaydedilmedi.');
    }
  }

  Future<void> _editContent(
    String type, {
    int? index,
  }) async {
    final list = switch (type) {
      'menu' => _menu,
      'campaign' => _campaigns,
      'program' => _program,
      _ => _posts,
    };
    final existing = index == null ? <String, dynamic>{} : list[index];
    final title = TextEditingController(
      text: (existing[type == 'menu' ? 'name' : 'title'] ?? '').toString(),
    );
    final description = TextEditingController(
      text: (existing['description'] ?? '').toString(),
    );
    final extra = TextEditingController(
      text: type == 'menu'
          ? (existing['price'] ?? '').toString()
          : (existing['date'] ?? '').toString(),
    );
    var active = existing['active'] != false;
    var available = existing['available'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            index == null
                ? switch (type) {
                    'menu' => 'Menü ürünü ekle',
                    'campaign' => 'Kampanya ekle',
                    'program' => 'Etkinlik / program ekle',
                    _ => 'Paylaşım oluştur',
                  }
                : 'Demo içeriği düzenle',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: type == 'menu' ? 'Ürün adı' : 'Başlık',
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
                  controller: extra,
                  keyboardType:
                      type == 'menu' ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: type == 'menu'
                        ? 'Fiyat (TL)'
                        : 'Tarih / saat (demo)',
                    hintText: type == 'menu' ? '125' : '30.08.2026 20:00',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif / görünür'),
                  value: active,
                  onChanged: (value) => setDialog(() => active = value),
                ),
                if (type == 'menu')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Satışta / mevcut'),
                    value: available,
                    onChanged: (value) => setDialog(() => available = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Demo Olarak Uygula'),
            ),
          ],
        ),
      ),
    );

    if (save == true && mounted) {
      final item = <String, dynamic>{
        type == 'menu' ? 'name' : 'title': title.text.trim(),
        'description': description.text.trim(),
        if (type == 'menu') 'price': extra.text.trim(),
        if (type != 'menu') 'date': extra.text.trim(),
        'active': active,
        'available': available,
      };
      setState(() {
        if (index == null) {
          list.insert(0, item);
        } else {
          list[index] = item;
        }
      });
      _message('Demo içerik uygulandı. Hiçbir yere kaydedilmedi.');
    }
    title.dispose();
    description.dispose();
    extra.dispose();
  }

  void _delete(List<Map<String, dynamic>> list, int index) {
    setState(() => list.removeAt(index));
    _message('Demo içerik silindi. Gerçek veri etkilenmedi.');
  }

  Future<void> _openList(String type) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _SandboxListScreen(
          title: switch (type) {
            'menu' => 'Menü Yönetimi',
            'campaign' => 'Kampanya Yönetimi',
            'program' => 'Program / Etkinlik',
            _ => 'Fotoğraf / Video',
          },
          type: type,
          items: switch (type) {
            'menu' => _menu,
            'campaign' => _campaigns,
            'program' => _program,
            _ => _posts,
          },
          onAdd: () => _editContent(type),
          onEdit: (index) => _editContent(type, index: index),
          onDelete: (index) {
            final list = switch (type) {
              'menu' => _menu,
              'campaign' => _campaigns,
              'program' => _program,
              _ => _posts,
            };
            _delete(list, index);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Icon(icon, color: AppColors.cyan),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('İşletme Test Modu')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface,
            border: Border.all(color: AppColors.cyan.withValues(alpha: .45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_outlined, color: AppColors.cyan),
                  SizedBox(width: 8),
                  Text(
                    'ADMİN TEST MODU',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.venueName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(_categoryLabel, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              const Text(
                'Burada işletme sahibinin yapabildiği işlemleri deneyebilirsin. Eklediğin menü, kampanya, etkinlik ve profil değişiklikleri yalnızca bu ekran açıkken bellekte tutulur; Firebase veya gerçek işletmeye yazılmaz.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _tile(
          Icons.store_mall_directory_outlined,
          'Profil Bilgileri',
          _description.isEmpty ? 'Açıklama, telefon ve web sitesini dene' : 'Demo profil değiştirildi',
          _editProfile,
        ),
        _tile(
          Icons.schedule_rounded,
          'Çalışma Saatleri',
          'Açılış ve kapanış saatlerini dene',
          _editHours,
        ),
        _tile(
          Icons.restaurant_menu_rounded,
          'Menü Yönetimi',
          '${_menu.length} demo ürün • ekle, düzenle, sil',
          () => _openList('menu'),
        ),
        _tile(
          Icons.local_offer_outlined,
          'Kampanya Yönetimi',
          '${_campaigns.length} demo kampanya',
          () => _openList('campaign'),
        ),
        _tile(
          Icons.calendar_month_rounded,
          'Program / Etkinlik',
          '${_program.length} demo etkinlik • planla ve düzenle',
          () => _openList('program'),
        ),
        _tile(
          Icons.add_to_photos_outlined,
          'Fotoğraf / Video Paylaş',
          '${_posts.length} demo paylaşım',
          () => _openList('post'),
        ),
        _tile(
          Icons.workspace_premium_outlined,
          'TBT Business Pro',
          'Rezervasyon, Boost ve istatistik ekranını simüle et',
          () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            backgroundColor: AppColors.background,
            builder: (_) => const Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Business Pro • Demo', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  SizedBox(height: 12),
                  ListTile(leading: Icon(Icons.insights_rounded), title: Text('İstatistikler'), subtitle: Text('1.284 profil görüntülenmesi • demo veri')),
                  ListTile(leading: Icon(Icons.event_seat_outlined), title: Text('Rezervasyonlar'), subtitle: Text('12 bekleyen • demo veri')),
                  ListTile(leading: Icon(Icons.rocket_launch_outlined), title: Text('Boost'), subtitle: Text('Kampanya görünürlüğünü artır • demo')),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SandboxListScreen extends StatefulWidget {
  final String title;
  final String type;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onAdd;
  final Future<void> Function(int) onEdit;
  final void Function(int) onDelete;

  const _SandboxListScreen({
    required this.title,
    required this.type,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SandboxListScreen> createState() => _SandboxListScreenState();
}

class _SandboxListScreenState extends State<_SandboxListScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text('${widget.title} • Demo')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await widget.onAdd();
        if (mounted) setState(() {});
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text('Yeni Ekle'),
    ),
    body: widget.items.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Henüz demo içerik yok. Yeni Ekle ile işletme sahibi gibi denemeye başla. Buradaki hiçbir şey kaydolmaz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final title = (item[widget.type == 'menu' ? 'name' : 'title'] ?? '').toString();
              final subtitle = [
                (item['description'] ?? '').toString(),
                if (widget.type == 'menu' && (item['price'] ?? '').toString().isNotEmpty) '${item['price']} ₺',
                if (widget.type != 'menu') (item['date'] ?? '').toString(),
              ].where((e) => e.isNotEmpty).join(' • ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    widget.type == 'menu'
                        ? Icons.fastfood_outlined
                        : widget.type == 'program'
                        ? Icons.event_outlined
                        : widget.type == 'campaign'
                        ? Icons.local_offer_outlined
                        : Icons.photo_library_outlined,
                    color: AppColors.cyan,
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(subtitle.isEmpty ? 'Demo içerik' : subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await widget.onEdit(index);
                      if (value == 'delete') widget.onDelete(index);
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
