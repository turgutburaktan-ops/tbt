import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nearby_venue.dart';
import '../services/app_notification_service.dart';
import '../services/nearby_venue_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nearby_places_view.dart';
import '../widgets/story_strip.dart';
import '../widgets/tbt_brand_mark.dart';
import 'campus_home_screen.dart';
import 'chat_inbox_screen.dart';
import 'collaborative_plans_screen.dart';
import 'event_create_screen_v2.dart';
import 'event_photo_create_screen.dart';
import 'feed_screen.dart';
import 'home_discover_screen.dart';
import 'login_screen.dart';
import 'main_camera_screen.dart';
import 'map_screen.dart';
import 'profile_page_v2.dart';
import 'public_travel_plans_screen.dart';
import 'radar_screen.dart';
import 'route_planner_screen.dart';
import 'smart_plan_screen.dart';
import 'spot_explore_screen_v2.dart';
import 'travel_plans_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressedAt;
  final Set<int> _loadedTabs = <int>{0};

  Widget _tabPage(int index) {
    if (!_loadedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const _HomeFeedHub(),
      1 => const _PlacesHub(),
      2 => _PlanningHub(onOpenNearby: () => _selectDestination(3)),
      3 => const _NearbyUnifiedHub(),
      4 => const _ProfileGate(),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _selectDestination(int index) async {
    if (!mounted || index == _selectedIndex) return;
    setState(() {
      _loadedTabs.add(index);
      _selectedIndex = index;
    });
  }

  void _handleBack(bool keyboardOpen) {
    if (keyboardOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_selectedIndex != 0) {
      setState(() {
        _loadedTabs.add(0);
        _selectedIndex = 0;
      });
      return;
    }
    final now = DateTime.now();
    final recent =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    if (recent) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Uygulamadan çıkmak için geri tuşuna tekrar bas.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(5, _tabPage, growable: false);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack(keyboardOpen);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: keyboardOpen
            ? null
            : _BottomNav(
                selectedIndex: _selectedIndex,
                onSelected: _selectDestination,
              ),
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
      (Icons.explore_outlined, Icons.explore_rounded, 'Planla'),
      (Icons.near_me_outlined, Icons.near_me_rounded, 'Çevrende'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    return SafeArea(
      top: false,
      child: BottomAppBar(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        color: AppColors.navigation,
        elevation: 0,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = selectedIndex == index;
            final isPlanning = index == 2;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isPlanning ? 34 : 26,
                        height: isPlanning ? 27 : 23,
                        decoration: isPlanning
                            ? BoxDecoration(
                                gradient: selected
                                    ? AppColors.accentGradientHorizontal
                                    : null,
                                color: selected ? null : AppColors.surfaceStrong,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : AppColors.borderStrong,
                                ),
                              )
                            : null,
                        alignment: Alignment.center,
                        child: isPlanning && selected
                            ? Icon(item.$2, color: Colors.white, size: 20)
                            : _GradientIcon(
                                icon: selected ? item.$2 : item.$1,
                                active: selected,
                                size: 21,
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0x75FFFFFF),
                          fontSize: 9.5,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
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
  static const double _chromeCollapseExtent = 132;

  int _section = 0;
  int _photoMode = 0;
  final Set<int> _loadedSections = <int>{0};
  final Set<int> _loadedPhotoModes = <int>{0};
  final ValueNotifier<double> _chromeCollapse = ValueNotifier<double>(0);
  Offset? _swipeStart;
  bool _openingCamera = false;

  @override
  void dispose() {
    _chromeCollapse.dispose();
    super.dispose();
  }

  void _setSection(int value) {
    if (value == _section) return;
    _chromeCollapse.value = 0;
    setState(() {
      _loadedSections.add(value);
      _section = value;
    });
  }

  void _setPhotoMode(int value) {
    if (value == _photoMode) return;
    setState(() {
      _loadedPhotoModes.add(value);
      _photoMode = value;
    });
  }

  bool _handleFeedScroll(ScrollNotification notification) {
    if (_section != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final next = notification.metrics.pixels
        .clamp(0.0, _chromeCollapseExtent)
        .toDouble();
    if ((next - _chromeCollapse.value).abs() > .35) {
      _chromeCollapse.value = next;
    }
    return false;
  }

  void _rememberSwipeStart(PointerDownEvent event) {
    if (event.localPosition.dx > 72) {
      _swipeStart = null;
      return;
    }
    _swipeStart = event.localPosition;
  }

  void _finishSwipe(PointerUpEvent event) {
    final start = _swipeStart;
    _swipeStart = null;
    if (start == null || _section != 0) return;
    final delta = event.localPosition - start;
    if (delta.dx < 96 || delta.dx.abs() < delta.dy.abs() * 1.4) {
      return;
    }
    _openCamera();
  }

  Future<void> _openCamera() async {
    if (_openingCamera) return;
    _openingCamera = true;
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => const MainCameraScreen(),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      );
    } finally {
      _openingCamera = false;
    }
  }

  Widget _scrollLinkedChrome() => ValueListenableBuilder<double>(
    valueListenable: _chromeCollapse,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const StoryStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
          child: _SegmentTabs(
            labels: const ['Sana Özel', 'Takip'],
            selected: _photoMode,
            onChanged: _setPhotoMode,
          ),
        ),
      ],
    ),
    builder: (context, offset, child) {
      final progress = (offset / _chromeCollapseExtent).clamp(0.0, 1.0);
      final factor = 1 - progress;
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: factor,
          child: Transform.translate(
            offset: Offset(0, -offset),
            child: IgnorePointer(ignoring: progress > .97, child: child),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _rememberSwipeStart,
      onPointerUp: _finishSwipe,
      onPointerCancel: (_) => _swipeStart = null,
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
            const _HomeHeader(showBrand: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: _SegmentTabs(
                labels: const ['Ana Sayfa', 'Keşfet'],
                selected: _section,
                prominent: true,
                onChanged: _setSection,
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleFeedScroll,
                child: IndexedStack(
                  index: _section,
                  children: [
                    _loadedSections.contains(0)
                        ? Column(
                            children: [
                              _scrollLinkedChrome(),
                              Expanded(
                                child: IndexedStack(
                                  index: _photoMode,
                                  children: [
                                    _loadedPhotoModes.contains(0)
                                        ? const _AuthAwareFeed(
                                            mode: FeedMode.forYou,
                                          )
                                        : const SizedBox.shrink(),
                                    _loadedPhotoModes.contains(1)
                                        ? const _AuthAwareFeed(
                                            mode: FeedMode.following,
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                    _loadedSections.contains(1)
                        ? const HomeDiscoverScreen()
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
                ],
              ),
            ),
            if (_section == 0)
              Positioned(
                left: 0,
                top: 150,
                child: Semantics(
                  button: true,
                  label: 'Kamerayı aç',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openCamera,
                    child: Container(
                      width: 30,
                      height: 72,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 68,
                        decoration: const BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(14),
                          ),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
  final bool showBrand;
  const _HomeHeader({this.showBrand = true});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(showBrand ? 12 : 6, 5, 4, 2),
    child: Row(
      children: [
        if (showBrand) ...[
          const TbtBrandMark(size: 32),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'TBT',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -.35,
              ),
            ),
          ),
        ] else
          const Spacer(),
        _HeaderAction(
          tooltip: 'TBT’de Ara',
          icon: Icons.search_rounded,
          count: 0,
          onTap: () => Navigator.pushNamed(context, '/search'),
        ),
        StreamBuilder<int>(
          stream: AppNotificationService.instance.unreadCount(),
          builder: (_, s) => _HeaderAction(
            tooltip: 'Bildirimler',
            icon: Icons.notifications_none_rounded,
            count: s.data ?? 0,
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ),
        StreamBuilder<int>(
          stream: AppNotificationService.instance.unreadMessageCount(),
          builder: (_, s) => _HeaderAction(
            tooltip: 'Mesajlar',
            icon: Icons.send_outlined,
            count: s.data ?? 0,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
            ),
          ),
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
      (Icons.restaurant_outlined, 'Lezzet'),
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
                    child: Text(
                      'Mekanlar',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
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
              child: Text(
                'Lezzet, kahve, konaklama ve gezilecek yerler.',
                style: TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5),
              ),
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

class _PlanningHub extends StatelessWidget {
  final VoidCallback onOpenNearby;

  const _PlanningHub({required this.onOpenNearby});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openAuthenticated(BuildContext context, Widget page) {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Plan oluşturmak için giriş yapmalısın.'),
          ),
        );
      return;
    }
    _open(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            const Row(
              children: [
                _GradientIcon(icon: Icons.explore_rounded, size: 27),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planla',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                      ),
                      Text(
                        'Gezini, etkinliğini ve buluşmanı buradan başlat.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.subtleGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderAccent),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugün ne yapmak istersin?',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Rotanı kur, insanları bir araya getir veya çevrendeki planlara katıl.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14),
                  _GradientIcon(icon: Icons.route_rounded, size: 48),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PlanningActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Akıllı Plan Oluştur',
              subtitle: 'Şehir, süre ve ilgi alanına göre rotanı TBT hazırlasın.',
              accent: AppColors.cyan,
              featured: true,
              onTap: () => _openAuthenticated(
                context,
                const SmartPlanScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.bookmarks_rounded,
              title: 'Planlarım',
              subtitle: 'Kaydettiğin ve davet edildiğin rotaları görüntüle.',
              accent: AppColors.violetBright,
              onTap: () => _openAuthenticated(
                context,
                const TravelPlansScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.group_add_rounded,
              title: 'Arkadaşlarla Planla',
              subtitle: 'Yeni bir rota hazırla ve arkadaşlarını davet et.',
              accent: AppColors.success,
              onTap: () => _openAuthenticated(
                context,
                const CollaborativePlansScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.public_rounded,
              title: 'Hazır Rotaları Keşfet',
              subtitle: 'Topluluğun paylaştığı rotaları bul, puanla ve kaydet.',
              accent: AppColors.warning,
              onTap: () => _open(
                context,
                const PublicTravelPlansScreen(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 20, 2, 10),
              child: Text(
                'HIZLI İŞLEMLER',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            _PlanningActionCard(
              icon: Icons.route_rounded,
              title: 'Manuel Rota Oluştur',
              subtitle: 'Duraklarını kendin seç, sırala ve yolculuğunu hazırla.',
              accent: AppColors.cyan,
              onTap: () => _open(context, const RoutePlannerScreen()),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.event_available_rounded,
              title: 'Etkinlik Oluştur',
              subtitle: 'Tarih, konum ve ayrıntıları belirleyerek yayınla.',
              accent: AppColors.violetBright,
              onTap: () => _openAuthenticated(
                context,
                const EventCreateScreenV2(),
              ),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.groups_2_rounded,
              title: 'Buluşma Başlat',
              subtitle: 'Hızlı bir plan seç, detaylarını ekle ve paylaş.',
              accent: AppColors.success,
              onTap: () => _openAuthenticated(
                context,
                const EventPhotoCreateScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _PlanningActionCard(
              icon: Icons.near_me_rounded,
              title: 'Yakınımda Ne Var?',
              subtitle: 'Yakındaki etkinlikleri ve buluşmaları keşfet.',
              accent: AppColors.warning,
              onTap: onOpenNearby,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool featured;

  const _PlanningActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: featured ? AppColors.surfaceAlt : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: featured ? AppColors.borderAccent : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .32)),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSubtle,
                size: 15,
              ),
            ],
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Etkinlik oluşturmak için giriş yapmalısın.'),
        ),
      );
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EventPhotoCreateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (_, auth) {
      final user = auth.data;
      if (user == null) return _buildHub(false);
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (_, profile) =>
            _buildHub(_campusEligible(profile.data?.data() ?? const {})),
      );
    },
  );

  Widget _buildHub(bool campusEligible) {
    final labels = campusEligible
        ? const ['Çevrende', 'Kampüs']
        : const ['Çevrende'];
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
                            Text(
                              'Çevrende',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Yakındaki planlar ve etkinlikler tek akışta.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                              ),
                            ),
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
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'Etkinlik oluştur',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (campusEligible)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
                child: _SegmentTabs(
                  labels: labels,
                  selected: index,
                  onChanged: (v) => setState(() => _section = v),
                ),
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
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
        return const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return snapshot.data == null
          ? const LoginScreen(embedded: true)
          : const ProfilePage();
    },
  );
}

class _SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool prominent;
  const _SegmentTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: prominent ? 34 : 31,
    child: Row(
      children: List.generate(labels.length, (index) {
        final active = selected == index;
        return Expanded(
          child: InkWell(
            onTap: () => onChanged(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: .46),
                        fontSize: prominent ? 12.5 : 11,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: active ? (prominent ? 44 : 34) : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: active ? AppColors.accentGradient : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
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
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    padding: const EdgeInsets.all(8),
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
      colors: active
          ? const [AppColors.cyan, AppColors.violet]
          : const [Color(0x75FFFFFF), Color(0x75FFFFFF)],
    ).createShader(bounds),
    child: Icon(icon, size: size),
  );
}
