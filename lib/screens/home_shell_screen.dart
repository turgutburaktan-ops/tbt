import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import 'activity_demand_screen.dart';
import 'camera_screen.dart';
import 'events_hub_screen.dart';
import 'feed_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_page_v2.dart';
import 'radar_screen.dart';
import 'spot_explore_screen_v2.dart';

class _Neon {
  static const bg = Color(0xFF06070B);
  static const panel = Color(0xFF101218);
  static const cyan = Color(0xFF42F5E9);
  static const violet = Color(0xFF8B5CF6);
  static const border = Color(0xFF292D38);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const _CommunityHub(), const MapScreen(), const RadarScreen(), const _ProfileGate()];
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      backgroundColor: _Neon.bg,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_Neon.cyan, _Neon.violet]),
          boxShadow: [BoxShadow(color: _Neon.cyan.withValues(alpha: .24), blurRadius: 22)],
        ),
        child: FloatingActionButton.small(
          heroTag: 'home-camera',
          tooltip: 'Kamera',
          elevation: 0,
          backgroundColor: _Neon.panel,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
          child: const Icon(Icons.photo_camera_rounded, size: 22),
        ),
      ),
      bottomNavigationBar: _PremiumNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (value) => setState(() => _selectedIndex = value),
      ),
    );
  }
}

class _PremiumNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _PremiumNavigationBar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
      (Icons.explore_outlined, Icons.explore_rounded, 'Keşfet'),
      (Icons.radar_outlined, Icons.radar_rounded, 'Radar'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
    ];
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xF20C0E13),
        border: const Border(top: BorderSide(color: _Neon.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .38), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return Expanded(
            child: InkResponse(
              onTap: () => onSelected(index),
              radius: 30,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: selected ? LinearGradient(colors: [_Neon.cyan.withValues(alpha: .13), _Neon.violet.withValues(alpha: .10)]) : null,
                  border: Border.all(color: selected ? _Neon.cyan.withValues(alpha: .28) : Colors.transparent),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _GradientIcon(icon: selected ? item.$2 : item.$1, active: selected),
                  const SizedBox(height: 3),
                  Text(item.$3, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 9.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                ]),
              ),
            ),
          );
        }),
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) return const SafeArea(child: Center(child: CircularProgressIndicator()));
          return snapshot.data == null ? const LoginScreen(embedded: true) : const ProfilePage();
        },
      );
}

class _AuthAwareFeed extends StatelessWidget {
  final FeedMode mode;
  const _AuthAwareFeed({required this.mode});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) => FeedScreen(key: ValueKey('${mode.name}-${snapshot.data?.uid ?? 'signed-out'}'), mode: mode, embedded: true),
      );
}

class _CommunityHub extends StatefulWidget {
  const _CommunityHub();
  @override
  State<_CommunityHub> createState() => _CommunityHubState();
}

class _CommunityHubState extends State<_CommunityHub> {
  int _section = 0;
  void _openActivity(String label) {
    if (label == 'Keşfet') { setState(() => _section = 2); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDemandScreen(initialActivity: label)));
  }

  @override
  Widget build(BuildContext context) {
    final activities = <(IconData, String)>[
      (Icons.photo_camera_outlined, 'Fotoğraf'), (Icons.local_cafe_outlined, 'Kahve'),
      (Icons.directions_walk_rounded, 'Yürüyüş'), (Icons.terrain_outlined, 'Kamp'),
      (Icons.sports_basketball_outlined, 'Spor'), (Icons.sports_esports_outlined, 'Oyun'),
      (Icons.place_outlined, 'Keşfet'),
    ];
    return ColoredBox(
      color: _Neon.bg,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          const _PremiumHeader(),
          if (_section <= 1)
            SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                children: activities.map((a) => _ActivityChip(icon: a.$1, label: a.$2, onTap: () => _openActivity(a.$2))).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: _Neon.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Neon.border)),
              child: Row(children: [
                for (final item in const [(0, 'Sana Özel'), (1, 'Takip'), (2, 'Yerler'), (3, 'Etkinlik')])
                  Expanded(child: _HubButton(label: item.$2, selected: _section == item.$1, onTap: () => setState(() => _section = item.$1))),
              ]),
            ),
          ),
          Expanded(child: IndexedStack(index: _section, children: const [
            _AuthAwareFeed(mode: FeedMode.forYou), _AuthAwareFeed(mode: FeedMode.following), SpotExploreScreen(), EventsHubScreen(),
          ])),
        ]),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
        child: Row(children: [
          Container(
            width: 42, height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [_Neon.cyan, _Neon.violet], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: _Neon.cyan.withValues(alpha: .18), blurRadius: 18)],
            ),
            child: const Text('TBT', style: TextStyle(color: Color(0xFF08090D), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: -.4)),
          ),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bugün ne yapıyoruz?', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.5)),
            SizedBox(height: 2),
            Text('Keşfet • Çek • Paylaş', style: TextStyle(color: Colors.white54, fontSize: 11.5, letterSpacing: .3)),
          ])),
          _HeaderAction(tooltip: 'Kampüs', icon: Icons.school_outlined, onTap: () {
            if (FirebaseAuth.instance.currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kampüs alanı için giriş yapmalısın.')));
              return;
            }
            Navigator.pushNamed(context, '/campus');
          }),
          StreamBuilder<int>(stream: AppNotificationService.instance.unreadCount(), builder: (_, s) => _HeaderAction(tooltip: 'Bildirimler', icon: Icons.notifications_none_rounded, count: s.data ?? 0, onTap: () => Navigator.pushNamed(context, '/notifications'))),
          StreamBuilder<int>(stream: AppNotificationService.instance.unreadMessageCount(), builder: (_, s) => _HeaderAction(tooltip: 'Mesajlar', icon: Icons.chat_bubble_outline_rounded, count: s.data ?? 0, onTap: () => Navigator.pushNamed(context, '/messages'))),
        ]),
      );
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  const _HeaderAction({required this.tooltip, required this.icon, required this.onTap, this.count = 0});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Tooltip(message: tooltip, child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 36, height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(color: _Neon.panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: _Neon.border)),
            child: Badge(isLabelVisible: count > 0, backgroundColor: _Neon.violet, label: Text(count > 99 ? '99+' : '$count'), child: Icon(icon, size: 19, color: Colors.white70)),
          ),
        )),
      );
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _GradientIcon({required this.icon, this.active = true});
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(colors: active ? const [_Neon.cyan, _Neon.violet] : const [Colors.white54, Colors.white54]).createShader(bounds),
        child: Icon(icon, size: 22),
      );
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActivityChip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 9),
        child: Material(color: Colors.transparent, child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            width: 84,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(color: _Neon.panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: _Neon.border)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _GradientIcon(icon: icon), const SizedBox(height: 5),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        )),
      );
}

class _HubButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HubButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected ? LinearGradient(colors: [_Neon.cyan.withValues(alpha: .18), _Neon.violet.withValues(alpha: .18)]) : null,
              border: Border.all(color: selected ? _Neon.cyan.withValues(alpha: .34) : Colors.transparent),
            ),
            child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: selected ? FontWeight.w900 : FontWeight.w700)),
          ),
        ),
      );
}
