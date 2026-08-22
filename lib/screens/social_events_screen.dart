import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_ticket.dart';
import '../models/social_event.dart';
import '../services/event_attendance_service.dart';
import '../services/event_privacy_service.dart';
import '../services/event_ticket_service.dart';
import '../services/event_trust_service.dart';
import '../services/social_event_service.dart';
import '../widgets/content_engagement_bar.dart';
import 'event_location_picker_screen.dart';
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

  IconData _privacyIcon(EventVisibility value) => switch (value) {
        EventVisibility.public => Icons.public,
        EventVisibility.followers => Icons.people_outline,
        EventVisibility.mutuals => Icons.sync_alt,
        EventVisibility.closeFriends => Icons.star_outline,
        EventVisibility.selectedPeople => Icons.person_add_alt_1,
        EventVisibility.private => Icons.lock_outline,
      };

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _priceLabel(SocialEvent event) => event.isPaid
      ? '${event.ticketPrice.toStringAsFixed(2)} ${event.currency}'
      : 'Ücretsiz';

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('permission-denied')) {
      return 'Bu işlem için veritabanı izni eksik. Lütfen tekrar dene.';
    }
    return text;
  }

  Future<Map<String, String>> _pickPeople(Set<String> initiallySelected) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final selected = <String>{...initiallySelected};
    final names = <String, String>{};
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D0F11),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kişileri Seç',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, names),
                      child: Text('Bitti (${selected.length})'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: EventPrivacyService.instance.users(),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.where((d) => d.id != me).toList();
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final name = (data['displayName'] ?? data['email'] ?? 'Kullanıcı').toString();
                        final photo = (data['photoUrl'] ?? '').toString();
                        names[doc.id] = name;
                        final checked = selected.contains(doc.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) => setSheetState(() {
                            if (v == true) {
                              selected.add(doc.id);
                            } else {
                              selected.remove(doc.id);
                            }
                          }),
                          secondary: CircleAvatar(
                            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                            child: photo.isEmpty ? const Icon(Icons.person_outline) : null,
                          ),
                          title: Text(name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) {
      return {for (final id in initiallySelected) id: names[id] ?? 'Kullanıcı'};
    }
    return {for (final id in selected) id: names[id] ?? 'Kullanıcı'};
  }

  Future<void> _showAttendanceChoices(SocialEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage('Etkinliğe katılmak için giriş yapmalısın.');
      return;
    }
    if (event.hostId == uid) {
      final cancel = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Etkinliği iptal et?'),
          content: const Text('Katılımcılara etkinliğin iptal edildiği bildirilecek.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('İptal Et')),
          ],
        ),
      );
      if (cancel == true) {
        await SocialEventService.instance.leave(event.id);
        _showMessage('Etkinlik iptal edildi.');
      }
      return;
    }

    final currentChoice = event.isHidden(uid)
        ? EventAttendanceChoice.hidden
        : event.isAttending(uid)
            ? EventAttendanceChoice.attending
            : event.isInterested(uid)
                ? EventAttendanceChoice.interested
                : null;

    final choice = await showModalBottomSheet<EventAttendanceChoice?>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111315),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Bu etkinlikle ne yapmak istiyorsun?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('İstersen katılımını diğer kullanıcılardan gizleyebilirsin.', style: TextStyle(color: Colors.white60, height: 1.35)),
            const SizedBox(height: 14),
            _AttendanceTile(
              icon: Icons.check_circle_outline_rounded,
              title: 'Katılıyorum',
              subtitle: 'Katılımcı listesinde görün ve yerini ayır.',
              selected: currentChoice == EventAttendanceChoice.attending,
              onTap: () => Navigator.pop(sheetContext, EventAttendanceChoice.attending),
            ),
            _AttendanceTile(
              icon: Icons.star_border_rounded,
              title: 'İlgileniyorum',
              subtitle: 'Etkinliği takip et; kapasiteden yer ayırma.',
              selected: currentChoice == EventAttendanceChoice.interested,
              onTap: () => Navigator.pop(sheetContext, EventAttendanceChoice.interested),
            ),
            _AttendanceTile(
              icon: Icons.visibility_off_outlined,
              title: 'Gizli katıl',
              subtitle: 'Yerini ayır ama adın diğer kullanıcılara görünmesin.',
              selected: currentChoice == EventAttendanceChoice.hidden,
              onTap: () => Navigator.pop(sheetContext, EventAttendanceChoice.hidden),
            ),
            if (currentChoice != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, null),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Seçimimi kaldır'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    try {
      if (choice == null) {
        if (currentChoice != null) {
          await EventAttendanceService.instance.clearChoice(event.id);
          _showMessage('Etkinlik tercihin kaldırıldı.');
        }
        return;
      }
      await EventAttendanceService.instance.setChoice(event.id, choice);
      _showMessage(switch (choice) {
        EventAttendanceChoice.attending => 'Etkinliğe katılıyorsun.',
        EventAttendanceChoice.interested => 'Etkinlikle ilgileniyorsun.',
        EventAttendanceChoice.hidden => 'Gizli katılımın kaydedildi.',
      });
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
    EventVisibility visibility = EventVisibility.public;
    Map<String, String> selectedPeople = {};
    DateTime startsAt = DateTime.now().add(const Duration(hours: 2));
    EventLocationSelection? selectedLocation;
    bool saving = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090A0C),
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
            setSheetState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
          }

          Future<void> chooseLocation() async {
            final result = await Navigator.push<EventLocationSelection>(
              context,
              MaterialPageRoute(
                builder: (_) => EventLocationPickerScreen(
                  city: cityController.text,
                  addressLabel: locationController.text,
                  initialLatitude: selectedLocation?.latitude,
                  initialLongitude: selectedLocation?.longitude,
                ),
              ),
            );
            if (result == null || !context.mounted) return;
            setSheetState(() {
              selectedLocation = result;
              if (locationController.text.trim().isEmpty) {
                locationController.text = result.label;
              }
              formError = null;
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Etkinlik Oluştur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Text('Fotoğraf yürüyüşü, kahve buluşması, gezi, kamp veya kendi fikrini oluştur.', style: TextStyle(color: Colors.white60, height: 1.35)),
                  const SizedBox(height: 16),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Etkinlik başlığı', prefixIcon: Icon(Icons.title))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SocialEventType>(
                    value: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Etkinlik türü'),
                    items: SocialEventType.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => type = value);
                    },
                  ),
                  if (type == SocialEventType.other) ...[
                    const SizedBox(height: 12),
                    TextField(controller: customTypeController, decoration: const InputDecoration(labelText: 'Etkinlik türünün adı')),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<EventVisibility>(
                    value: visibility,
                    decoration: const InputDecoration(labelText: 'Kimler görebilir?', prefixIcon: Icon(Icons.shield_outlined)),
                    items: EventVisibility.values.map((item) => DropdownMenuItem(
                      value: item,
                      child: Row(children: [Icon(_privacyIcon(item), size: 18), const SizedBox(width: 9), Text(item.label)]),
                    )).toList(),
                    onChanged: (value) => setSheetState(() {
                      visibility = value ?? EventVisibility.public;
                      if (visibility != EventVisibility.selectedPeople) selectedPeople = {};
                    }),
                  ),
                  if (visibility == EventVisibility.selectedPeople) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickPeople(selectedPeople.keys.toSet());
                        if (context.mounted) setSheetState(() => selectedPeople = picked);
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(selectedPeople.isEmpty ? 'Kişileri seç' : '${selectedPeople.length} kişi seçildi'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SegmentedButton<EventAccessType>(
                    segments: const [
                      ButtonSegment(value: EventAccessType.free, label: Text('Ücretsiz'), icon: Icon(Icons.confirmation_number_outlined)),
                      ButtonSegment(value: EventAccessType.paid, label: Text('Ücretli'), icon: Icon(Icons.payments_outlined)),
                    ],
                    selected: {accessType},
                    onSelectionChanged: (values) => setSheetState(() => accessType = values.first),
                  ),
                  if (accessType == EventAccessType.paid) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Bilet fiyatı (TL)', prefixIcon: Icon(Icons.currency_lira)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: cityController, decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Etkinlik / buluşma adresi', prefixIcon: Icon(Icons.place_outlined))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: chooseLocation,
                      icon: Icon(selectedLocation == null ? Icons.map_outlined : Icons.location_on),
                      label: Text(selectedLocation == null ? 'Haritadan kesin konumu seç' : 'Harita konumu seçildi • Değiştir'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Tarih ve saat'),
                    subtitle: Text(_dateLabel(startsAt)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: chooseDateTime,
                  ),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Katılımcı kapasitesi', prefixIcon: Icon(Icons.groups_2_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: descriptionController, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Açıklama / not')),
                  if (formError != null) ...[
                    const SizedBox(height: 12),
                    Text(formError!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final typedCapacity = int.tryParse(capacityController.text.trim()) ?? 0;
                              if (typedCapacity < 1) {
                                setSheetState(() => formError = 'Katılımcı sayısı en az 1 olmalı.');
                                return;
                              }
                              if (selectedLocation == null) {
                                setSheetState(() => formError = 'Etkinliğin haritadaki kesin konumunu seç.');
                                return;
                              }
                              if (visibility == EventVisibility.selectedPeople && selectedPeople.isEmpty) {
                                setSheetState(() => formError = 'En az bir kişi seçmelisin.');
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                formError = null;
                              });
                              try {
                                final price = double.tryParse(priceController.text.trim().replaceAll(',', '.')) ?? 0;
                                if (accessType == EventAccessType.paid) {
                                  final eligibility = await EventTrustService.instance.paidEventEligibility();
                                  if (!eligibility.allowed) throw Exception(eligibility.reason);
                                }
                                final allowed = await EventPrivacyService.instance.resolveAudience(
                                  visibility,
                                  selectedUserIds: selectedPeople.keys.toList(),
                                );
                                await SocialEventService.instance.create(
                                  title: titleController.text,
                                  type: type,
                                  startsAt: startsAt,
                                  capacity: typedCapacity,
                                  city: cityController.text,
                                  locationLabel: locationController.text,
                                  description: descriptionController.text,
                                  customTypeLabel: customTypeController.text,
                                  accessType: accessType,
                                  ticketPriceMinor: (price * 100).round(),
                                  latitude: selectedLocation!.latitude,
                                  longitude: selectedLocation!.longitude,
                                  visibility: visibility,
                                  allowedUserIds: allowed,
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                _showMessage('Etkinlik oluşturuldu.');
                              } catch (e) {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    saving = false;
                                    formError = _friendlyError(e);
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Etkinlikler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Katıl, ilgilen veya kendi buluşmanı oluştur.', style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Biletlerim',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventTicketsScreen())),
                    icon: const Icon(Icons.confirmation_number_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CreateEventDiscoveryCard(onTap: _openCreate),
            ],
          ),
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
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Etkinlikler yüklenemedi.\n${_friendlyError(snapshot.error!)}',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final events = snapshot.data ?? const <SocialEvent>[];
              if (events.isEmpty) {
                return _EmptyEvents(onCreate: _openCreate);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final event = events[index];
                  final isHost = uid != null && event.hostId == uid;
                  final attending = uid != null && event.isAttending(uid);
                  final interested = uid != null && event.isInterested(uid);
                  final hidden = uid != null && event.isHidden(uid);
                  final stateLabel = isHost
                      ? 'Yönet'
                      : hidden
                          ? 'Gizli katılıyorsun'
                          : attending
                              ? 'Katılıyorsun'
                              : interested
                                  ? 'İlgileniyorsun'
                                  : event.isFull
                                      ? 'Dolu'
                                      : 'Katıl';
                  return Card(
                    color: const Color(0xFF121416),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(child: Icon(_iconFor(event.type))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                    Text('${event.typeLabel} • ${_priceLabel(event)}', style: const TextStyle(color: Color(0xFFB7BCC2), fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Text('${event.participantCount}/${event.capacity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              _Meta(icon: Icons.schedule, text: _dateLabel(event.startsAt)),
                              if (event.city.isNotEmpty) _Meta(icon: Icons.location_city_outlined, text: event.city),
                              _Meta(icon: _privacyIcon(event.visibility), text: event.visibility.label),
                              if (event.interestedCount > 0) _Meta(icon: Icons.star_border_rounded, text: '${event.interestedCount} ilgili'),
                            ],
                          ),
                          if (event.locationLabel.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _Meta(icon: Icons.place_outlined, text: event.locationLabel),
                          ],
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(event.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.35)),
                          ],
                          const SizedBox(height: 8),
                          ContentEngagementBar(
                            collection: 'social_events',
                            contentId: event.id,
                            ownerId: event.hostId,
                            title: event.title,
                            sourceType: 'social_event',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: Text('Düzenleyen: ${event.hostName}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                              if (attending && !hidden && !isHost)
                                StreamBuilder<EventTicket?>(
                                  stream: EventTicketService.instance.watchTicket(event.id),
                                  builder: (_, ticketSnapshot) {
                                    final ticket = ticketSnapshot.data;
                                    if (ticket == null || !ticket.isActive) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: OutlinedButton.icon(
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketQrScreen(ticket: ticket))),
                                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                        label: const Text('Biletim'),
                                      ),
                                    );
                                  },
                                ),
                              FilledButton.icon(
                                onPressed: event.isFull && !attending && !interested && !isHost
                                    ? null
                                    : () => _showAttendanceChoices(event),
                                icon: Icon(isHost ? Icons.tune_rounded : attending ? Icons.check_rounded : interested ? Icons.star_outline_rounded : Icons.person_add_alt_1_rounded, size: 18),
                                label: Text(stateLabel),
                              ),
                            ],
                          ),
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

class _CreateEventDiscoveryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateEventDiscoveryCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF171A1D),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25292E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sen de bir etkinlik başlat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Fotoğraf yürüyüşü • Kahve • Gezi • Kamp', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      );
}

class _EmptyEvents extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyEvents({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_2_outlined, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Yaklaşan etkinlik yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text(
                'Çevrende ilk fotoğraf yürüyüşünü, kahve buluşmasını, geziyi veya kamp etkinliğini sen oluşturabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('İlk Etkinliği Oluştur'),
              ),
            ],
          ),
        ),
      );
}

class _AttendanceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AttendanceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? const Color(0xFF20262A) : const Color(0xFF171A1D),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: selected ? const Icon(Icons.check_circle_rounded) : const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}
