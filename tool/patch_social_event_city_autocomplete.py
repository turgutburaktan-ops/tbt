from pathlib import Path

path = Path('lib/screens/social_events_screen.dart')
text = path.read_text(encoding='utf-8')

if "../data/turkey_selection_data.dart" not in text:
    text = text.replace(
        "import '../models/event_ticket.dart';\n",
        "import '../data/turkey_selection_data.dart';\nimport '../models/event_ticket.dart';\n",
        1,
    )

if "../widgets/searchable_selection_field.dart" not in text:
    text = text.replace(
        "import '../widgets/content_engagement_bar.dart';\n",
        "import '../widgets/content_engagement_bar.dart';\nimport '../widgets/searchable_selection_field.dart';\n",
        1,
    )

old = "TextField(controller: cityController, decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined))),"
new = """SearchableSelectionField(
                  controller: cityController,
                  options: turkeyCities,
                  labelText: 'Şehir',
                  hintText: 'Yazmaya başla ve seç',
                  prefixIcon: Icons.location_city_outlined,
                ),"""

if old in text:
    text = text.replace(old, new, 1)
elif 'options: turkeyCities' not in text:
    raise SystemExit('social event city field anchor not found')

path.write_text(text, encoding='utf-8')
print('Social event city autocomplete applied')
