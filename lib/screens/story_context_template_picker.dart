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
          if (spec.type != 'free')
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
  final void Function(_ContextItem, _TemplateSpec) onTemplateSelected;

  const _ContextBrowser({
    required this.spec,
    required this.query,
    required this.selected,
    required this.onContextSelected,
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
                  onPressed: () => onContextSelected(
                    const _ContextItem(id: '', name: '', type: ''),
                  ),
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
                    child: _TemplatePreview(slotCount: template.slotCount),
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
                    '${template.slotCount} fotoğraf',
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
          _TemplateSpec('event_4_moments', 'Etkinlikten 4 an', 4),
          _TemplateSpec('event_stage_vibe', 'Sahne + ortam + ekip', 4),
          _TemplateSpec('event_night_recap', 'Gecenin özeti', 4),
        ];
      case 'venue':
        return const [
          _TemplateSpec('venue_what_i_ate', 'Ne yedim?', 4),
          _TemplateSpec('venue_vibe_favorite', 'Ortam + favorim', 4),
          _TemplateSpec('venue_3_frames', '3 karede mekan', 3),
        ];
      case 'spot':
        return const [
          _TemplateSpec('spot_here_today', 'Bugün buradaydım', 2),
          _TemplateSpec('spot_route_4', '4 karede rota', 4),
          _TemplateSpec('spot_view_detail_tip', 'Manzara + detay + önerim', 3),
        ];
      default:
        return const [
          _TemplateSpec('free_day_4', '4 karede günüm', 4),
          _TemplateSpec('free_best_moment', 'Günün en iyi anı', 2),
          _TemplateSpec('free_week_recap', 'Haftanın özeti', 4),
        ];
    }
  }
}

class _TemplatePreview extends StatelessWidget {
  final int slotCount;
  const _TemplatePreview({required this.slotCount});

  @override
  Widget build(BuildContext context) {
    final rows = (slotCount / 2).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: List.generate(
          rows,
          (row) => Expanded(
            child: Row(
              children: List.generate(2, (col) {
                final index = row * 2 + col;
                if (index >= slotCount) {
                  return const Expanded(child: SizedBox());
                }
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    color: Colors.white12,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: Colors.white38,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
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
  const _TemplateSpec(this.id, this.title, this.slotCount);
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
