import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../models/shooting_guide.dart';
import '../models/spot_meetup.dart';
import '../services/meetup_service.dart';
import '../services/shooting_guide_service.dart';
import 'meetup_chat_actions.dart';

class ShootingGuideSection extends StatelessWidget {
  final PhotoSpot spot;

  const ShootingGuideSection({
    super.key,
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShootingGuide>(
      future: ShootingGuideService.instance.loadForSpot(spot),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Shell(
            icon: Icons.auto_awesome,
            title: 'Nasıl Çekilir?',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final guide = snapshot.data;
        if (guide == null) {
          return const _Shell(
            icon: Icons.auto_awesome,
            title: 'Nasıl Çekilir?',
            child: Text(
              'Bu nokta için çekim rehberi hazırlanamadı.',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }

        final rows = <({IconData icon, String title, String text})>[
          if (guide.shootingPosition.trim().isNotEmpty)
            (icon: Icons.place_outlined, title: 'Nerede dur?', text: guide.shootingPosition),
          if (guide.subjectPlacement.trim().isNotEmpty)
            (icon: Icons.person_pin_circle_outlined, title: 'Özneyi yerleştir', text: guide.subjectPlacement),
          if (guide.lightDirection.trim().isNotEmpty)
            (icon: Icons.wb_sunny_outlined, title: 'Işığı kullan', text: guide.lightDirection),
          if (guide.compositionTip.trim().isNotEmpty)
            (icon: Icons.grid_3x3_outlined, title: 'Kadraj', text: guide.compositionTip),
          if (guide.portraitTip.trim().isNotEmpty)
            (icon: Icons.portrait_outlined, title: 'Portre', text: guide.portraitTip),
          if (guide.recommendedSettings.trim().isNotEmpty)
            (icon: Icons.tune, title: 'Başlangıç ayarları', text: guide.recommendedSettings),
          if (guide.accessibilityNote.trim().isNotEmpty)
            (icon: Icons.shield_outlined, title: 'Erişim ve güvenlik', text: guide.accessibilityNote),
        ];

        return _Shell(
          icon: Icons.auto_awesome,
          title: 'Nasıl Çekilir?',
          subtitle: 'Bu noktaya özel çekim planı',
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(rows[i].icon, size: 20, color: const Color(0xFFFFC107)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(rows[i].text, style: const TextStyle(color: Colors.white70, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (i != rows.length - 1) const Divider(height: 24, color: Colors.white10),
              ],
              if (guide.shotIdeas.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Denenecek kareler', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: guide.shotIdeas
                      .map(
                        (idea) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF202631),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(idea, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class TogetherGoSection extends StatelessWidget {
  final PhotoSpot spot;

  const TogetherGoSection({
    super.key,
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
    return _Shell(
      icon: Icons.groups_2_outlined,
      title: 'Birlikte Git',
      subtitle: 'Bu noktaya gidecek kişileri bul ve mesajlaşarak plan yap',
      trailing: TextButton.icon(
        onPressed: () => _openCreateMeetup(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Buluşma oluştur'),
      ),
      child: StreamBuilder<List<SpotMeetup>>(
        stream: MeetupService.instance.watchUpcomingForSpot(spot.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          if (snapshot.hasError) {
            return const _Notice(
              icon: Icons.cloud_off_outlined,
              title: 'Buluşmalar yüklenemedi',
              text: 'Bağlantı düzeldiğinde yaklaşan buluşmalar burada görünecek.',
            );
          }

          final meetups = snapshot.data ?? const <SpotMeetup>[];
          if (meetups.isEmpty) {
            return const _Notice(
              icon: Icons.group_add_outlined,
              title: 'İlk buluşmayı sen başlat',
              text: 'Tarih, saat ve kişi sayısını seç. Kesin canlı konum paylaşılmaz.',
            );
          }

          return Column(
            children: [
              for (var i = 0; i < meetups.length; i++) ...[
                _MeetupCard(meetup: meetups[i]),
                if (i != meetups.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateMeetup(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message(context, 'Buluşma oluşturmak için önce giriş yapmalısın.');
      return;
    }

    DateTime selected = DateTime.now().add(const Duration(hours: 2));
    int capacity = 3;
    String purpose = 'Fotoğraf çekimi';
    bool saving = false;
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11161E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> chooseDateTime() async {
            final date = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (date == null || !context.mounted) return;

            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(selected),
            );
            if (time == null) return;

            setSheetState(() {
              selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            });
          }

          Future<void> save() async {
            if (saving) return;
            setSheetState(() => saving = true);
            try {
              await MeetupService.instance.createMeetup(
                spot: spot,
                startsAt: selected,
                capacity: capacity,
                purpose: purpose,
                note: noteController.text,
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              if (context.mounted) _message(context, 'Buluşma oluşturuldu.');
            } catch (e) {
              if (context.mounted) _message(context, _cleanError(e));
              setSheetState(() => saving = false);
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${spot.name} • Birlikte Git',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Katılımcılar çekim noktasını ve planlanan zamanı görür. Kesin canlı konum paylaşılmaz.',
                      style: TextStyle(color: Colors.white60, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined, color: Color(0xFFFFC107)),
                      title: const Text('Tarih ve saat'),
                      subtitle: Text(_dateTimeText(selected)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: chooseDateTime,
                    ),
                    const SizedBox(height: 8),
                    const Text('Amaç', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Fotoğraf çekimi', 'Gün batımı', 'Portre', 'Gece çekimi']
                          .map(
                            (item) => ChoiceChip(
                              label: Text(item),
                              selected: purpose == item,
                              onSelected: (_) => setSheetState(() => purpose = item),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Toplam kişi sayısı', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: capacity > 2 ? () => setSheetState(() => capacity--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$capacity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(
                          onPressed: capacity < 12 ? () => setSheetState(() => capacity++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    TextField(
                      controller: noteController,
                      maxLength: 180,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Kısa not (isteğe bağlı)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: saving ? null : save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.groups_2_outlined),
                        label: Text(saving ? 'Oluşturuluyor...' : 'Buluşmayı oluştur'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    noteController.dispose();
  }
}

class _MeetupCard extends StatefulWidget {
  final SpotMeetup meetup;

  const _MeetupCard({required this.meetup});

  @override
  State<_MeetupCard> createState() => _MeetupCardState();
}

class _MeetupCardState extends State<_MeetupCard> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final meetup = widget.meetup;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joined = uid != null && meetup.participantIds.contains(uid);
    final isHost = uid != null && meetup.hostId == uid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B212A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x22FFC107),
                ),
                child: const Icon(Icons.people_alt_outlined, color: Color(0xFFFFC107)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meetup.purpose, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      '${meetup.hostName} • ${_dateTimeText(meetup.startsAt)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meetup.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(meetup.note, style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 17, color: Colors.white54),
              const SizedBox(width: 5),
              Text(
                '${meetup.participantCount}/${meetup.capacity} kişi',
                style: const TextStyle(color: Colors.white60),
              ),
              const Spacer(),
              if (isHost)
                TextButton(
                  onPressed: busy ? null : _leave,
                  child: const Text('İptal et'),
                )
              else if (joined)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : () => openMeetupHostChat(context, meetup),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Mesajlaş'),
                    ),
                    IconButton(
                      tooltip: 'Buluşmadan ayrıl',
                      onPressed: busy ? null : _leave,
                      icon: const Icon(Icons.logout, size: 19),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: busy || meetup.isFull ? null : _join,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(meetup.isFull ? 'Dolu' : 'Katıl'),
                ),
            ],
          ),
          if (joined && !isHost) ...[
            const SizedBox(height: 7),
            const Text(
              'Katıldın • Ev sahibiyle mesajlaşarak saati ve buluşma detaylarını netleştirebilirsin.',
              style: TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _join() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message(context, 'Buluşmaya katılmak için giriş yapmalısın.');
      return;
    }

    setState(() => busy = true);
    try {
      final chatReady = await MeetupService.instance.join(widget.meetup.id);
      if (!mounted) return;
      _message(
        context,
        chatReady
            ? 'Buluşmaya katıldın. Mesajlaş butonuyla ev sahibiyle konuşabilirsin.'
            : 'Buluşmaya katıldın. Mesajlaşma şu an hazırlanamadı; butondan tekrar deneyebilirsin.',
      );
    } catch (e) {
      if (mounted) _message(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _leave() async {
    setState(() => busy = true);
    final isHost = FirebaseAuth.instance.currentUser?.uid == widget.meetup.hostId;
    try {
      await MeetupService.instance.leave(widget.meetup.id);
      if (mounted) {
        _message(context, isHost ? 'Buluşma iptal edildi.' : 'Buluşmadan ayrıldın.');
      }
    } catch (e) {
      if (mounted) _message(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Shell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _Shell({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFC107),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFFFC107)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTimeText(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} • ${two(value.hour)}:${two(value.minute)}';
}

String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
