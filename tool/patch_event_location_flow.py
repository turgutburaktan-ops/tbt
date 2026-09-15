#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / 'lib/screens/social_events_screen.dart'
SERVICE = ROOT / 'lib/services/social_event_service.dart'
MODEL = ROOT / 'lib/models/social_event.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch anchor: {label}')
    return text.replace(old, new, 1)


# --- social events UI ---
text = SCREEN.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'event_tickets_screen.dart';\n",
    "import 'event_tickets_screen.dart';\nimport 'event_location_picker_screen.dart';\n",
    'event picker import',
)
text = replace_once(
    text,
    "    int capacity = 10;\n    bool saving = false;",
    "    int capacity = 10;\n    EventLocationSelection? selectedLocation;\n    bool citySuggestionSelected = false;\n    bool saving = false;",
    'location state',
)
text = replace_once(
    text,
    "          void setCapacity(int value) {\n            final safe = value.clamp(2, 100);\n            setSheetState(() {\n              capacity = safe;\n              formError = null;\n            });\n            capacityController.value = TextEditingValue(\n              text: '$safe',\n              selection: TextSelection.collapsed(offset: '$safe'.length),\n            );\n          }\n",
    "          void setCapacity(int value) {\n            final safe = value < 1 ? 1 : value;\n            setSheetState(() {\n              capacity = safe;\n              formError = null;\n            });\n            capacityController.value = TextEditingValue(\n              text: '$safe',\n              selection: TextSelection.collapsed(offset: '$safe'.length),\n            );\n          }\n\n          Future<void> chooseEventLocation() async {\n            final result = await Navigator.push<EventLocationSelection>(\n              context,\n              MaterialPageRoute(\n                builder: (_) => EventLocationPickerScreen(\n                  city: cityController.text,\n                  addressLabel: locationController.text,\n                  initialLatitude: selectedLocation?.latitude,\n                  initialLongitude: selectedLocation?.longitude,\n                ),\n              ),\n            );\n            if (result == null || !context.mounted) return;\n            setSheetState(() {\n              selectedLocation = result;\n              formError = null;\n              if (locationController.text.trim().isEmpty) {\n                locationController.text = result.label;\n              }\n            });\n          }\n",
    'capacity and map picker',
)
text = replace_once(
    text,
    "                  TextField(\n                    controller: cityController,\n                    decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined)),\n                  ),\n                  const SizedBox(height: 12),\n                  TextField(\n                    controller: locationController,\n                    decoration: const InputDecoration(labelText: 'Etkinlik / buluşma konumu', prefixIcon: Icon(Icons.place_outlined)),\n                  ),",
    "                  TextField(\n                    controller: cityController,\n                    decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined)),\n                    onChanged: (_) => setSheetState(() => citySuggestionSelected = false),\n                  ),\n                  if (cityController.text.trim().length >= 2) ...[\n                    const SizedBox(height: 6),\n                    InkWell(\n                      borderRadius: BorderRadius.circular(14),\n                      onTap: () {\n                        setSheetState(() => citySuggestionSelected = true);\n                        FocusScope.of(context).unfocus();\n                      },\n                      child: Container(\n                        width: double.infinity,\n                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),\n                        decoration: BoxDecoration(\n                          color: citySuggestionSelected ? const Color(0x3322D3EE) : const Color(0xFF141126),\n                          borderRadius: BorderRadius.circular(14),\n                          border: Border.all(color: citySuggestionSelected ? const Color(0xFF22D3EE) : const Color(0xFF352A55)),\n                        ),\n                        child: Row(children: [\n                          Icon(citySuggestionSelected ? Icons.check_circle : Icons.location_on_outlined, color: const Color(0xFFA78BFA)),\n                          const SizedBox(width: 9),\n                          Text('${cityController.text.trim()}, Türkiye', style: const TextStyle(fontWeight: FontWeight.w700)),\n                        ]),\n                      ),\n                    ),\n                  ],\n                  const SizedBox(height: 12),\n                  TextField(\n                    controller: locationController,\n                    decoration: const InputDecoration(\n                      labelText: 'Etkinlik / buluşma adresi',\n                      hintText: 'Mekân, mahalle, cadde veya açık adres',\n                      prefixIcon: Icon(Icons.place_outlined),\n                    ),\n                  ),\n                  const SizedBox(height: 8),\n                  SizedBox(\n                    width: double.infinity,\n                    child: OutlinedButton.icon(\n                      onPressed: chooseEventLocation,\n                      icon: Icon(selectedLocation == null ? Icons.map_outlined : Icons.location_on),\n                      label: Text(selectedLocation == null ? 'Haritadan kesin konumu seç' : 'Harita konumu seçildi • Değiştir'),\n                    ),\n                  ),\n                  if (selectedLocation != null)\n                    Padding(\n                      padding: const EdgeInsets.only(top: 6),\n                      child: Text(\n                        '${selectedLocation!.latitude.toStringAsFixed(5)}, ${selectedLocation!.longitude.toStringAsFixed(5)}',\n                        style: const TextStyle(color: Colors.white54, fontSize: 12),\n                      ),\n                    ),",
    'city and address UI',
)
text = text.replace("onPressed: capacity > 2 ? () => setCapacity(capacity - 1) : null,", "onPressed: capacity > 1 ? () => setCapacity(capacity - 1) : null,")
text = text.replace("capacity = parsed.clamp(2, 100);", "capacity = parsed < 1 ? 1 : parsed;")
text = text.replace("onPressed: capacity < 100 ? () => setCapacity(capacity + 1) : null,", "onPressed: () => setCapacity(capacity + 1),")
text = text.replace("'2 ile 100 arasında sayı yazabilir veya + / - kullanabilirsin.'", "'İstediğin katılımcı sayısını yazabilir veya + / - kullanabilirsin.'")
text = replace_once(
    text,
    "                              if (typedCapacity == null || typedCapacity < 2 || typedCapacity > 100) {\n                                setSheetState(() => formError = 'Katılımcı sayısı 2 ile 100 arasında olmalı.');\n                                return;\n                              }",
    "                              if (typedCapacity == null || typedCapacity < 1) {\n                                setSheetState(() => formError = 'Katılımcı sayısı en az 1 olmalı.');\n                                return;\n                              }\n                              if (selectedLocation == null) {\n                                setSheetState(() => formError = 'Etkinliğin haritadaki kesin konumunu seç.');\n                                return;\n                              }",
    'save validation',
)
text = replace_once(
    text,
    "                                  ticketPriceMinor: (price * 100).round(),\n                                );",
    "                                  ticketPriceMinor: (price * 100).round(),\n                                  latitude: selectedLocation!.latitude,\n                                  longitude: selectedLocation!.longitude,\n                                );",
    'create coordinates',
)
SCREEN.write_text(text, encoding='utf-8')

