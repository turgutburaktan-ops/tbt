import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nearby_venue.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nearby_places_view.dart';
import '../widgets/story_strip.dart';
import 'campus_home_screen.dart';
import 'event_photo_create_screen.dart';
import 'feed_screen.dart';
import 'home_discover_screen.dart';
import 'login_screen.dart';
import 'main_camera_screen.dart';
import 'map_screen.dart';
import 'profile_page_v2.dart';
import 'radar_screen.dart';
import 'spot_explore_screen_v2.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressedAt;

  Future<void> _selectDestination(int index) async {
    if (index == 2) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MainCameraScreen()));
      return;
    }
    if (mounted) setState(() => _selectedIndex = index);
  }

  void _handleBack(bool keyboardOpen) {
    if (keyboardOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    final now = DateTime.now();
    final recent = _lastBackPressedAt != null && now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    if (recent) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Uygulamadan çıkmak için geri tuşuna tekrar bas.')));
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      _HomeFeedHub(),
      _PlacesHub(),
      SizedBox.shrink(),
      _NearbyUnifiedHub(),
      _ProfileGate(),
    ];
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack(keyboardOpen);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _selectedIndex, children: pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: keyboardOpen
            ? null
            : Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
                child: FloatingActionButton(
                  heroTag: 'main-camera-v3',
                  tooltip: 'Kamera',
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: () => _selectDestination(2),
                  child: const Icon(Icons.photo_camera_rounded, size: 25),
                ),
              ),
        bottomNavigationBar: keyboardOpen ? null : _BottomNav(selectedIndex: _selectedIndex, onSelected: _selectDestination),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _BottomNav({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
      (Icons.place_outlined, Icons.place_rounded, 'Mekanlar'),
      (Icons.circle_outlined, Icons.circle, 'Kamera'),
      (Icons.near_me_outlined, Icons.near_me_rounded, 'Çevrende'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    return SafeArea(
      top: false,
      child: BottomAppBar(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        color: AppColors.navigation,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        child: Row(
          children: List.generate(items.length, (index) {
            if (index == 2) {
              return const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text('Kamera', style: TextStyle(color: Color(0x75FFFFFF), fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              );
            }
            final item = items[index];
            final selected = selectedIndex == index;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GradientIcon(icon: selected ? item.$2 : item.$1, active: selected, size: 21),
                      const SizedBox(height: 2),
                      Text(item.$3, maxLines: 1, style: TextStyle(color: selected ? Colors.white : const Color(0x75FFFFFF), fontSize: 9.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _HomeFeedHub extends StatefulWidget {
  const _HomeFeedHub();
  @override
  State<_HomeFeedHub> createState() => _HomeFeedHubState();
}

class _HomeFeedHubState extends State<_HomeFeedHub> {
  int _section = 0;
  int _photoMode = 0;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _HomeHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 7),
                child: _SegmentTabs(
                  labels: const ['Ana Sayfa', 'Keşfet'],
                  selected: _section,
                  prominent: true,
                  onChanged: (value) => setState(() => _section = value),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _section,
                  children: [
                    Column(
                      children: [
                        const StoryStrip(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 3, 14, 5),
                          child: _SegmentTabs(
                            labels: const ['Sana Özel', 'Takip'],
                            selected: _photoMode,
                            onChanged: (value) => setState(() => _photoMode = value),
                          ),
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _photoMode,
                            children: const [
                              _AuthAwareFeed(mode: FeedMode.forYou),
                              _AuthAwareFeed(mode: FeedMode.following),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const HomeDiscoverScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _AuthAwareFeed extends StatelessWidget {
  final FeedMode mode;
  const _AuthAwareFeed({required this.mode});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (_, snapshot) => FeedScreen(
          key: ValueKey('${mode.name}-${snapshot.data?.uid ?? 'guest'}'),
          mode: mode,
          embedded: true,
          includeEvents: false,
        ),
      );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 5),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: AppColors.accentGradient),
              child: const Text('TBT', style: TextStyle(color: Color(0xFF08090D), fontSize: 10.5, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            const Expanded(child: Text('TBT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.35))),
            StreamBuilder<int>(
              stream: AppNotificationService.instance.unreadCount(),
              builder: (_, s) => _HeaderAction(tooltip: 'Bildirimler', icon: Icons.notifications_none_rounded, count: s.data ?? 0, onTap: () => Navigator.pushNamed(context, '/notifications')),
            ),
            StreamBuilder<int>(
              stream: AppNotificationService.instance.unreadMessageCount(),
              builder: (_, s) => _HeaderAction(tooltip: 'Mesajlar', icon: Icons.chat_bubble_outline_rounded, count: s.data ?? 0, onTap: () => Navigator.pushNamed(context, '/messages')),
            ),
          ],
        ),
      );
}

class _PlacesHub extends StatefulWidget {
  const _PlacesHub();
  @override
  State<_PlacesHub> createState() => _PlacesHubState();
}

class _PlacesHubState extends State<_PlacesHub> {
  String _category = 'Gezilecek Yerler';

  void _openMap() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Gezilecek Yerler Haritası')),
            body: const MapScreen(),
          ),
        ),
      );

  NearbyVenueCategory _nearbyCategory() {
    if (_category == 'Kafeler') return NearbyVenueCategory.cafe;
    if (_category == 'Oteller') return NearbyVenueCategory.hotel;
    return NearbyVenueCategory.dining;
  }

  @override
  Widget build(BuildContext context) {
    const categories = <(IconData, String)>[
      (Icons.landscape_outlined, 'Gezilecek Yerler'),
      (Icons.restaurant_outlined, 'Yeme-İçme'),
      (Icons.local_cafe_outlined, 'Kafeler'),
      (Icons.hotel_outlined, 'Oteller'),
    ];

    final Widget content;
    if (_category == 'Gezilecek Yerler') {
      content = const SpotExploreScreen(embedded: true);
    } else {
      content = NearbyPlacesView(
        key: ValueKey(_category),
        category: _nearbyCategory(),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mekanlar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.4)),
                  ),
                  if (_category == 'Gezilecek Yerler')
                    OutlinedButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Harita'),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text('Yeme-içme, kahve, konaklama ve gezilecek yerler.', style: TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: categories
                    .map(
                      (item) => ChoiceChip(
                        avatar: Icon(item.$1, size: 16),
                        label: Text(item.$2),
                        selected: _category == item.$2,
                        onSelected: (_) => setState(() => _category = item.$2),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _NearbyUnifiedHub extends StatefulWidget {
  const _NearbyUnifiedHub();
  @override
  State<_NearbyUnifiedHub> createState() => _NearbyUnifiedHubState();
}

class _NearbyUnifiedHubState extends State<_NearbyUnifiedHub> {
  int _section = 0;

  bool _campusEligible(Map<String, dynamic> data) {
    const years = {'Hazırlık', '1', '2', '3', '4', '5', '6'};
    final university = (data['university'] ?? '').toString().trim();
    final classYear = (data['classYear'] ?? '').toString().trim();
    return university.isNotEmpty && years.contains(classYear);
  }

  Future<void> _createEvent() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik oluşturmak için giriş yapmalısın.')));
      return;
    }
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EventPhotoCreateScreen()));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (_, auth) {
          final user = auth.data;
          if (user == null) return _buildHub(false);
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (_, profile) => _buildHub(_campusEligible(profile.data?.data() ?? const {})),
          );
        },
      );

  Widget _buildHub(bool campusEligible) {
    final labels = campusEligible ? const ['Çevrende', 'Kampüs'] : const ['Çevrende'];
    final index = _section >= labels.length ? 0 : _section;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
              child: Column(
                children: [
                  const Row(
                    children: [
                      _GradientIcon(icon: Icons.near_me_rounded, size: 23),
                      SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Çevrende', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                            Text('Yakındaki planlar ve etkinlikler tek akışta.', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _createEvent,
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      label: const Text('Etkinlik oluştur', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
            if (campusEligible)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
                child: _SegmentTabs(labels: labels, selected: index, onChanged: (v) => setState(() => _section = v)),
              ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  const RadarScreen(embedded: true),
                  if (campusEligible) const CampusHomeScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const SafeArea(child: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == null ? const LoginScreen(embedded: true) : const ProfilePage();
        },
      );
}

class _SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool prominent;
  const _SegmentTabs({required this.labels, required this.selected, required this.onChanged, this.prominent = false});

  @override
  Widget build(BuildContext context) => Container(
        height: prominent ? 36 : 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          children: List.generate(labels.length, (index) {
            final active = selected == index;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: active ? AppColors.surfaceStrong : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white.withValues(alpha: .48),
                      fontSize: prominent ? 12 : 10.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  const _HeaderAction({required this.tooltip, required this.icon, required this.onTap, this.count = 0});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: AppColors.violet,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      );
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final double size;
  const _GradientIcon({required this.icon, this.active = true, this.size = 22});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: active ? const [AppColors.cyan, AppColors.violet] : const [Color(0x75FFFFFF), Color(0x75FFFFFF)],
        ).createShader(bounds),
        child: Icon(icon, size: size),
      );
}
