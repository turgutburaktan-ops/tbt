from pathlib import Path


def main() -> None:
    path = Path('lib/screens/social_events_screen.dart')
    if not path.exists():
        raise SystemExit('social_events_screen.dart not found')

    text = path.read_text(encoding='utf-8')

    service_anchor = "import '../services/event_trust_service.dart';\n"
    if "invite_link_service.dart" not in text:
        if service_anchor not in text:
            raise SystemExit('event service import anchor not found')
        text = text.replace(
            service_anchor,
            service_anchor + "import '../services/invite_link_service.dart';\n",
            1,
        )

    screen_anchor = "import 'event_location_picker_screen.dart';\n"
    screen_imports = (
        "import 'event_deep_link_screen.dart';\n"
        "import 'invite_qr_screen.dart';\n"
    )
    if "invite_qr_screen.dart" not in text:
        if screen_anchor not in text:
            raise SystemExit('event screen import anchor not found')
        text = text.replace(screen_anchor, screen_anchor + screen_imports, 1)

    join_anchor = """                        FilledButton(
                          onPressed: event.isFull && !joined && !isHost ? null : () => _toggleJoin(event),
                          child: Text(isHost ? 'İptal Et' : joined ? 'Ayrıl' : event.isFull ? 'Dolu' : event.isPaid ? 'Bilet Al' : 'Katıl'),
                        ),
"""
    invite_actions = """                        IconButton(
                          tooltip: 'Etkinlik QR',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InviteQrScreen(
                                title: event.title,
                                subtitle: event.city.isEmpty ? 'Etkinlik daveti' : '${event.city} • Etkinlik daveti',
                                uri: InviteLinkService.instance.eventUri(event.id),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded),
                        ),
                        IconButton(
                          tooltip: 'Paylaş',
                          onPressed: () => InviteLinkService.instance.shareEvent(
                            eventId: event.id,
                            eventTitle: event.title,
                            hostName: event.hostName,
                            city: event.city,
                          ),
                          icon: const Icon(Icons.ios_share_outlined),
                        ),
                        FilledButton(
                          onPressed: event.isFull && !joined && !isHost ? null : () => _toggleJoin(event),
                          child: Text(isHost ? 'İptal Et' : joined ? 'Ayrıl' : event.isFull ? 'Dolu' : event.isPaid ? 'Bilet Al' : 'Katıl'),
                        ),
"""
    if "tooltip: 'Etkinlik QR'" not in text:
        if join_anchor not in text:
            raise SystemExit('event join button anchor not found')
        text = text.replace(join_anchor, invite_actions, 1)

    card_anchor = """                return Card(
                  color: const Color(0xFF121416),
"""
    if "EventDeepLinkScreen(eventId: event.id)" not in text and card_anchor in text:
        # Keep the card design but make its title area navigable through an explicit details action.
        detail_anchor = """                      const SizedBox(height: 10),
                      Row(children: [
"""
        detail_replacement = """                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: event.id)),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Detay'),
                        ),
                      ),
                      Row(children: [
"""
        if detail_anchor in text:
            text = text.replace(detail_anchor, detail_replacement, 1)

    path.write_text(text, encoding='utf-8')
    print('Social event cards patched with invite QR/share/detail actions')


if __name__ == '__main__':
    main()
