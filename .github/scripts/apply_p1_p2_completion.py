from pathlib import Path
import subprocess


def need(text: str, old: str, label: str) -> None:
    if old not in text:
        raise SystemExit(f"Expected block not found: {label}")


# P1 #19 — real image/description metadata for venues.
path = Path("lib/models/nearby_venue.dart")
text = path.read_text()
if "final String imageUrl;" not in text:
    need(text, "  final String website;\n", "nearby venue fields")
    text = text.replace(
        "  final String website;\n",
        "  final String website;\n  final String imageUrl;\n  final String description;\n",
        1,
    )
    text = text.replace(
        "    this.website = '',\n  });",
        "    this.website = '',\n    this.imageUrl = '',\n    this.description = '',\n  });",
        1,
    )
    text = text.replace(
        "    'website': website,\n  };",
        "    'website': website,\n    'imageUrl': imageUrl,\n    'description': description,\n  };",
        1,
    )
    text = text.replace(
        "      website: (json['website'] ?? '').toString(),\n    );",
        "      website: (json['website'] ?? '').toString(),\n      imageUrl: (json['imageUrl'] ?? '').toString(),\n      description: (json['description'] ?? '').toString(),\n    );",
        1,
    )
path.write_text(text)

path = Path("lib/services/nearby_venue_service.dart")
text = path.read_text()
if "d['coverImageUrl']" not in text:
    old = """            website: (d['website'] ?? '').toString(),
          ),"""
    new = """            website: (d['website'] ?? '').toString(),
            imageUrl: (
              d['coverImageUrl'] ??
              d['imageUrl'] ??
              d['photoUrl'] ??
              d['logoUrl'] ??
              ''
            ).toString(),
            description: (
              d['shortDescription'] ?? d['description'] ?? ''
            ).toString(),
          ),"""
    need(text, old, "business venue constructor")
    text = text.replace(old, new, 1)
if "tags['description:tr']" not in text:
    old = """          website: (tags['contact:website'] ?? tags['website'] ?? '')
              .toString(),
        ),"""
    new = """          website: (tags['contact:website'] ?? tags['website'] ?? '')
              .toString(),
          imageUrl: (() {
            final value = (tags['image'] ?? '').toString().trim();
            return value.startsWith('https://') || value.startsWith('http://')
                ? value
                : '';
          })(),
          description: (
            tags['description:tr'] ?? tags['description'] ?? ''
          ).toString(),
        ),"""
    need(text, old, "OSM venue constructor")
    text = text.replace(old, new, 1)
path.write_text(text)

# P1 #19 + P2 #22 — richer cards, skeletons and one-tap city selection.
path = Path("lib/widgets/nearby_places_view.dart")
text = path.read_text()
if "../data/turkey_selection_data.dart" not in text:
    text = text.replace(
        "import '../models/nearby_venue.dart';\n",
        "import '../data/turkey_selection_data.dart';\nimport '../models/nearby_venue.dart';\n",
        1,
    )
if "searchable_selection_field.dart" not in text:
    text = text.replace(
        "import 'chat_share_sheet.dart';\n",
        "import 'chat_share_sheet.dart';\nimport 'searchable_selection_field.dart';\n",
        1,
    )
if "Listeden şehre dokunduğunda doğrudan açılır." not in text:
    old = """              TextField(
                controller: _cityController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchCity(sheetContext, setSheet),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_city_outlined),
                  hintText: 'Örn. Elazığ, İzmir, İstanbul',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _citySearching
                    ? null
                    : () => _searchCity(sheetContext, setSheet),
                icon: _citySearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _citySearching ? 'Şehir bulunuyor…' : 'Şehri Göster',
                ),
              ),"""
    new = """              SearchableSelectionField(
                controller: _cityController,
                options: turkeyCities,
                labelText: 'Şehir',
                hintText: 'Örn. Elazığ, İzmir, İstanbul',
                prefixIcon: Icons.location_city_outlined,
                enabled: !_citySearching,
                maxSuggestions: 7,
                onSelected: (_) => _searchCity(sheetContext, setSheet),
              ),
              const SizedBox(height: 8),
              Text(
                _citySearching
                    ? 'Şehir hazırlanıyor…'
                    : 'Listeden şehre dokunduğunda doğrudan açılır.',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),"""
    need(text, old, "city picker")
    text = text.replace(old, new, 1)
text = text.replace(
    "    if (_loading) return const Center(child: CircularProgressIndicator());",
    "    if (_loading) return const _VenueSkeletonList();",
    1,
)
if "venue.imageUrl.trim().isNotEmpty" not in text:
    old = """              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon, color: AppColors.cyan),
              ),"""
    new = """              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: venue.imageUrl.trim().isNotEmpty
                      ? Image.network(
                          venue.imageUrl.trim(),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _venuePlaceholder(),
                        )
                      : _venuePlaceholder(),
                ),
              ),"""
    need(text, old, "venue visual")
    text = text.replace(old, new, 1)
if "venue.category.label," not in text[text.find("Widget _venueCard"):]:
    old = """                      children: [
                        if (rating.count > 0)"""
    new = """                      children: [
                        Text(
                          venue.category.label,
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (rating.count > 0)"""
    need(text, old, "venue category metadata")
    text = text.replace(old, new, 1)
