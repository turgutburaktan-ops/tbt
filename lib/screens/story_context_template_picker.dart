import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StoryContextTemplateSelection {
  final String contextType;
  final String contextId;
  final String contextName;
  final String templateId;
  final String templateTitle;
  final int slotCount;

  const StoryContextTemplateSelection({
    required this.contextType,
    required this.contextId,
    required this.contextName,
    required this.templateId,
    required this.templateTitle,
    required this.slotCount,
  });
}

class StoryContextTemplatePicker extends StatefulWidget {
  const StoryContextTemplatePicker({super.key});

  @override
  State<StoryContextTemplatePicker> createState() =>
      _StoryContextTemplatePickerState();
}

class _StoryContextTemplatePickerState
    extends State<StoryContextTemplatePicker> {
  int _tab = 0;
  String _query = '';
  _ContextItem? _selectedContext;

  static const _tabs = <_TabSpec>[
    _TabSpec('Etkinlik', 'event', Icons.local_activity_outlined),
    _TabSpec('Mekan', 'venue', Icons.storefront_outlined),
    _TabSpec('Gezi', 'spot', Icons.landscape_outlined),
    _TabSpec('Serbest', 'free', Icons.auto_awesome_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final spec = _tabs[_tab];
    return Scaffold(
      backgroundColor: const Color(0xFF090A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Story Şablonları',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == _tab;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _tab = i;
                    _selectedContext = null;
                    _query = '';
                  }),
                  avatar: Icon(_tabs[i].icon, size: 17),
                  label: Text(_tabs[i].label),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          if (spec.type != 'free' && _selectedContext == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                onChanged: (value) => setState(
                  () => _query = value.trim().toLowerCase(),
                ),
                decoration: InputDecoration(
                  hintText: '${spec.label} ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFF15181D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: spec.type == 'free'
                ? _TemplateList(
                    contextItem: const _ContextItem(
                      id: '',
                      name: 'Serbest Story',
                      type: 'free',
                    ),
                    onSelected: _finish,
                  )
                : _ContextBrowser(
                    spec: spec,
                    query: _query,
                    selected: _selectedContext,
                    onContextSelected: (item) =>
                        setState(() => _selectedContext = item),
                    onBack: () => setState(() => _selectedContext = null),
                    onTemplateSelected: _finish,
                  ),
          ),
        ],
      ),
    );
  }

  void _finish(_ContextItem contextItem, _TemplateSpec template) {
    Navigator.pop(
      context,
      StoryContextTemplateSelection(
        contextType: contextItem.type,
        contextId: contextItem.id,
        contextName: contextItem.name,
        templateId: template.id,
        templateTitle: template.title,
        slotCount: template.slotCount,
      ),
    );
  }
}

class _ContextBrowser extends StatelessWidget {
  final _TabSpec spec;
  final String query;
  final _ContextItem? selected;
  final ValueChanged<_ContextItem> onContextSelected;
  final VoidCallback onBack;
  final void Function(_ContextItem, _TemplateSpec) onTemplateSelected;

  const _ContextBrowser({
    required this.spec,
    required this.query,
    required this.selected,
    required this.onContextSelected,
    required this.onBack,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (selected != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    selected!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _TemplateList(
              contextItem: selected!,
              onSelected: onTemplateSelected,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(spec.collection)
          .limit(100)
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.docs.map((doc) {
          final data = doc.data();
          return _ContextItem(
            id: doc.id,
            name: _nameFor(spec.type, data),
            type: spec.type,
          );
        }).where((item) {
          if (item.name.trim().isEmpty) return false;
          return query.isEmpty || item.name.toLowerCase().contains(query);
        }).toList();
        items.sort((a, b) => a.name.compareTo(b.name));
        if (items.isEmpty) {
          return Center(
            child: Text(
              '${spec.label} bulunamadı',
              style: const TextStyle(color: Colors.white60),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              tileColor: const Color(0xFF14171C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF242830),
                child: Icon(spec.icon),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onContextSelected(item),
            );
          },
        );
      },
    );
  }

  static String _nameFor(String type, Map<String, dynamic> data) {
    if (type == 'event') {
      return (data['title'] ?? data['name'] ?? 'Etkinlik').toString().trim();
    }
    if (type == 'venue') {
      return (data['name'] ?? data['title'] ?? 'Mekan').toString().trim();
    }
    return (data['name'] ?? data['title'] ?? 'Gezilecek yer').toString().trim();
  }
}

class _TemplateList extends StatelessWidget {
  final _ContextItem contextItem;
  final void Function(_ContextItem, _TemplateSpec) onSelected;

