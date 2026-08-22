import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../services/event_attendance_service.dart';
import '../theme/app_theme.dart';

class EventAttendanceActions extends StatefulWidget {
  final SocialEvent event;
  final ValueChanged<String>? onMessage;

  const EventAttendanceActions({
    super.key,
    required this.event,
    this.onMessage,
  });

  @override
  State<EventAttendanceActions> createState() => _EventAttendanceActionsState();
}

class _EventAttendanceActionsState extends State<EventAttendanceActions> {
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  EventAttendanceChoice? get _currentChoice {
    final uid = _uid;
    if (uid == null) return null;
    if (widget.event.isHidden(uid)) return EventAttendanceChoice.hidden;
    if (widget.event.participantIds.contains(uid)) return EventAttendanceChoice.attending;
    if (widget.event.isInterested(uid)) return EventAttendanceChoice.interested;
    return null;
  }

  Future<void> _choose(EventAttendanceChoice choice) async {
    if (_busy) return;
    if (_uid == null) {
      widget.onMessage?.call('Katılmak için giriş yapmalısın.');
      return;
    }
    setState(() => _busy = true);
    try {
      await EventAttendanceService.instance.setChoice(widget.event.id, choice);
      widget.onMessage?.call(switch (choice) {
        EventAttendanceChoice.attending => 'Etkinliğe katılıyorsun.',
        EventAttendanceChoice.interested => 'Etkinlikle ilgilendiğin kaydedildi.',
        EventAttendanceChoice.hidden => 'Gizli katılımın kaydedildi.',
      });
      if (mounted) Navigator.maybePop(context);
    } catch (e) {
      widget.onMessage?.call(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy || _uid == null) return;
    setState(() => _busy = true);
    try {
      await EventAttendanceService.instance.clearChoice(widget.event.id);
      widget.onMessage?.call('Etkinlik tercihin kaldırıldı.');
    } catch (e) {
      widget.onMessage?.call(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChoices() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Etkinliğe nasıl dahil olmak istersin?',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: Icons.check_circle_outline_rounded,
              title: 'Katılıyorum',
              subtitle: 'Katılımcı listesinde görünürsün ve yerin ayrılır.',
              onTap: () => _choose(EventAttendanceChoice.attending),
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: Icons.star_border_rounded,
              title: 'İlgileniyorum',
              subtitle: 'Yerin ayrılmaz; etkinliği takip edip hatırlatma alabilirsin.',
              onTap: () => _choose(EventAttendanceChoice.interested),
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: Icons.visibility_off_outlined,
              title: 'Gizli katıl',
              subtitle: 'Yerin ayrılır fakat adın diğer katılımcılara gösterilmez.',
              onTap: () => _choose(EventAttendanceChoice.hidden),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choice = _currentChoice;
    if (choice != null) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _clear,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(switch (choice) {
                EventAttendanceChoice.attending => Icons.check_circle_rounded,
                EventAttendanceChoice.interested => Icons.star_rounded,
                EventAttendanceChoice.hidden => Icons.visibility_off_rounded,
              }),
        label: Text(choice.label),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(13),
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF08090D),
        ),
        onPressed: widget.event.isFull || _busy ? null : _openChoices,
        icon: const Icon(Icons.how_to_reg_rounded),
        label: Text(widget.event.isFull ? 'Dolu' : 'Katıl'),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.cyan),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