if "venue.description.trim().isNotEmpty" not in text:
    old = """                    if (venue.address.isNotEmpty) ...[
                      const SizedBox(height: 5),"""
    new = """                    if (venue.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        venue.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (venue.address.isNotEmpty) ...[
                      const SizedBox(height: 5),"""
    need(text, old, "venue description")
    text = text.replace(old, new, 1)
if "Widget _venuePlaceholder()" not in text:
    marker = "  IconData get _icon => switch (widget.category) {"
    helper = """  Widget _venuePlaceholder() => ColoredBox(
    color: AppColors.surfaceStrong,
    child: Center(child: Icon(_icon, color: AppColors.cyan, size: 28)),
  );

  IconData get _icon => switch (widget.category) {"""
    need(text, marker, "venue placeholder insertion")
    text = text.replace(marker, helper, 1)
if "class _VenueSkeletonList" not in text:
    marker = "class _SortChip extends StatelessWidget {"
    skeleton = """class _VenueSkeletonList extends StatelessWidget {
  const _VenueSkeletonList();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
    itemCount: 5,
    itemBuilder: (_, __) => Container(
      height: 102,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 13, width: 170, color: AppColors.surfaceStrong),
                const SizedBox(height: 10),
                Container(height: 10, width: 120, color: AppColors.surfaceStrong),
                const SizedBox(height: 8),
                Container(height: 10, width: 200, color: AppColors.surfaceStrong),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SortChip extends StatelessWidget {"""
    need(text, marker, "skeleton insertion")
    text = text.replace(marker, skeleton, 1)
path.write_text(text)

# P1 #20 — explicit Buradayım / Buluşalım entry using existing city-level demand and social event flows.
path = Path("lib/widgets/retention_now_overlay.dart")
text = path.read_text()
if "../screens/activity_demand_screen.dart" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\n\nimport '../screens/activity_demand_screen.dart';\nimport '../screens/event_create_screen_v2.dart';\n",
        1,
    )
text = text.replace("                      'Şu An',", "                      'Buradayım / Buluşalım',", 1)
text = text.replace("                            'Şu An',", "                            'Buradayım / Buluşalım',", 1)
text = text.replace(
    "                            'Çevrende ve TBT’de son hareketler',",
    "                            'Yakınındaki planlara katıl veya yeni bir plan başlat',",
    1,
)
if "child: _NowActions()" not in text:
    old = """              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>("""
    new = """              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _NowActions(),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>("""
    need(text, old, "Now actions slot")
    text = text.replace(old, new, 1)
if "class _NowActions" not in text:
    marker = "class _RadarBadge extends StatelessWidget {"
    actions = """class _NowActions extends StatelessWidget {
  const _NowActions();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ActivityDemandScreen(
                    initialActivity: 'Sosyal',
                  ),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded),
              label: const Text('Buradayım'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventCreateScreenV2(
                    initialTitle: 'Buluşalım',
                    initialDescription: 'Yakındaki insanlarla yeni bir plan.',
                  ),
                ),
              ),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Buluşalım'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Buradayım yalnızca seçtiğin şehir ve aktivite sinyalini paylaşır; kesin konum yayınlanmaz.',
        style: TextStyle(color: Colors.white46, fontSize: 10.5, height: 1.3),
      ),
    ],
  );
}

class _RadarBadge extends StatelessWidget {"""
    need(text, marker, "Now actions class")
    text = text.replace(marker, actions, 1)
path.write_text(text)

# P2 #22 — global search in the global header, not profile overflow.
path = Path("lib/screens/home_shell_v3.dart")
text = path.read_text()
if "tooltip: 'TBT’de Ara'" not in text:
    marker = """        StreamBuilder<int>(
          stream: AppNotificationService.instance.unreadCount(),"""
    action = """        _HeaderAction(
          tooltip: 'TBT’de Ara',
          icon: Icons.search_rounded,
          count: 0,
          onTap: () => Navigator.pushNamed(context, '/search'),
        ),
        StreamBuilder<int>(
          stream: AppNotificationService.instance.unreadCount(),"""
    need(text, marker, "global search header")
    text = text.replace(marker, action, 1)
path.write_text(text)

path = Path("lib/screens/profile_page_v2.dart")
text = path.read_text()
text = text.replace(
    """      case 'messages':
        if (mounted) Navigator.pushNamed(context, '/messages');
        return;
      case 'search':
        if (mounted) Navigator.pushNamed(context, '/search');
        return;
""",
    "",
    1,
)
text = text.replace(
    """                const PopupMenuItem(
                  value: 'messages',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.chat_bubble_outline_rounded),
                    title: Text('Mesajlar'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.search_rounded),
                    title: Text('TBT’de Ara'),
                  ),
                ),
""",
    "",
    1,
)
path.write_text(text)

# Camera/Iris guardrail.
changed = subprocess.check_output(["git", "diff", "--name-only"], text=True).splitlines()
forbidden_prefixes = (
    "lib/screens/camera_screen.dart",
    "lib/screens/main_camera_screen.dart",
    "lib/screens/ai_edit_screen.dart",
)
bad = [p for p in changed if p in forbidden_prefixes]
if bad:
    raise SystemExit(f"Camera/Iris guardrail violated: {bad}")

print("P1/P2 files changed:")
print("\n".join(changed))
