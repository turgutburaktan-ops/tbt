from pathlib import Path
import re


def must_replace(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch anchor: {label}')
    return text.replace(old, new, 1)

# 1) Phone verification: stale sessions should never leave the user stuck.
p = Path('lib/screens/phone_verification_screen.dart')
s = p.read_text()
s = must_replace(
    s,
    "    setState(() => _sending = true);\n    try {",
    """    setState(() => _sending = true);
    unawaited(Future<void>.delayed(const Duration(seconds: 25), () {
      if (!mounted || !_sending || _verificationId != null) return;
      setState(() => _sending = false);
      _message('SMS isteği beklenenden uzun sürdü. Tekrar deneyebilirsin.');
    }));
    try {""",
    'phone send watchdog',
)
s = must_replace(
    s,
    """        'session-expired' => 'Kodun süresi doldu. Yeni kod iste.',
        _ => _authError(error),
      });""",
    """        'session-expired' => 'Kodun süresi doldu. Yeni bir SMS kodu iste.',
        _ => _authError(error),
      });
      if (error.code == 'session-expired' && mounted) {
        _timer?.cancel();
        setState(() {
          _verificationId = null;
          _resendToken = null;
          _seconds = 0;
          _code.clear();
        });
      }""",
    'phone expired reset',
)
p.write_text(s)

# 2) City selection: resolve Turkish provinces locally before Nominatim.
p = Path('lib/services/nearby_venue_service.dart')
s = p.read_text()
known = """  static const _knownCities = <String, List<double>>{
    'Adana': [37.0000, 35.3213], 'Adıyaman': [37.7648, 38.2786],
    'Afyonkarahisar': [38.7507, 30.5567], 'Ağrı': [39.7191, 43.0503],
    'Aksaray': [38.3687, 34.0370], 'Amasya': [40.6499, 35.8353],
    'Ankara': [39.9334, 32.8597], 'Antalya': [36.8969, 30.7133],
    'Ardahan': [41.1105, 42.7022], 'Artvin': [41.1828, 41.8183],
    'Aydın': [37.8560, 27.8416], 'Balıkesir': [39.6484, 27.8826],
    'Bartın': [41.6344, 32.3375], 'Batman': [37.8812, 41.1351],
    'Bayburt': [40.2552, 40.2249], 'Bilecik': [40.1501, 29.9831],
    'Bingöl': [38.8853, 40.4983], 'Bitlis': [38.4006, 42.1095],
    'Bolu': [40.7395, 31.6116], 'Burdur': [37.7203, 30.2908],
    'Bursa': [40.1950, 29.0600], 'Çanakkale': [40.1553, 26.4142],
    'Çankırı': [40.6013, 33.6134], 'Çorum': [40.5506, 34.9556],
    'Denizli': [37.7765, 29.0864], 'Diyarbakır': [37.9144, 40.2306],
    'Düzce': [40.8438, 31.1565], 'Edirne': [41.6771, 26.5557],
    'Elazığ': [38.6743, 39.2232], 'Erzincan': [39.7500, 39.5000],
    'Erzurum': [39.9000, 41.2700], 'Eskişehir': [39.7767, 30.5206],
    'Gaziantep': [37.0662, 37.3833], 'Giresun': [40.9128, 38.3895],
    'Gümüşhane': [40.4386, 39.5086], 'Hakkari': [37.5744, 43.7408],
    'Hatay': [36.2023, 36.1600], 'Iğdır': [39.9201, 44.0436],
    'Isparta': [37.7648, 30.5566], 'İstanbul': [41.0082, 28.9784],
    'İzmir': [38.4237, 27.1428], 'Kahramanmaraş': [37.5753, 36.9228],
    'Karabük': [41.2061, 32.6204], 'Karaman': [37.1811, 33.2150],
    'Kars': [40.6013, 43.0975], 'Kastamonu': [41.3887, 33.7827],
    'Kayseri': [38.7205, 35.4826], 'Kırıkkale': [39.8468, 33.5153],
    'Kırklareli': [41.7351, 27.2252], 'Kırşehir': [39.1425, 34.1709],
    'Kilis': [36.7184, 37.1212], 'Kocaeli': [40.8533, 29.8815],
    'Konya': [37.8746, 32.4932], 'Kütahya': [39.4242, 29.9833],
    'Malatya': [38.3552, 38.3095], 'Manisa': [38.6191, 27.4289],
    'Mardin': [37.3212, 40.7245], 'Mersin': [36.8121, 34.6415],
    'Muğla': [37.2153, 28.3636], 'Muş': [38.9462, 41.7539],
    'Nevşehir': [38.6244, 34.7239], 'Niğde': [37.9698, 34.6766],
    'Ordu': [40.9862, 37.8797], 'Osmaniye': [37.0742, 36.2460],
    'Rize': [41.0201, 40.5234], 'Sakarya': [40.7569, 30.3781],
    'Samsun': [41.2867, 36.3300], 'Siirt': [37.9333, 41.9500],
    'Sinop': [42.0231, 35.1531], 'Sivas': [39.7477, 37.0179],
    'Şanlıurfa': [37.1674, 38.7955], 'Şırnak': [37.4187, 42.4918],
    'Tekirdağ': [40.9780, 27.5110], 'Tokat': [40.3167, 36.5500],
    'Trabzon': [41.0015, 39.7178], 'Tunceli': [39.1079, 39.5401],
    'Uşak': [38.6823, 29.4082], 'Van': [38.4891, 43.4089],
    'Yalova': [40.6500, 29.2667], 'Yozgat': [39.8181, 34.8147],
    'Zonguldak': [41.4564, 31.7987],
  };

  static String _normalizeCity(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');

  CityVenueArea? _findKnownCity(String value) {
    final q = _normalizeCity(value);
    if (q.length < 2) return null;
    MapEntry<String, List<double>>? match;
    for (final entry in _knownCities.entries) {
      final name = _normalizeCity(entry.key);
      if (name == q) {
        match = entry;
        break;
      }
      if (match == null && name.startsWith(q)) match = entry;
    }
    if (match == null) return null;
    final lat = match.value[0];
    final lon = match.value[1];
    return CityVenueArea(
      name: match.key,
      latitude: lat,
      longitude: lon,
      south: lat - 0.75,
      west: lon - 0.95,
      north: lat + 0.75,
      east: lon + 0.95,
    );
  }

"""
s = must_replace(
    s,
    "  static const _headers = <String, String>{\n    'User-Agent': 'TBT-mobile/0.1 (city places)',\n    'Accept': 'application/json',\n  };\n\n",
    "  static const _headers = <String, String>{\n    'User-Agent': 'TBT-mobile/0.1 (city places)',\n    'Accept': 'application/json',\n  };\n\n" + known,
    'known city catalog',
)
s = must_replace(
    s,
    """  Future<CityVenueArea?> findCity(String value) async {
    final query = value.trim();
    if (query.length < 2) return null;
    try {""",
    """  Future<CityVenueArea?> findCity(String value) async {
    final query = value.trim();
    if (query.length < 2) return null;
    final local = _findKnownCity(query);
    if (local != null) return local;
    try {""",
    'local city lookup',
)
p.write_text(s)

# 3) Favorite places: make the profile block compact horizontally.
p = Path('lib/widgets/profile_favorite_places_section.dart')
s = p.read_text()
start = s.find('              ..._types.map((type) {')
end = s.find('              }),\n            ],', start)
if start < 0 or end < 0:
    raise SystemExit('missing patch anchor: favorite cards')
end += len('              }),')
compact = r'''              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = _types[index];
                    final value = favorites[type.key];
                    final data = value is Map
                        ? Map<String, dynamic>.from(value)
                        : null;
                    if (!editable && data == null) {
                      return const SizedBox.shrink();
                    }
                    final name = (data?['name'] ?? '').toString().trim();
                    final subtitle = (data?['subtitle'] ?? '').toString().trim();
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: editable ? () => _pick(context, type) : null,
                      child: Container(
                        width: 154,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11141A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF292E38)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(type.icon, size: 20, color: const Color(0xFFB8A1FF)),
                                const Spacer(),
                                if (editable)
                                  const Icon(Icons.edit_rounded, size: 16, color: Colors.white38),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              type.label.replaceFirst('Favori ', ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name.isEmpty ? 'Seç' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: name.isEmpty ? Colors.white38 : Colors.white,
                              ),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),'''
s = s[:start] + compact + s[end:]
p.write_text(s)
