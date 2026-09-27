import 'package:flutter/material.dart';
import 'discover_post_feed.dart';
import 'shared_post_card.dart';

class ProfilePostFeed extends StatelessWidget {
  const ProfilePostFeed({super.key, required this.postIds, required this.initialIndex});
  final List<String> postIds;
  final int initialIndex;

  @override
  Widget build(BuildContext context) => DiscoverPostFeed(
    title: 'Gönderiler',
    itemCount: postIds.length,
    initialIndex: initialIndex,
    itemBuilder: (_, index) => SharedPostCard(
      key: ValueKey(postIds[index]),
      postId: postIds[index],
      feedPresentation: true,
    ),
  );
}
