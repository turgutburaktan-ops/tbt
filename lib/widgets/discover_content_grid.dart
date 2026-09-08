import 'package:flutter/material.dart';

import 'sponsored_native_ad.dart';

/// Keeps the first four rows entirely organic and the ad in the same scroll.
class DiscoverContentGrid extends StatelessWidget {
  const DiscoverContentGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.sponsoredCard = const SponsoredNativeAd(
      compact: true,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget sponsoredCard;

  static const _firstGroupSize = 12;
  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: 2,
    crossAxisSpacing: 2,
    childAspectRatio: .78,
  );

  Widget _group(int start, int count) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    sliver: SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => itemBuilder(context, start + index),
        childCount: count,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      _group(0, itemCount < _firstGroupSize ? itemCount : _firstGroupSize),
      if (itemCount >= _firstGroupSize)
        SliverToBoxAdapter(child: sponsoredCard),
      if (itemCount > _firstGroupSize)
        _group(_firstGroupSize, itemCount - _firstGroupSize),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ],
  );
}
