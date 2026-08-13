import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../models/shooting_guide.dart';
import '../models/spot_meetup.dart';
import '../services/meetup_service.dart';
import '../services/shooting_guide_service.dart';

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
          return const _SectionShell(
            icon: Icons.auto_awesome,
            title: 'Nasıl Çekilir?',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final guide = snapshot.data;
        if (guide == null) return const SizedBox.shrink();

        final rows = <_GuideRow>[
          if (guide.shootingPosition.isNotEmpty)
            _GuideRow(Icons.place_outlined, 'Nerede dur?', guide.shootingPosition),
          if (guide.subjectPlacement.isNotEmpty)
            _GuideRow(Icons.person_pin_circle_outlined, 'Özneyi yerleştir', guide.subjectPlacement),
          if (guide.lightDirection.isNotEmpty)
            _GuideRow(Icons.wb_sunny_outlined, 'Işığı kullan', guide.lightDirection),
          if (guide.compositionTip.isNotEmpty)
            _GuideRow(Icons.grid_3x3_outlined, 'Kadraj', guide.compositionTip),
          if (guide.portraitTip.isNotEmpty)
            _GuideRow(Icons.portrait_outlined, 'Portre', guide.portraitTip),
          if (guide.recommendedSettings.isNotEmpty)
            _GuideRow(Icons.tune, 'Başlangıç ayarları', guide.recommendedSettings),
          if (guide.accessibilityNote.isNotEmpty)
            _GuideRow(Icons.shield_outlined, 'Erişim ve güvenlik', guide.accessibilityNote),
        ];

        return _SectionShell(
          icon: Icons.auto_awesome,
          title: 'Nasıl Çekilir?',
          subtitle: 'Bu noktaya özel çekim planı',
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _GuideRowTile(row: rows[i]),
                if (i != rows.length - 1) const Divider(height: 22, color: Colors.white10),
              ],
              if (guide.shotIdeas.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Denenecek kareler',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: guide.shotIdeas
                      .map(
                        (idea) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF202631),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            idea,
                            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                          ),
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
    return _SectionShell(
      icon: Icons.groups_2_outlined,
      title: 'Birlikte Git',
      subtitle: 'Bu noktaya fotoğraf çekmeye gidecek kişileri bul',
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
            return const _EmptyMeetup(
              icon: Icons.cloud_off_outlined,
              title: 'Buluşmalar yüklenemedi',
              text: 'Bağlantı düzeldiğinde burada yaklaşan fotoğraf buluşmaları görünecek.',
            );
          }

          final meetups = snapshot.data ?? const <SpotMeetup>[];
          if (meetups.isEmpty) {
            return const _EmptyMeetup(
              icon: Icons.group_add_outlined,
              title: 'İlk buluşmayı sen başlat',
              text: 'Tarih, saat ve kişi sayısını seç. Kesin konum yerine yalnızca çekim noktası paylaşılır.',
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message(context, 'Buluşma oluşturmak için önce giriş yapmalısın.');
      return;
    }

    DateTime selected = DateTime.now().add(const Duration(hours: 2));
    int capacity = 3;
    final noteController = TextEditingController();
    String purpose = 'Fotoğraf çekimi';
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11161E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
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
                  16,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${spot.name} • Birlikte Git',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kesin canlı konum paylaşılmaz. Katılımcılar yalnızca bu çekim noktasını ve planlanan zamanı görür.',
                        style: TextStyle(color: Colors.white60, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      _PickerTile(
                        icon: Icons.event_outlined,
                        title: 'Tarih ve saat',
                        value: _dateTimeText(selected),
                        onTap: chooseDateTime,
                      ),
                      const SizedBox(height: 12),
                      const Text('Amaç', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Fotoğraf çekimi',
                          'Gün batımı',
                          'Portre',
                          'Gece çekimi',
                        ].map((item) {
                          final selectedItem = purpose == item;
                          return ChoiceChip(
                            label: Text(item),
                            selected: selectedItem,
                            onSelected: (_) => setSheetState(() => purpose = item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLength: 180,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Kısa not (isteğe bağlı)',
                          hintText: 'Örn. tripod getireceğim, gün batımından 30 dk önce buluşalım.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        );
      },
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
            const SizedBox(height: 12),
            Text(meetup.note, style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 17, color: Colors.white54),
              const SizedBox(width: 5),
              Text('${meetup.participantCount}/${meetup.capacity} kişi', style: const TextStyle(color: Colors.white60)),
              const SizedBox(width: 14),
              if (meetup.approximateLocationOnly) ...[
                const Icon(Icons.privacy_tip_outlined, size: 17, color: Colors.white54),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text('Yaklaşık konum', style: TextStyle(color: Colors.white60)),
                ),
              ] else
                const Spacer(),
              if (isHost)
                TextButton(
                  onPressed: busy ? null : () => _leave(context),
                  child: const Text('İptal et'),
                )
              else if (joined)
                TextButton(
                  onPressed: busy ? null : () => _leave(context),
                  child: const Text('Ayrıl'),
                )
              else
                FilledButton(
                  onPressed: busy || meetup.isFull ? null : () => _join(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(meetup.isFull ? 'Dolu' : 'Katıl'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context) async {
    setState(() => busy = true);
    try {
      await MeetupService.instance.join(widget.meetup.id);
      if (context.mounted) _message(context, 'Buluşmaya katıldın.');
    } catch (e) {
      if (context.mounted) _message(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _leave(BuildContext context) async {
    setState(() => busy = true);
    try {
      await MeetupService.instance.leave(widget.meetup.id);
      if (context.mounted) _message(context, 'Buluşma güncellendi.');
    } catch (e) {
      if (context.mounted) _message(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _SectionShell({
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
                      Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _GuideRow {
  final IconData icon;
  final String title;
  final String text;

  const _GuideRow(this.icon, this.title, this.text);
}

class _GuideRowTile extends StatelessWidget {
  final _GuideRow row;

  const _GuideRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 19, color: const Color(0xFFFFC107)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(row.text, style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyMeetup extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyMeetup({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B212A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Colors.white54, height: 1.35, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B212A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC107)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

String _dateTimeText(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} • ${two(date.hour)}:${two(date.minute)}';
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
