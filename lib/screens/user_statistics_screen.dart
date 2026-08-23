import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UserStatisticsScreen extends StatefulWidget {
  final String? userId;

  const UserStatisticsScreen({super.key, this.userId});

  @override
  State<UserStatisticsScreen> createState() => _UserStatisticsScreenState();
}

class _UserStatisticsScreenState extends State<UserStatisticsScreen> {
  Future<_UserStatistics>? _future;

  String? get _userId => widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = _userId;
    _future = uid == null
        ? Future<_UserStatistics>.error('İstatistikleri görmek için giriş yapmalısın.')
        : _load(uid);
  }

  Future<_UserStatistics> _load(String uid) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));

    final results = await Future.wait<dynamic>([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(uid).collection('followers').get(),
      db.collection('users').doc(uid).collection('following').get(),
      db.collection('posts').where('userId', isEqualTo: uid).get(),
      db.collection('stories').where('userId', isEqualTo: uid).get(),
      db.collection('social_events').where('hostId', isEqualTo: uid).get(),
      db.collection('social_events').where('participantIds', arrayContains: uid).get(),
    ]);

    final profile = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final followers = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final following = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final posts = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final stories = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final hostedEvents = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final joinedEvents = results[6] as QuerySnapshot<Map<String, dynamic>>;

    var photoPosts = 0;
    var videoPosts = 0;
    var postsLast30Days = 0;
    var likesReceived = 0;
    var commentsReceived = 0;
    final uniquePostEngagers = <String>{};

    await Future.wait(posts.docs.map((post) async {
      final data = post.data();
      final mediaType = (data['mediaType'] ?? '').toString();
      final videoUrl = (data['videoUrl'] ?? '').toString();
      if (mediaType == 'video' || videoUrl.isNotEmpty) {
        videoPosts++;
      } else {
        photoPosts++;
      }

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(last30Days)) {
        postsLast30Days++;
      }

      final engagement = await Future.wait([
        post.reference.collection('likes').get(),
        post.reference.collection('comments').get(),
      ]);
      final likes = engagement[0];
      final comments = engagement[1];
      likesReceived += likes.docs.length;
      commentsReceived += comments.docs.length;
      for (final doc in likes.docs) {
        final id = (doc.data()['userId'] ?? doc.id).toString();
        if (id.isNotEmpty && id != uid) uniquePostEngagers.add(id);
      }
      for (final doc in comments.docs) {
        final id = (doc.data()['userId'] ?? '').toString();
        if (id.isNotEmpty && id != uid) uniquePostEngagers.add(id);
      }
    }));

    var storiesLast30Days = 0;
    var storyViews = 0;
    var storyLikes = 0;
    var storyReactions = 0;
    var storyReplies = 0;
    final uniqueStoryViewers = <String>{};

    await Future.wait(stories.docs.map((story) async {
      final data = story.data();
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(last30Days)) {
        storiesLast30Days++;
      }
      final interactions = await story.reference.collection('interactions').get();
      for (final interaction in interactions.docs) {
        final item = interaction.data();
        final viewerId = (item['userId'] ?? interaction.id).toString();
        if (item['viewedAt'] is Timestamp) {
          storyViews++;
          if (viewerId.isNotEmpty && viewerId != uid) uniqueStoryViewers.add(viewerId);
        }
        if (item['liked'] == true) storyLikes++;
        if ((item['reaction'] ?? '').toString().trim().isNotEmpty) storyReactions++;
        if ((item['message'] ?? '').toString().trim().isNotEmpty) storyReplies++;
      }
    }));

    var openHostedEvents = 0;
    var cancelledHostedEvents = 0;
    var totalEventParticipants = 0;
    for (final event in hostedEvents.docs) {
      final data = event.data();
      final status = (data['status'] ?? 'open').toString();
      if (status == 'cancelled') {
        cancelledHostedEvents++;
      } else {
        openHostedEvents++;
      }
      final ids = (data['participantIds'] as List? ?? const [])
          .map((e) => e.toString())
          .where((id) => id.isNotEmpty && id != uid)
          .toSet();
      totalEventParticipants += ids.length;
    }

    final hostedIds = hostedEvents.docs.map((e) => e.id).toSet();
    final attendedEvents = joinedEvents.docs.where((e) => !hostedIds.contains(e.id)).length;

    DateTime? memberSince;
    final createdAt = profile.data()?['createdAt'];
    if (createdAt is Timestamp) memberSince = createdAt.toDate();

    return _UserStatistics(
      followers: followers.docs.length,
      following: following.docs.length,
      posts: posts.docs.length,
      photoPosts: photoPosts,
      videoPosts: videoPosts,
      postsLast30Days: postsLast30Days,
      likesReceived: likesReceived,
      commentsReceived: commentsReceived,
      uniquePostEngagers: uniquePostEngagers.length,
      stories: stories.docs.length,
      storiesLast30Days: storiesLast30Days,
      storyViews: storyViews,
      uniqueStoryViewers: uniqueStoryViewers.length,
      storyLikes: storyLikes,
      storyReactions: storyReactions,
      storyReplies: storyReplies,
      hostedEvents: hostedEvents.docs.length,
      openHostedEvents: openHostedEvents,
      cancelledHostedEvents: cancelledHostedEvents,
      eventParticipants: totalEventParticipants,
      attendedEvents: attendedEvents,
      memberSince: memberSince,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İstatistikler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_UserStatistics>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              message: snapshot.error?.toString() ?? 'İstatistikler yüklenemedi.',
              onRetry: () => setState(_reload),
            );
          }
          final stats = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
              children: [
                _OverviewCard(stats: stats),
                const SizedBox(height: 14),
                _Section(
                  title: 'Sosyal',
                  icon: Icons.people_alt_outlined,
                  children: [
                    _Metric('Takipçi', stats.followers, Icons.person_add_alt_1_rounded),
                    _Metric('Takip edilen', stats.following, Icons.people_outline_rounded),
                    _Metric('Etkileşime geçen benzersiz kişi', stats.uniquePostEngagers, Icons.hub_outlined),
                  ],
                ),
                _Section(
                  title: 'Gönderiler',
                  icon: Icons.grid_on_rounded,
                  children: [
                    _Metric('Toplam gönderi', stats.posts, Icons.collections_outlined),
                    _Metric('Fotoğraf', stats.photoPosts, Icons.photo_outlined),
                    _Metric('Video', stats.videoPosts, Icons.videocam_outlined),
                    _Metric('Son 30 gün', stats.postsLast30Days, Icons.calendar_month_outlined),
                    _Metric('Alınan beğeni', stats.likesReceived, Icons.favorite_border_rounded),
                    _Metric('Alınan yorum', stats.commentsReceived, Icons.chat_bubble_outline_rounded),
                  ],
                ),
                _Section(
                  title: 'Story',
                  icon: Icons.auto_stories_outlined,
                  children: [
                    _Metric('Toplam story', stats.stories, Icons.add_circle_outline_rounded),
                    _Metric('Son 30 gün', stats.storiesLast30Days, Icons.calendar_today_outlined),
                    _Metric('Toplam görüntülenme', stats.storyViews, Icons.visibility_outlined),
                    _Metric('Benzersiz izleyici', stats.uniqueStoryViewers, Icons.group_outlined),
                    _Metric('Story beğenisi', stats.storyLikes, Icons.favorite_outline_rounded),
                    _Metric('Emoji tepkisi', stats.storyReactions, Icons.emoji_emotions_outlined),
                    _Metric('Story yanıtı', stats.storyReplies, Icons.reply_rounded),
                  ],
                ),
                _Section(
                  title: 'Etkinlikler',
                  icon: Icons.event_available_outlined,
                  children: [
                    _Metric('Oluşturulan', stats.hostedEvents, Icons.add_box_outlined),
                    _Metric('Aktif / tamamlanan', stats.openHostedEvents, Icons.event_available_outlined),
                    _Metric('İptal edilen', stats.cancelledHostedEvents, Icons.event_busy_outlined),
                    _Metric('Etkinliklerine katılan kişi', stats.eventParticipants, Icons.groups_2_outlined),
                    _Metric('Katıldığın etkinlik', stats.attendedEvents, Icons.directions_walk_rounded),
                  ],
                ),
                if (stats.memberSince != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Üyelik başlangıcı: ${_formatDate(stats.memberSince!)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Rakamlar Firebase’deki mevcut kayıtların tamamından hesaplanır. Yenile ile güncel değerleri tekrar çekebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0x52FFFFFF), fontSize: 10.5, height: 1.35),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

class _OverviewCard extends StatelessWidget {
  final _UserStatistics stats;

  const _OverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Genel görünüm', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Profilindeki sosyal hareket, içerik ve etkinlik performansı.',
            style: TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _HeroMetric(value: stats.posts, label: 'Gönderi')),
              const SizedBox(width: 8),
              Expanded(child: _HeroMetric(value: stats.likesReceived, label: 'Beğeni')),
              const SizedBox(width: 8),
              Expanded(child: _HeroMetric(value: stats.storyViews, label: 'Story izlenme')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final int value;
  final String label;

  const _HeroMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 19, color: AppColors.cyan),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.query_stats_rounded, size: 42, color: Colors.white38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _UserStatistics {
  final int followers;
  final int following;
  final int posts;
  final int photoPosts;
  final int videoPosts;
  final int postsLast30Days;
  final int likesReceived;
  final int commentsReceived;
  final int uniquePostEngagers;
  final int stories;
  final int storiesLast30Days;
  final int storyViews;
  final int uniqueStoryViewers;
  final int storyLikes;
  final int storyReactions;
  final int storyReplies;
  final int hostedEvents;
  final int openHostedEvents;
  final int cancelledHostedEvents;
  final int eventParticipants;
  final int attendedEvents;
  final DateTime? memberSince;

  const _UserStatistics({
    required this.followers,
    required this.following,
    required this.posts,
    required this.photoPosts,
    required this.videoPosts,
    required this.postsLast30Days,
    required this.likesReceived,
    required this.commentsReceived,
    required this.uniquePostEngagers,
    required this.stories,
    required this.storiesLast30Days,
    required this.storyViews,
    required this.uniqueStoryViewers,
    required this.storyLikes,
    required this.storyReactions,
    required this.storyReplies,
    required this.hostedEvents,
    required this.openHostedEvents,
    required this.cancelledHostedEvents,
    required this.eventParticipants,
    required this.attendedEvents,
    required this.memberSince,
  });
}