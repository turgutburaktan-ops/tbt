import 'package:flutter/material.dart';

import 'past_events_screen.dart';
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.event_available_outlined), label: Text('Yaklaşan')),
              ButtonSegment(value: 1, icon: Icon(Icons.photo_album_outlined), label: Text('Anılarım')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              SocialEventsScreen(),
              PastEventsScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
