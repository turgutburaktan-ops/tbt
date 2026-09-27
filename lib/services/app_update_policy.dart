/// Invalid/unpublished versions never force users into an update loop.
int? compareAppVersions(String a, String b) {
  List<int>? parse(String v) {
    if (!RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(v)) return null;
    final parts = v.split('.').map(int.tryParse).toList();
    return parts.any((v) => v == null) ? null : parts.cast<int>();
  }
  final x = parse(a), y = parse(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < 4; i++) {
    final d = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

bool requiresAndroidUpdate(int installed, int available, int minimum) =>
    installed < minimum && available >= minimum && available > installed;

bool requiresIosUpdate(String installed, String available, String minimum) =>
    compareAppVersions(installed, minimum) == -1 &&
    (compareAppVersions(available, minimum) ?? -1) >= 0 &&
    compareAppVersions(available, installed) == 1;
