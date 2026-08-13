import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../models/spot_presence.dart';
import '../services/spot_presence_service.dart';

class SpotPresenceSection extends StatefulWidget {
  final PhotoSpot spot;

  const SpotPresenceSection({
    super.key,
    required this.spot,
  });

  @override
  State<SpotPresenceSection> createState() => _SpotPresenceSectionState();
}

class _SpotPresenceSectionState extends State<SpotPresenceSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: StreamBuilder<List<SpotPresence>>(
        stream: SpotPresenceService.instance.watchVisibleForSpot(widget.spot.id),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <SpotPresence>[];
          final isVisible = currentUser != null &&
              items.any((item) => item.userId == currentUser.uid);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFFFFC107)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şu anda burada',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Yalnızca görünür olmayı seçen kullanıcılar gösterilir.',
                          style: TextStyle(color: Colors.white60, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFC107),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (snapshot.hasError)
                const Text(
                  'Buradaki kullanıcılar şu anda yüklenemiyor.',
                  style: TextStyle(color: Colors.white60),
                )
              else if (items.isEmpty)
                const Text(
                  'Şu an görünür olan kimse yok. İstersen ilk sen görünür olabilirsin.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                )
              else
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _PresenceAvatar(item: item);
                    },
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kesin konum paylaşılmaz. Görünürlük 90 dakika sonra otomatik kapanır.',
                      style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isVisible)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _checkOut,
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('Gizlen'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _checkIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Buradayım'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Burada görünmek için önce giriş yapmalısın.');
      return;
    }

    setState(() => _busy = true);
    try {
      await SpotPresenceService.instance.checkIn(widget.spot);
      _message('90 dakika boyunca bu çekim noktasında görünürsün.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _busy = true);
    try {
      await SpotPresenceService.instance.checkOut(widget.spot.id);
      _message('Bu noktada artık görünmüyorsun.');
    } catch (e) {
      _message('Görünürlük kapatılamadı. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }
}

class _PresenceAvatar extends StatelessWidget {
  final SpotPresence item;

  const _PresenceAvatar({required this.item});

  @override
  Widget build(BuildContext context) {
    final firstLetter = item.displayName.trim().isEmpty
        ? '?'
        : item.displayName.trim().characters.first.toUpperCase();

    return SizedBox(
      width: 62,
      child: Column(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFF252C37),
            backgroundImage: item.photoUrl.isNotEmpty ? NetworkImage(item.photoUrl) : null,
            child: item.photoUrl.isEmpty
                ? Text(
                    firstLetter,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
