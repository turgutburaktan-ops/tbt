from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str, marker: str | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    if marker and marker in text:
        return
    if old not in text:
        raise SystemExit(f'Missing patch target: {label}')
    p.write_text(text.replace(old, new, 1))


# 1) Map lifecycle: never talk to a stale GoogleMap platform view after a route
# is closing. This addresses the runtime framework _dependents assertion seen in
# the screen recording when changing location / leaving the map.
p = Path('lib/screens/map_screen.dart')
s = p.read_text()

if 'bool _mapDisposed = false;' not in s:
    s = s.replace(
        '  GoogleMapController? _mapController;\n',
        '  GoogleMapController? _mapController;\n'
        '  bool _mapDisposed = false;\n'
        '  double _mapZoom = 5;\n',
        1,
    )

if 'Future<void> _animateMap(CameraUpdate update)' not in s:
    target = '''  @override
  void initState() {
    super.initState();
    _loadSpots();
    _prepareLocation();
  }
'''
    replacement = target + '''
  @override
  void dispose() {
    _mapDisposed = true;
    // The GoogleMap widget owns the underlying platform view disposal. Drop our
    // reference immediately so late async route/location callbacks cannot use it.
    _mapController = null;
    super.dispose();
  }

  Future<void> _animateMap(CameraUpdate update) async {
    if (!mounted || _mapDisposed) return;
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(update);
    } catch (_) {
      // Platform view may already be tearing down while a route is popped.
      if (identical(_mapController, controller)) _mapController = null;
    }
  }
'''
    if target not in s:
        raise SystemExit('Missing patch target: map initState')
    s = s.replace(target, replacement, 1)

# At national zoom, rendering 1,000+ individual platform-map markers is both
# noisy and expensive. Progressively reveal more points as the user zooms in.
if 'final visibleSpots = _mapZoom < 7' not in s:
    target = '''    if (_filter == _MapContentFilter.all ||
        _filter == _MapContentFilter.spots) {
      for (final spot in _spots) {'''
    replacement = '''    if (_filter == _MapContentFilter.all ||
        _filter == _MapContentFilter.spots) {
      final visibleSpots = _mapZoom < 7
          ? _spots.take(140)
          : _mapZoom < 9
          ? _spots.take(360)
          : _spots;
      for (final spot in visibleSpots) {'''
    if target not in s:
        raise SystemExit('Missing patch target: map marker density')
    s = s.replace(target, replacement, 1)

# Keep nearby venue markers useful rather than rendering hundreds at once.
s = s.replace('      return venues.take(120).toList(growable: false);',
              '      return venues.take(40).toList(growable: false);', 1)

# All camera changes go through the lifecycle-safe wrapper.
s = s.replace('''      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );''', '''      await _animateMap(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );''', 1)

if 'if (!mounted || _mapDisposed) return;\n    setState(() {' not in s:
    s = s.replace('''  }) async {
    setState(() {
      _selectedSpot = spot;''', '''  }) async {
    if (!mounted || _mapDisposed) return;
    setState(() {
      _selectedSpot = spot;''', 1)

s = s.replace('''    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(destination, 15),
    );''', '''    await _animateMap(
      CameraUpdate.newLatLngZoom(destination, 15),
    );''', 1)
s = s.replace('''      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 54),
      );''', '''      await _animateMap(
        CameraUpdate.newLatLngBounds(bounds, 54),
      );''', 1)
s = s.replace('''  void _showAll() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_defaultLocation, 5),
    );
    _clearSelection();
  }''', '''  void _showAll() {
    _animateMap(CameraUpdate.newLatLngZoom(_defaultLocation, 5));
    _clearSelection();
  }''', 1)

if 'void _clearSelection() {\n    if (!mounted || _mapDisposed) return;' not in s:
    s = s.replace('''  void _clearSelection() {
    setState(() {''', '''  void _clearSelection() {
    if (!mounted || _mapDisposed) return;
    setState(() {''', 1)

old_created = '''                    onMapCreated: (controller) async {
                      _mapController = controller;
                      final position = _currentPosition;
                      if (position != null) {
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(position.latitude, position.longitude),
                            15,
                          ),
                        );
                      }
                    },'''
new_created = '''                    onMapCreated: (controller) async {
                      if (!mounted || _mapDisposed) return;
                      _mapController = controller;
                      final position = _currentPosition;
                      if (position != null) {
                        await _animateMap(
                          CameraUpdate.newLatLngZoom(
                            LatLng(position.latitude, position.longitude),
                            15,
                          ),
                        );
                      }
                    },
                    onCameraMove: (position) {
                      if (!mounted || _mapDisposed) return;
                      if ((position.zoom - _mapZoom).abs() >= .75) {
                        setState(() => _mapZoom = position.zoom);
                      }
                    },'''
if 'onCameraMove: (position)' not in s:
    if old_created not in s:
        raise SystemExit('Missing patch target: map onMapCreated')
    s = s.replace(old_created, new_created, 1)

p.write_text(s)


# 2) Google sign-in: a native certificate/configuration failure must not fall
# through into Firebase's browser provider. The browser fallback was turning a
# simple Android config error into a broken external-web flow in production.
p = Path('lib/services/auth_service.dart')
s = p.read_text()
old_google = '''      } catch (e) {
        debugPrint(
          'Native Google sign-in failed, trying Firebase provider: $e',
        );
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        final result = await _auth.signInWithProvider(GoogleAuthProvider());
        await _ensureSocialProfile(result.user, provider: 'google');
        return result;
      }'''
new_google = '''      } catch (e) {
        debugPrint('Native Google sign-in failed: $e');
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        rethrow;
      }'''
if 'trying Firebase provider' in s:
    if old_google not in s:
        raise SystemExit('Missing patch target: Google browser fallback')
    s = s.replace(old_google, new_google, 1)
p.write_text(s)


# 3) Favorites: replace the indefinite centered spinner with a useful loading
# state, and compact the cards so favorites do not dominate the profile.
p = Path('lib/widgets/profile_favorite_places_section.dart')
s = p.read_text()
s = s.replace('padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),',
              'padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),', 1)
s = s.replace('const SizedBox(height: 10),\n              ..._types.map',
              'const SizedBox(height: 7),\n              ..._types.map', 1)
s = s.replace('padding: const EdgeInsets.only(bottom: 8),',
              'padding: const EdgeInsets.only(bottom: 5),', 1)
s = s.replace('padding: const EdgeInsets.all(13),',
              'padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),', 1)
s = s.replace('''                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());''', '''                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Yakındaki mekanlar hazırlanıyor…',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }''', 1)
p.write_text(s)

# Phone verification is additionally hardened directly in its screen. Keep this
# hook for older branches where the previous generic wording still exists.
p = Path('lib/screens/phone_verification_screen.dart')
if p.exists():
    s = p.read_text()
    s = s.replace(
        "'Telefon doğrulaması başlatılamadı. Lütfen tekrar deneyin.'",
        "'SMS gönderilemedi. Uygulama güvenlik doğrulaması tamamlanamadı; uygulamayı güncelleyip tekrar deneyin.'",
    )
    p.write_text(s)

# Apply lower-risk loading/layout polish collected from the same QA recording.
polish = Path('.github/scripts/apply_video_qa_polish.py')
if polish.exists():
    exec(compile(polish.read_text(), str(polish), 'exec'))
