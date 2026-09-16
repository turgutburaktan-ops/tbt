import 'package:flutter/material.dart';
import '../models/social_event.dart';
import '../theme/app_theme.dart';
import '../utils/event_presentation.dart';

class EventListCard extends StatelessWidget {
  const EventListCard({super.key, required this.event, required this.joined, required this.busy, required this.onOpen, required this.onJoin, required this.icon});
  final SocialEvent event;
  final bool joined, busy;
  final VoidCallback onOpen, onJoin;
  final IconData icon;
  @override Widget build(BuildContext context) {
    final remaining = event.remainingSlots.clamp(0, event.capacity);
    return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(17), child: InkWell(
      borderRadius: BorderRadius.circular(17), onTap: onOpen,
      child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 56, height: 56,
            child: event.coverImageUrl.isNotEmpty ? Image.network(event.coverImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, color: AppColors.cyan)) : ColoredBox(color: AppColors.surfaceStrong, child: Icon(icon, color: AppColors.cyan)),
          )),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(eventStartLabel(event.startsAt), style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(event.locationLabel.isEmpty ? event.city : event.locationLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${event.participantCount}/${event.capacity} katılımcı', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (remaining > 0 && remaining <= 2) Text('Son $remaining yer', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          FilledButton(style: joined ? FilledButton.styleFrom(backgroundColor: AppColors.surfaceStrong, foregroundColor: AppColors.textPrimary) : null, onPressed: busy || (event.isFull && !joined) ? null : joined ? onOpen : onJoin,
            child: busy ? const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2)) : Text(joined ? 'Detayları Gör' : event.isFull ? 'Dolu' : 'Ben de Geliyorum'),
          ),
        ]),
      ])),
    ));
  }
}
