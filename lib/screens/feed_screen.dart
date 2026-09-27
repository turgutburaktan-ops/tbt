import '../widgets/feed_post_card.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_name_link.dart';
import '../services/video_audio_session.dart';
import '../widgets/shared_post_card.dart';
import '../widgets/creator_view_tracker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../models/travel_plan.dart';
import '../services/social_event_service.dart';
import '../services/social_service.dart';
import '../widgets/content_engagement_bar.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/sponsored_native_ad.dart';
import 'social_events_screen.dart';
import 'travel_plan_detail_screen.dart';
import 'user_profile_screen.dart';

enum FeedMode { forYou, following }

class FeedScreen extends StatefulWidget {
  final FeedMode mode;
  final bool embedded;
  final bool includeEvents;
  const FeedScreen({
    super.key,
    this.mode = FeedMode.forYou,
    this.embedded = false,
    this.includeEvents = true,
  });
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with RouteAware {
  PageRoute<dynamic>? _observedRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _observedRoute) {
      videoRouteObserver.unsubscribe(this);
      _observedRoute = route;
      videoRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    VideoAudioSession.feed.reset();
  }

  @override
  void dispose() {
    videoRouteObserver.unsubscribe(this);
    super.dispose();
  }

  late final _query = FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(120);
  late Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream = _query
      .snapshots();
  late final _repostsStream = FirebaseFirestore.instance
      .collection('post_reposts')
      .orderBy('createdAt', descending: true)
      .limit(120)
      .snapshots();
  late final _followingStream = SocialService.instance.followingIds();
  late final _eventsStream = SocialEventService.instance.watchUpcoming(
    limit: 50,
  );
  QuerySnapshot<Map<String, dynamic>>? _refreshSnapshot;
  int _refreshVersion = 0;

