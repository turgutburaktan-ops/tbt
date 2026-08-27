from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old in text:
        p.write_text(text.replace(old, new, 1))


# Profile favorites: keep the feature, but make it feel like one compact module
# rather than three oversized dashboard rows.
p = Path('lib/widgets/profile_favorite_places_section.dart')
s = p.read_text()
s = s.replace("'Favori Mekanlar'", "'Favori Mekanlarım'", 1)
s = s.replace('width: 42,\n                            height: 42,', 'width: 36,\n                            height: 36,', 1)
s = s.replace('borderRadius: BorderRadius.circular(13),', 'borderRadius: BorderRadius.circular(11),', 1)
s = s.replace('const SizedBox(width: 12),', 'const SizedBox(width: 9),', 1)
s = s.replace('fontSize: 11.5,', 'fontSize: 10.5,', 1)
s = s.replace("name.isEmpty ? 'Favorini seç' : name", "name.isEmpty ? 'Seç' : name", 1)
p.write_text(s)


# Discover: avoid a bare spinner and give the user a polished loading state.
p = Path('lib/screens/home_discover_screen.dart')
s = p.read_text()
old = '''          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }'''
new = '''          if (!snapshot.hasData) {
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: .78,
              ),
              itemCount: 12,
              itemBuilder: (_, __) => const ColoredBox(
                color: Color(0xFF171A1F),
              ),
            );
          }'''
if old in s:
    s = s.replace(old, new, 1)
# Search wording is intentionally people-first because people results are ranked
# above content and this makes the mental model obvious to first-time users.
s = s.replace(
    "hintText: 'Kişi, mekan, etkinlik veya içerik ara...',",
    "hintText: 'Kişi, kullanıcı adı, mekan veya etkinlik ara...',",
    1,
)
p.write_text(s)


# Phone verification: make expired-session recovery explicit in the screen itself
# so the user does not keep retrying a dead code.
p = Path('lib/screens/phone_verification_screen.dart')
s = p.read_text()
s = s.replace(
    "'Kodun süresi doldu. Yeni bir SMS kodu iste.'",
    "'Kodun süresi doldu. Oturumu yeniledik; yeni bir SMS kodu iste.'",
    1,
)
s = s.replace(
    "'Doğrulama oturumu sona erdi. Yeni kod iste.'",
    "'Doğrulama oturumu sona erdi. Oturumu yeniledik; yeni kod iste.'",
    1,
)
p.write_text(s)


# Nearby venues: local city lookup is the fast path. Tighten remote fallback so a
# typo or weak network cannot leave city selection feeling frozen.
p = Path('lib/services/nearby_venue_service.dart')
s = p.read_text()
s = s.replace('.timeout(const Duration(seconds: 6));', '.timeout(const Duration(seconds: 4));', 1)
p.write_text(s)
