import 'package:flutter/material.dart';

class TbtBrandMark extends StatelessWidget {
  final double size;
  final bool roundedBackground;

  const TbtBrandMark({
    super.key,
    this.size = 34,
    this.roundedBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/spot_thumbnails/tbt_app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    if (!roundedBackground) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
