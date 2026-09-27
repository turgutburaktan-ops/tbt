import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Opens at the tapped tile and continues through every loaded Explore post.
/// Earlier tiles follow the last tile, without repeating any post.
class DiscoverPostFeed extends StatelessWidget {
  const DiscoverPostFeed({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    this.title = 'Keşfet',
  }) : assert(itemCount >= 0),
       assert(itemCount == 0 || (initialIndex >= 0 && initialIndex < itemCount));

  final String title;
  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      title: Text(title),
    ),
    body: itemCount == 0
        ? const Center(child: Text('Gösterilecek paylaşım yok.'))
        : ListView.builder(
            key: const PageStorageKey('discover-post-feed'),
            padding: const EdgeInsets.only(bottom: 24),
            cacheExtent: 0,
            addAutomaticKeepAlives: false,
            itemCount: itemCount,
            itemBuilder: (context, index) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: itemBuilder(context, (initialIndex + index) % itemCount),
              ),
            ),
          ),
  );
}
