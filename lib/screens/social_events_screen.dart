import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_ticket.dart';
import '../models/social_event.dart';
import '../services/event_ticket_service.dart';
import '../services/social_event_service.dart';
import '../widgets/content_engagement_bar.dart';
import 'event_tickets_screen.dart';

class SocialEventsScreen extends StatefulWidget {
  const SocialEventsScreen({super.key});

  @override
  State<SocialEventsScreen> createState() => _SocialEventsScreenState();
}

class _SocialEventsScreenState extends State<SocialEventsScreen> {
  SocialEventType? _selectedType;

  Stream<List<SocialEvent>> get _stream =>
      SocialEventService.instance.watchUpcoming(type: _selectedType);

  IconData _iconFor(SocialEventType type) => switch (type) {
        SocialEventType.photography => Icons.camera_alt_outlined,
        SocialEventType.cycling => Icons.directions_bike,
        SocialEventType.running => Icons.directions_run,
        SocialEventType.walking => Icons.directions_walk,
        SocialEventType.hiking => Icons.terrain_outlined,
        SocialEventType.camping => Icons.cabin_outlined,
        SocialEventType.followerMeetup => Icons.groups_2_outlined,
        SocialEventType.trip => Icons.route_outlined,
        SocialEventType.social => Icons.celebration_outlined,
        SocialEventType.concert => Icons.music_note_rounded,
        SocialEventType.party => Icons.nightlife_rounded,
        SocialEventType.theatre => Icons.theater_comedy_outlined,
        SocialEventType.seminar => Icons.record_voice_over_outlined,
        SocialEventType.workshop => Icons.handyman_outlined,
        SocialEventType.festival => Icons.festival_outlined,
        SocialEventType.talk => Icons.forum_outlined,
        SocialEventType.exhibition => Icons.museum_outlined,
        SocialEventType.standUp => Icons.mic_external_on_outlined,
        SocialEventType.dance => Icons.music_video_outlined,
        SocialEventType.cinema => Icons.movie_outlined,
        SocialEventType.gaming => Icons.sports_esports_outlined,
        SocialEventType.foodDrink => Icons.restaurant_outlined,
        SocialEventType.networking => Icons.hub_outlined,
        SocialEventType.education => Icons.school_outlined,
        SocialEventType.charity => Icons.volunteer_activism_outlined,
        SocialEventType.other => Icons.more_horiz,
      };

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _priceLabel(SocialEvent event) => event.isPaid
      ? '${event.ticketPrice.toStringAsFixed(2)} ${event.currency}'
      : 'Ücretsiz';

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('permission-denied')) {
      return 'Etkinlik servisi için veritabanı izni eksik. Formun silinmedi; tekrar deneyebilirsin.';
    }
    return text;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleJoin(SocialEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage('Katılmak için giriş yapmalısın.');
      return;
    }
    try {
      if (event.hostId == uid || event.participantIds.contains(uid)) {
        await SocialEventService.instance.leave(event.id);
        _showMessage(event.hostId == uid ? 'Etkinlik iptal edildi.' : 'Etkinlikten ayrıldın.');
      } else {
        await SocialEventService.instance.join(event.id);
        _showMessage(event.isPaid
            ? 'Ödeme altyapısı yakında aktif olacak.'
            : 'Etkinliğe katıldın. Biletin hazır.');
      }
    } catch (e) {
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _openCreate() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage('Etkinlik oluşturmak için giriş yapmalısın.');
      return;
    }

    final titleController = TextEditingController();
    final cityController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final customTypeController = TextEditingController();
    final priceController = TextEditingController();
    final capacityController = TextEditingController(text: '10');
    SocialEventType type = SocialEventType.social;
    EventAccessType accessType = EventAccessType.free;
    DateTime startsAt = DateTime.now().add(const Duration(hours: 2));
    int capacity = 10;
    bool saving = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090812),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> chooseDateTime() async {
            final date = await showDatePicker(
              context: context,
              initialDate: startsAt,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(startsAt),
            );
            if (time == null) return;
            setSheetState(() {
              startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            });
          }

          void setCapacity(int value) {
            final safe = value.clamp(2, 100);
            setSheetState(() {
              capacity = safe;
              formError = null;
            });
            capacityController.value = TextEditingValue(
              text: '$safe',
              selection: TextSelection.collapsed(offset: '$safe'.length),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Etkinlik Oluştur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Etkinlik başlığı', prefixIcon: Icon(Icons.title)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SocialEventType>(
                    value: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Etkinlik türü'),
                    items: SocialEventType.values
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Row(children: [
                                Icon(_iconFor(item), size: 18),
                                const SizedBox(width: 10),
                                Text(item.label),
                              ]),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => type = value);
                    },
                  ),
                  if (type == SocialEventType.other) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customTypeController,
                      decoration: const InputDecoration(labelText: 'Etkinlik türünün adı'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SegmentedButton<EventAccessType>(
                    segments: const [
                      ButtonSegment(
                        value: EventAccessType.free,
                        label: Text('Ücretsiz'),
                        icon: Icon(Icons.confirmation_number_outlined),
                      ),
                      ButtonSegment(
                        value: EventAccessType.paid,
                        label: Text('Ücretli'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {accessType},
                    onSelectionChanged: (values) => setSheetState(() => accessType = values.first),
                  ),
                  if (accessType == EventAccessType.paid) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Bilet fiyatı (TL)',
                        helperText: 'Ödeme altyapısı daha sonra aktif olacak.',
                        prefixIcon: Icon(Icons.currency_lira),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Etkinlik / buluşma konumu', prefixIcon: Icon(Icons.place_outlined)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Tarih ve saat'),
                    subtitle: Text(_dateLabel(startsAt)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: chooseDateTime,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Katılımcı kapasitesi', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: capacity > 2 ? () => setCapacity(capacity - 1) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 74,
                        child: TextField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '10',
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed == null) return;
                            setSheetState(() {
                              capacity = parsed.clamp(2, 100);
                              formError = null;
                            });
                          },
                          onEditingComplete: () {
                            final parsed = int.tryParse(capacityController.text) ?? capacity;
                            setCapacity(parsed);
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: capacity < 100 ? () => setCapacity(capacity + 1) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('2 ile 100 arasında sayı yazabilir veya + / - kullanabilirsin.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Açıklama / not'),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Text(formError!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final typedCapacity = int.tryParse(capacityController.text.trim());
                              if (typedCapacity == null || typedCapacity < 2 || typedCapacity > 100) {
                                setSheetState(() => formError = 'Katılımcı sayısı 2 ile 100 arasında olmalı.');
                                return;
                              }
                              capacity = typedCapacity;
                              setSheetState(() {
                                saving = true;
                                formError = null;
                              });
                              try {
                                final price = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0;
                                await SocialEventService.instance.create(
                                  title: titleController.text,
                                  type: type,
                                  startsAt: startsAt,
                                  capacity: capacity,
                                  city: cityController.text,
                                  locationLabel: locationController.text,
                                  description: descriptionController.text,
                                  customTypeLabel: customTypeController.text,
                                  accessType: accessType,
                                  ticketPriceMinor: (price * 100).round(),
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                _showMessage('Etkinlik oluşturuldu.');
                              } catch (e) {
                                final message = _friendlyError(e);
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    saving = false;
                                    formError = message;
                                  });
                                }
                              }
                            },
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_rounded),
                      label: Text(saving ? 'Oluşturuluyor...' : 'Etkinliği Oluştur'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    titleController.dispose();
    cityController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    customTypeController.dispose();
    priceController.dispose();
    capacityController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Etkinlikler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Keşfet, katıl, biletini al ve birlikte deneyimle.', style: TextStyle(color: Colors.white60)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Biletlerim',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventTicketsScreen()),
              ),
              icon: const Icon(Icons.confirmation_number_outlined),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.black),
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Oluştur'),
            ),
          ]),
        ),
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _selectedType == null,
                  onSelected: (_) => setState(() => _selectedType = null),
                ),
              ),
              ...SocialEventType.values.map(
                (type) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: Icon(_iconFor(type), size: 17),
                    label: Text(type.label),
                    selected: _selectedType == type,
                    onSelected: (_) => setState(() => _selectedType = type),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SocialEvent>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
              }
              if (snapshot.hasError) {
                final permissionDenied = snapshot.error.toString().contains('permission-denied');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_busy_outlined, size: 48, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(
                          permissionDenied ? 'Etkinlik servisi için veritabanı izni bekleniyor.' : 'Etkinlikler yüklenemedi.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Bu ekran kapanmayacak; bağlantı düzeldiğinde liste otomatik yenilenir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final events = snapshot.data ?? const <SocialEvent>[];
              if (events.isEmpty) return const Center(child: Text('Yaklaşan etkinlik yok.'));

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final joined = uid != null && event.participantIds.contains(uid);
                  final isHost = uid != null && event.hostId == uid;
                  return Card(
                    color: const Color(0xFF141126),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              backgroundColor: const Color(0x228B5CF6),
                              foregroundColor: const Color(0xFF8B5CF6),
                              child: Icon(_iconFor(event.type)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                  Text(
                                    '${event.typeLabel} • ${_priceLabel(event)}',
                                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            Text('${event.participantCount}/${event.capacity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _Meta(icon: Icons.schedule, text: _dateLabel(event.startsAt)),
                              if (event.city.isNotEmpty) _Meta(icon: Icons.location_city_outlined, text: event.city),
                              if (event.locationLabel.isNotEmpty) _Meta(icon: Icons.place_outlined, text: event.locationLabel),
                            ],
                          ),
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              event.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, height: 1.35),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ContentEngagementBar(
                            collection: 'social_events',
                            contentId: event.id,
                            ownerId: event.hostId,
                            title: event.title,
                            sourceType: 'social_event',
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: Text('Düzenleyen: ${event.hostName}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ),
                            if (joined && !isHost)
                              StreamBuilder<EventTicket?>(
                                stream: EventTicketService.instance.watchTicket(event.id),
                                builder: (context, ticketSnapshot) {
                                  final ticket = ticketSnapshot.data;
                                  if (ticket == null || !ticket.isActive) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => TicketQrScreen(ticket: ticket)),
                                      ),
                                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                      label: const Text('Biletim'),
                                    ),
                                  );
                                },
                              ),
                            if (isHost)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TicketScannerScreen(eventId: event.id, eventTitle: event.title),
                                    ),
                                  ),
                                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                                  label: const Text('Bilet Kontrol'),
                                ),
                              ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: (joined || isHost) ? const Color(0xFF241D3D) : const Color(0xFF8B5CF6),
                                foregroundColor: (joined || isHost) ? Colors.white : Colors.black,
                              ),
                              onPressed: event.isFull && !joined && !isHost ? null : () => _toggleJoin(event),
                              child: Text(
                                isHost
                                    ? 'İptal Et'
                                    : joined
                                        ? 'Ayrıl'
                                        : event.isFull
                                            ? 'Dolu'
                                            : event.isPaid
                                                ? 'Bilet Al'
                                                : 'Katıl',
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