  const _TemplateList({
    required this.contextItem,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final templates = _templatesFor(contextItem.type);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .86,
      ),
      itemCount: templates.length,
      itemBuilder: (_, i) {
        final template = templates[i];
        return InkWell(
          onTap: () => onSelected(contextItem, template),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF15181D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TemplatePreview(template: template),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    template.subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static List<_TemplateSpec> _templatesFor(String type) {
    switch (type) {
      case 'event':
        return const [
          _TemplateSpec('event_invite', 'Etkinliğe davet', 1, 'Tarih • saat • konum'),
          _TemplateSpec('event_countdown', 'Geri sayım', 1, 'Başlangıca kalan süre'),
          _TemplateSpec('event_schedule', 'Program akışı', 2, 'Saat saat program'),
          _TemplateSpec('event_last_seats', 'Son kontenjan', 1, 'Harekete geçirici duyuru'),
          _TemplateSpec('event_4_moments', 'Etkinlikten 4 an', 4, 'Dinamik fotoğraf kolajı'),
          _TemplateSpec('event_stage_vibe', 'Sahne + ortam + ekip', 4, 'Atmosfer ve ekip'),
          _TemplateSpec('event_night_recap', 'Gecenin özeti', 4, 'Editoryal gece özeti'),
          _TemplateSpec('event_thank_you', 'Katılanlara teşekkür', 2, 'Etkinlik kapanışı'),
        ];
      case 'venue':
        return const [
          _TemplateSpec('venue_daily_menu', 'Günün menüsü', 2, 'Ürün ve fiyat alanı'),
          _TemplateSpec('venue_campaign', 'Kampanya duyurusu', 1, 'İndirim ve son tarih'),
          _TemplateSpec('venue_new_product', 'Yeni ürün', 2, 'Ürün lansmanı'),
          _TemplateSpec('venue_review', 'Müşteri yorumu', 1, 'Sosyal kanıt kartı'),
          _TemplateSpec('venue_what_i_ate', 'Ne yedim?', 4, 'Lezzet kolajı'),
          _TemplateSpec('venue_vibe_favorite', 'Ortam + favorim', 4, 'Mekan deneyimi'),
          _TemplateSpec('venue_3_frames', '3 karede mekan', 3, 'Editoryal mekan özeti'),
          _TemplateSpec('venue_reservation', 'Rezervasyon çağrısı', 1, 'Saat ve iletişim alanı'),
        ];
      case 'spot':
        return const [
          _TemplateSpec('spot_weekend_route', 'Hafta sonu rotası', 3, 'Duraklı rota özeti'),
          _TemplateSpec('spot_city_24h', 'Şehirde 24 saat', 4, 'Günlük gezi akışı'),
          _TemplateSpec('spot_hidden_gem', 'Gizli kalmış yer', 2, 'Keşif ve konum'),
          _TemplateSpec('spot_sunset', 'Gün batımı noktası', 2, 'Saat ve çekim önerisi'),
          _TemplateSpec('spot_here_today', 'Bugün buradaydım', 2, 'Minimal gezi günlüğü'),
          _TemplateSpec('spot_route_4', '4 karede rota', 4, 'Haritalı rota özeti'),
          _TemplateSpec('spot_view_detail_tip', 'Manzara + detay + önerim', 3, 'Rehber düzeni'),
          _TemplateSpec('spot_before_after', 'Önce / sonra', 2, 'Karşılaştırmalı görünüm'),
        ];
      default:
        return const [
          _TemplateSpec('free_minimal', 'Minimal an', 1, 'Temiz tipografi'),
          _TemplateSpec('free_editorial', 'Editoryal hikâye', 2, 'Dergi görünümü'),
          _TemplateSpec('free_polaroid', 'Polaroid günlüğü', 3, 'Analog fotoğraf düzeni'),
          _TemplateSpec('free_day_4', '4 karede günüm', 4, 'Günlük kolaj'),
          _TemplateSpec('free_best_moment', 'Günün en iyi anı', 2, 'Büyük fotoğraf düzeni'),
          _TemplateSpec('free_week_recap', 'Haftanın özeti', 4, 'Haftalık özet'),
        ];
    }
  }
}

class _TemplatePreview extends StatelessWidget {
  final _TemplateSpec template;
  const _TemplatePreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final slotCount = template.slotCount;
    final rows = (slotCount / 2).ceil();
    final accent = _accent(template.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: .55), const Color(0xFF101218)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 25, 8, 22),
            child: Column(
              children: List.generate(
                rows,
                (row) => Expanded(
                  child: Row(
                    children: List.generate(2, (col) {
                      final index = row * 2 + col;
                      if (index >= slotCount) return const Expanded(child: SizedBox());
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(index == 0 ? 10 : 6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.image_outlined, size: 17, color: Colors.white38),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            top: 8,
            right: 9,
            child: Row(
              children: [
                Container(width: 22, height: 3, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9))),
                const SizedBox(width: 5),
                Expanded(child: Container(height: 3, color: Colors.white24)),
              ],
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 8,
            child: Text(
              template.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .7),
            ),
          ),
        ],
      ),
    );
  }

  Color _accent(String id) {
    if (id.startsWith('event_')) return const Color(0xFFFF8A65);
    if (id.startsWith('venue_')) return const Color(0xFFFFC857);
    if (id.startsWith('spot_')) return const Color(0xFF45D6C8);
    return const Color(0xFF9A7CFF);
  }
}

class _ContextItem {
  final String id;
  final String name;
  final String type;
  const _ContextItem({required this.id, required this.name, required this.type});
}

class _TemplateSpec {
  final String id;
  final String title;
  final int slotCount;
  final String subtitle;
  const _TemplateSpec(this.id, this.title, this.slotCount, this.subtitle);
}

class _TabSpec {
  final String label;
  final String type;
  final IconData icon;
  const _TabSpec(this.label, this.type, this.icon);

  String get collection {
    switch (type) {
      case 'event':
        return 'social_events';
      case 'venue':
        return 'business_venues';
      case 'spot':
        return 'photo_spots';
      default:
        return 'stories';
    }
  }
}
