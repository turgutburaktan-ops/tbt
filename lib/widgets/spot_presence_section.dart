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
    return StreamBuilder<User?>(
      stream: SpotPresenceService.instance.authChanges,
      initialData: SpotPresenceService.instance.currentUser,
      builder: (context, authSnapshot) {
        final currentUser = authSnapshot.data;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF11181D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: StreamBuilder<List<SpotPresence>>(
            stream: SpotPresenceService.instance
                .watchVisibleForSpot(widget.spot.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <SpotPresence>[];
              final isVisible = currentUser != null &&
                  items.any((item) => item.userId == currentUser.uid);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          color: Color(0xFF16B8A6)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Şu anda burada',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Yalnızca görünür olmayı seçen kullanıcılar gösterilir.',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x228B5CF6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(
                            color: Color(0xFF16B8A6),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (snapshot.hasError)
                    _StatusMessage(
                      icon: Icons.cloud_off_outlined,
                      text: _readableStreamError(snapshot.error),
                    )
                  else if (items.isEmpty)
                    const _StatusMessage(
                      icon: Icons.location_on_outlined,
                      text:
                          'Şu an görünür olan kimse yok. İstersen ilk sen görünür olabilirsin.',
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
                  if (currentUser == null) ...[
                    const _StatusMessage(
                      icon: Icons.lock_outline,
                      text:
                          'Buradayım özelliğini kullanmak için giriş yapmalısın. Diğer kullanıcıların görünürlüğü yalnızca yaklaşık çekim noktası seviyesindedir.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Kesin konum paylaşılmaz. Görünürlük 90 dakika sonra otomatik kapanır.',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                              height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isVisible)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _checkOut,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.visibility_off_outlined,
                                  size: 18),
                          label: const Text('Gizlen'),
                        )
                      else
                        FilledButton.icon(
                          onPressed:
                              _busy || currentUser == null ? null : _checkIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16B8A6),
                            foregroundColor: Colors.black,
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Buradayım'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _checkIn() async {
    if (SpotPresenceService.instance.currentUser == null) {
      _message('Burada görünmek için önce giriş yapmalısın.');
      return;
    }

    setState(() => _busy = true);
    try {
      await SpotPresenceService.instance.checkIn(widget.spot);
      _message('Buradasın. 90 dakika boyunca bu çekim noktasında görünürsün.');
    } catch (e) {
      _message(_cleanError(e));
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
      _message(_cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'İşlem tamamlanamadı. Tekrar deneyebilirsin.' : text;
  }

  String _readableStreamError(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (text.contains('permission-denied')) {
      return 'Buradaki kullanıcılar için Firestore okuma izni alınamadı. Oturumunu yenileyip tekrar deneyebilirsin.';
    }
    if (text.contains('unavailable')) {
      return 'Buradaki kullanıcılar şu anda yüklenemiyor. İnternet bağlantını kontrol et.';
    }
    return 'Buradaki kullanıcılar şu anda yüklenemiyor. Biraz sonra tekrar deneyebilirsin.';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatusMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white70, height: 1.4, fontSize: 12.5),
            ),
          ),
        ],
      ),
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
            backgroundImage:
                item.photoUrl.isNotEmpty ? NetworkImage(item.photoUrl) : null,
            child: item.photoUrl.isEmpty
                ? Text(
                    firstLetter,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Colors.white),
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
