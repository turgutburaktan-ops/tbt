from pathlib import Path
import subprocess


def need(text: str, old: str, label: str) -> None:
    if old not in text:
        raise SystemExit(f"Expected block not found: {label}")

# #21 — inbox: show unread state and last-message time without adding polling.
path = Path('lib/screens/chat_inbox_screen.dart')
text = path.read_text()
if 'String _threadTime(DateTime? value)' not in text:
    marker = "class _ThreadTile extends StatelessWidget {"
    helper = """String _threadTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (now.year == local.year && now.month == local.month && now.day == local.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (now.difference(local).inDays < 7) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[local.weekday - 1];
  }
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
}

class _ThreadTile extends StatelessWidget {"""
    need(text, marker, 'thread helper insertion')
    text = text.replace(marker, helper, 1)

if 'final unread = thread.lastSenderId != myId' not in text:
    old = """            return _ThreadTile(thread: thread, otherUserId: otherIds.first);"""
    new = """            final lastRead = thread.lastReadAt[myId];
            final unread = thread.lastSenderId != myId &&
                thread.lastMessageAt != null &&
                (lastRead == null || thread.lastMessageAt!.isAfter(lastRead));
            return _ThreadTile(
              thread: thread,
              otherUserId: otherIds.first,
              myId: myId,
              unread: unread,
            );"""
    need(text, old, 'thread tile invocation')
    text = text.replace(old, new, 1)

text = text.replace(
    """  final String otherUserId;

  const _ThreadTile({required this.thread, required this.otherUserId});""",
    """  final String otherUserId;
  final String myId;
  final bool unread;

  const _ThreadTile({
    required this.thread,
    required this.otherUserId,
    required this.myId,
    required this.unread,
  });""",
    1,
)

old = """          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),"""
new = """          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              if (thread.lastMessageAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _threadTime(thread.lastMessageAt),
                  style: TextStyle(
                    color: unread ? const Color(0xFF62E6D2) : Colors.white38,
                    fontSize: 11,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),"""
if old in text:
    text = text.replace(old, new, 1)

text = text.replace(
    """            style: const TextStyle(color: Colors.white54),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),""",
    """            style: TextStyle(
              color: unread ? Colors.white : Colors.white54,
              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          trailing: unread
              ? const Badge(
                  backgroundColor: Color(0xFF62E6D2),
                  smallSize: 9,
                  child: Icon(Icons.chevron_right, color: Colors.white54),
                )
              : const Icon(Icons.chevron_right, color: Colors.white38),""",
    1,
)
path.write_text(text)

# #20 — surface privacy-safe Buradayım demand on the map as an aggregate social signal.
# Exact user coordinates are never requested or stored by ActivityDemandService.
path = Path('lib/screens/map_screen.dart')
text = path.read_text()
if "../services/activity_demand_service.dart" not in text:
    text = text.replace(
        "import '../services/road_route_service.dart';\n",
        "import '../services/activity_demand_service.dart';\nimport '../services/road_route_service.dart';\n",
        1,
    )

if 'StreamBuilder<List<ActivityDemand>>' not in text:
    old = """        return StreamBuilder<List<SocialEvent>>(
          stream: SocialEventService.instance.watchUpcoming(limit: 120),
          builder: (context, eventSnapshot) {
            _events = eventSnapshot.data ?? _events;
            return SafeArea("""
    new = """        return StreamBuilder<List<SocialEvent>>(
          stream: SocialEventService.instance.watchUpcoming(limit: 120),
          builder: (context, eventSnapshot) {
            _events = eventSnapshot.data ?? _events;
            return StreamBuilder<List<ActivityDemand>>(
              stream: ActivityDemandService.instance.watchActive(limit: 600),
              builder: (context, demandSnapshot) {
                final activeDemands = demandSnapshot.data ?? const <ActivityDemand>[];
                return SafeArea("""
    need(text, old, 'map demand stream open')
    text = text.replace(old, new, 1)
    old_close = """            );
          },
        );
      },
    );
  }
}"""
    # Replace only the final build-method close occurrence.
    idx = text.rfind(old_close)
    if idx == -1:
        raise SystemExit('Expected map build closing block not found')
    new_close = """                );
              },
            );
          },
        );
      },
    );
  }
}"""
    text = text[:idx] + new_close + text[idx + len(old_close):]

if "'topluluk sinyali'" not in text:
    marker = """                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(4),"""
    signal = """                        if (activeDemands.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: const Color(0xFF0F1113).withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _openEvents,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_alt_outlined, size: 17, color: Color(0xFF62E6D2)),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${activeDemands.length} topluluk sinyali',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('• kişi konumu gösterilmez', style: TextStyle(fontSize: 10.5, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(4),"""
    need(text, marker, 'map signal insertion')
    text = text.replace(marker, signal, 1)
path.write_text(text)

# Guardrail — Camera/Iris untouched.
changed = subprocess.check_output(['git', 'diff', '--name-only'], text=True).splitlines()
forbidden = {
    'lib/screens/camera_screen.dart',
    'lib/screens/main_camera_screen.dart',
    'lib/screens/ai_edit_screen.dart',
}
bad = sorted(set(changed).intersection(forbidden))
if bad:
    raise SystemExit(f'Camera/Iris guardrail violated: {bad}')
print('\n'.join(changed))
