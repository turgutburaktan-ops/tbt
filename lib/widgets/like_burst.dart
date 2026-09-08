import 'package:flutter/material.dart';

/// Animation lifetime is independent of the network request.
class LikeBurst extends StatefulWidget {
  const LikeBurst({super.key, required this.child, required this.onLike});
  final Widget child;
  final Future<void> Function() onLike;
  @override
  State<LikeBurst> createState() => _LikeBurstState();
}

class _LikeBurstState extends State<LikeBurst>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _saving = false;
  void _like() async {
    _animation.forward(from: 0);
    if (_saving) return;
    _saving = true;
    try {
      await widget.onLike();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Beğeni kaydedilemedi. Tekrar deneyebilirsin.'),
          ),
        );
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: _like,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, __) {
              final t = _animation.value;
              final opacity = t == 0 || t == 1
                  ? 0.0
                  : (t < .65 ? 1.0 : (1 - t) / .35);
              return Center(
                child: Opacity(
                  opacity: opacity.clamp(0, 1),
                  child: Transform.scale(
                    scale: t < .35
                        ? .5 + Curves.easeOutBack.transform(t / .35) * .5
                        : 1,
                    child: const Text('❤️', style: TextStyle(fontSize: 92)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
