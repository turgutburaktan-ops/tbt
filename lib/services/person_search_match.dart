String normalizeSearchText(Object? value) => (value ?? '')
    .toString()
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('i\u0307', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

int personMatchScore(Map<String, dynamic> data, String query) {
  final q = normalizeSearchText(query.replaceFirst(RegExp(r'^@'), ''));
  if (q.isEmpty) return 0;
  final name = normalizeSearchText(data['displayName'] ?? data['name']);
  final username = normalizeSearchText(data['username'] ?? data['userName'])
      .replaceFirst(RegExp(r'^@'), '');
  final combined = '$name $username';
  final tokens = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (name == q) return 120;
  if (username == q) return 115;
  if (name.startsWith(q)) return 105;
  if (username.startsWith(q)) return 100;
  if (tokens.isNotEmpty && tokens.every(combined.contains)) return 85;
  if (name.contains(q)) return 75;
  if (username.contains(q)) return 70;
  return 0;
}