  Future<void> _refresh() async {
    try {
      final snapshot = await _query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _refreshSnapshot = snapshot;
        _refreshVersion++;
        _postsStream = _query.snapshots();
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akış yenilenemedi. Bağlantını kontrol edip tekrar dene.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final body = currentUser == null
        ? const _SignedOutFeed()
        : StreamBuilder<List<String>>(
            stream: _followingStream,
            builder: (context, followingSnapshot) {
              if (followingSnapshot.connectionState == ConnectionState.waiting)
                return const _FeedLoading();
              final followingIds = followingSnapshot.data ?? <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey(_refreshVersion),
                stream: _postsStream,
                initialData: _refreshSnapshot,
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !postsSnapshot.hasData)
                    return const _FeedLoading();
                  if (postsSnapshot.hasError)
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          'Akış yüklenemedi.\n${postsSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _repostsStream,
                    builder: (context, repostSnapshot) {
                      final docs = [
                        ...?postsSnapshot.data?.docs,
                        ...?repostSnapshot.data?.docs,
                      ];
                      docs.sort((a, b) {
                        final at = a.data()['createdAt'],
                            bt = b.data()['createdAt'];
                        if (at is Timestamp && bt is Timestamp)
                          return bt.compareTo(at);
                        return a.id.compareTo(b.id);
                      });
                      docs.removeWhere(
                        (doc) => doc.data()['accountFrozen'] == true,
                      );
                      if (widget.mode == FeedMode.following) {
                        docs.removeWhere((doc) {
                          final owner = (doc.data()['userId'] ?? '').toString();
                          return owner != currentUser.uid &&
                              !followingIds.contains(owner);
                        });
                      }
                      // The server query is newest-first. Following has its own tab;
                      // older followed posts must not bury newly published posts.
                      return StreamBuilder<List<SocialEvent>>(
                        stream: _eventsStream,
                        builder: (context, eventsSnapshot) {
                          final now = DateTime.now();
                          final events =
                              (widget.includeEvents
                                      ? eventsSnapshot.data ??
                                            const <SocialEvent>[]
                                      : const <SocialEvent>[])
                                  .where((event) {
                                    final visible =
                                        event.visibility ==
                                            EventVisibility.public ||
                                        event.hostId == currentUser.uid ||
                                        event.participantIds.contains(
                                          currentUser.uid,
                                        ) ||
                                        event.allowedUserIds.contains(
                                          currentUser.uid,
                                        );
                                    if (!visible) return false;
                                    if (widget.mode == FeedMode.following &&
                                        !(followingIds.contains(event.hostId) ||
                                            event.participantIds.any(
                                              followingIds.contains,
                                            )))
                                      return false;
                                    return true;
                                  })
                                  .toList()
                                ..sort(
                                  (a, b) => a.startsAt.compareTo(b.startsAt),
                                );
                          final tonight = events
                              .where((event) {
                                final d = event.startsAt.toLocal();
                                return d.year == now.year &&
                                    d.month == now.month &&
                                    d.day == now.day;
                              })
                              .take(6)
                              .toList();
                          final items = <Widget>[];
                          if (widget.mode == FeedMode.forYou &&
                              tonight.isNotEmpty)
                            items.add(
                              _TonightStrip(
                                events: tonight,
                                followingIds: followingIds,
                              ),
                            );
                          var eventIndex = 0;
                          for (var i = 0; i < docs.length; i++) {
                            final doc = docs[i], data = doc.data();
                            final mediaType = (data['mediaType'] ?? '').toString();
                            final cardIndex = items.length;
                            final isRepost =
                                doc.reference.parent.id == 'post_reposts';
                            if (isRepost) {
                              items.add(
                                SharedPostCard(
                                  key: ValueKey('repost-${doc.id}'),
                                  postId: data['postId'].toString(),
                                  repostId: doc.id,
                                ),
                              );
                            } else if (mediaType == 'route') {
                              items.add(
                                _FeedRouteCard(postId: doc.id, data: data),
                              );
                            } else {
                              items.add(
                                FeedPostCard.fromPost(
                                  key: ValueKey(doc.id),
                                  postId: doc.id,
                                  data: data,
                                ),
                              );
                            }
                            if (!isRepost)
                              items[cardIndex] = CreatorViewTracker(
                                key: ValueKey('view-${doc.reference.path}'),
                                postId: isRepost
                                    ? data['postId'].toString()
                                    : doc.id,
                                child: items[cardIndex],
                              );
                            if (i == 5 || (i > 5 && (i - 5) % 10 == 0))
                              items.add(
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: SponsoredNativeAd(),
                                ),
                              );
                            if ((i + 1) % 4 == 0 && eventIndex < events.length)
                              items.add(
                                _EventFeedCard(
                                  event: events[eventIndex++],
                                  followingIds: followingIds,
                                ),
                              );
                          }
                          while (eventIndex < events.length &&
                              items.length < 10)
                            items.add(
                              _EventFeedCard(
                                event: events[eventIndex++],
                                followingIds: followingIds,
                              ),
                            );
                          if (docs.isEmpty && events.isEmpty)
                            items.add(_EmptyFeed(mode: widget.mode));
                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: items.length,
                              itemBuilder: (_, i) => items[i],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.mode == FeedMode.following ? 'Takip' : 'Sana Özel'),
      ),
      body: body,
    );
  }
}

class _TonightStrip extends StatelessWidget {
  final List<SocialEvent> events;
  final List<String> followingIds;
  const _TonightStrip({required this.events, required this.followingIds});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 0, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Bu Akşam 🔥',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SocialEventsScreen()),
                ),
                child: const Text('Tümünü gör'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (_, i) => SizedBox(
              width: 230,
              child: _CompactEventCard(
                event: events[i],
                followingIds: followingIds,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CompactEventCard extends StatelessWidget {
  final List<String> followingIds;
  final SocialEvent event;
  const _CompactEventCard({required this.event, required this.followingIds});
  @override
  Widget build(BuildContext context) {
    final friendCount = event.participantIds
        .where(followingIds.contains)
        .length;
    final local = event.startsAt.toLocal(),
        time =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              const Icon(
                Icons.groups_2_outlined,
                size: 16,
                color: Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                '${event.participantCount}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            event.locationLabel.isNotEmpty ? event.locationLabel : event.city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const Spacer(),
          if (friendCount > 0)
            Text(
              '$friendCount takip ettiğin kişi katılıyor',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _EventFeedCard extends StatelessWidget {
  final SocialEvent event;
  final List<String> followingIds;
  const _EventFeedCard({required this.event, required this.followingIds});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joined = uid != null && event.participantIds.contains(uid);
    final local = event.startsAt.toLocal(),
        date =
            '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    Future<void> join() async {
      try {
        await SocialEventService.instance.join(event.id);
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '$date  •  ${event.locationLabel.isNotEmpty ? event.locationLabel : event.city}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SocialEventsScreen()),
                ),
                child: const Text('Etkinliği Gör'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: joined || event.isFull ? null : join,
                child: Text(
                  joined
                      ? 'Katıldın'
                      : event.isFull
                      ? 'Dolu'
                      : 'Katıl',
                ),
              ),
            ],
          ),
          ContentEngagementBar(
            collection: 'social_events',
            contentId: event.id,
            ownerId: event.hostId,
            title: event.title,
            sourceType: 'social_event',
          ),
        ],
      ),
    );
  }
}

class _SignedOutFeed extends StatelessWidget {
  const _SignedOutFeed();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Sosyal akış için giriş yap'));
}

class _EmptyFeed extends StatelessWidget {
  final FeedMode mode;
  const _EmptyFeed({required this.mode});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Text(
      mode == FeedMode.following
          ? 'Takip akışın henüz sakin'
          : 'Henüz paylaşım yok',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
    ),
  );
}

class _FeedRouteCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  const _FeedRouteCard({required this.postId, required this.data});

  Future<void> _open(BuildContext context) async {
    final planId = (data['travelPlanId'] ?? '').toString();
    if (planId.isEmpty) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('travel_plans')
        .doc(planId)
        .get();
    if (!context.mounted) return;
    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu rota artık kullanılamıyor.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TravelPlanDetailScreen(plan: TravelPlan.fromDoc(snapshot)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = (data['userId'] ?? '').toString();
    final title = (data['routeTitle'] ?? 'Gezi rotası').toString();
    final city = (data['routeCity'] ?? '').toString();
    final stops = (data['routeSpotNames'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.route_rounded)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ProfileNameLink(
                        userId: (data['userId'] ?? '').toString(),
                        compact: true,
                        child: Text(
                          (data['userName'] ?? 'TBT kullanıcısı').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$city • ${stops.length} durak • ${data['routeDurationHours'] ?? 0} saat',
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 14),
                for (final entry in stops.take(3).toList().asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${entry.key + 1}. ${entry.value}'),
                  ),
                if (stops.length > 3)
                  Text(
                    '+${stops.length - 3} durak daha',
                    style: const TextStyle(color: Colors.white54),
                  ),
                if ((data['guideNote'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ProfileNameLink(
                      userId: (data['userId'] ?? '').toString(),
                      compact: true,
                      child: Text(
                        '“${data['guideNote']}” — ${data['userName'] ?? ''}',
                      ),
                    ),
                  ),
                ContentEngagementBar(
                  collection: 'posts',
                  contentId: postId,
                  ownerId: ownerId,
                  title: title,
                  sourceType: 'route',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: 3,
    itemBuilder: (_, __) => const SizedBox(
      height: 420,
      child: ColoredBox(color: AppColors.surface),
    ),
  );
}
