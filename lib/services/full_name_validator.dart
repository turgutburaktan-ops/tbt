/// Accept names across supported writing systems, including combining marks.
bool validFullName(String input) {
  final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  final parts = name.split(' ');
  return name.length >= 3 && name.length <= 80 && parts.length >= 2 &&
    parts.every((part) => RegExp(r"^[\p{L}][\p{L}\p{M}'’\-]*$", unicode: true).hasMatch(part));
}
