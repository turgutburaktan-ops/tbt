import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'event_photo_create_screen.dart';
import 'past_events_screen.dart';
import 'reels_screen.dart';
import 'social_events_screen.dart';

class EventsHubScreen extends StatefulWidget {
  const EventsHubScreen({super.key});

  @override
  State<EventsHubScreen> createState() => _EventsHubScreenState();
}

class _EventsHubScreenState extends State<EventsHubScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _EventTab(
                                icon: Icons.event_available_outlined,
                                label: 'Yaklaşan',
                                selected: _tab == 0,
                                onTap: () => setState(() => _tab = 0),
                              ),
                            ),
                            Expanded(
                              child: _EventTab(
                                icon: Icons.photo_album_outlined,
                                label: 'Anılarım',
                                selected: _tab == 1,
                                onTap: () => setState(() => _tab = 1),
                              ),
                            ),
                            Expanded(
                              child: _EventTab(
                                icon: Icons.smart_display_outlined,
                                label: 'Reels',
                                selected: _tab == 2,
                                onTap: () => setState(() => _tab = 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Etkinlik oluştur • +50 XP',
                      child: Material(
                        color: AppColors.surfaceStrong,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EventPhotoCreateScreen(),
                              ),
                            );
                            if (mounted) setState(() => _tab = 0);
                          },
                          child: const SizedBox(
                            width: 54,
                            height: 46,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Center(child: Icon(Icons.add_a_photo_outlined)),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: _XpBadge(text: '+50'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_tab == 0) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/rewards'),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: Color(0xFFFFD166),
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Etkinliğe katıl +15 XP  •  Etkinlik oluştur +50 XP',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                SocialEventsScreen(),
                PastEventsScreen(embedded: true),
                ReelsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final String text;
  const _XpBadge({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD166),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 8,
      ),
    ),
  );
}

class _EventTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EventTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceStrong : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.cyan : Colors.white54,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
