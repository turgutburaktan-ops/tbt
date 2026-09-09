import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/creator_service.dart';

/// Counts only a sustained, foreground view; the server deduplicates per day.
class CreatorViewTracker extends StatefulWidget {
  const CreatorViewTracker({
    super.key,
    required this.postId,
    required this.child,
  });
  final String postId;
  final Widget child;
  @override
  State<CreatorViewTracker> createState() => _CreatorViewTrackerState();
}

class _CreatorViewTrackerState extends State<CreatorViewTracker>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = false, _sent = false, _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CreatorViewTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _sent = false;
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_visible || !_active || _sent) return;
    _timer = Timer(const Duration(seconds: 1), () async {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _sent = true;
      try {
        await CreatorService.instance.publishing('view', widget.postId);
      } catch (_) {
        /* Metrics never interrupt reading. */
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: ValueKey('creator-view-${widget.postId}-${identityHashCode(this)}'),
    onVisibilityChanged: (info) {
      final visible = info.visibleFraction >= .5;
      if (visible != _visible) {
        _visible = visible;
        _schedule();
      }
    },
    child: widget.child,
  );
}