# --- service: persist exact coordinates and do not cap capacity ---
text = SERVICE.read_text(encoding='utf-8')
text = replace_once(
    text,
    "    DateTime? ticketSalesEndAt,\n  }) async {",
    "    DateTime? ticketSalesEndAt,\n    double? latitude,\n    double? longitude,\n  }) async {",
    'service args',
)
text = text.replace("'capacity': capacity.clamp(2, 100),", "'capacity': capacity < 1 ? 1 : capacity,")
text = replace_once(
    text,
    "      'spotName': spot?.name,\n      'status': 'open',\n      'approximateLocationOnly': true,",
    "      'spotName': spot?.name,\n      'latitude': latitude ?? spot?.latitude,\n      'longitude': longitude ?? spot?.longitude,\n      'location': latitude != null && longitude != null\n          ? GeoPoint(latitude, longitude)\n          : (spot == null ? null : GeoPoint(spot.latitude, spot.longitude)),\n      'status': 'open',\n      'approximateLocationOnly': false,",
    'coordinate persistence',
)
text = text.replace("final capacity = ((data['capacity'] as num?)?.toInt() ?? 2).clamp(2, 100);", "final capacity = ((data['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647);")
SERVICE.write_text(text, encoding='utf-8')

# --- model: preserve large capacities ---
text = MODEL.read_text(encoding='utf-8')
text = text.replace("capacity: ((data['capacity'] as num?)?.toInt() ?? 2).clamp(2, 100),", "capacity: ((data['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647),")
MODEL.write_text(text, encoding='utf-8')

print('Event city suggestion + exact map picker + unlimited capacity patch applied')
