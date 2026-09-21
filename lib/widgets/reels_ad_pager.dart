import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/reels_ad_loader.dart';

/// Ads are inserted only ahead of a settled page, never into a swipe in flight.
/// At most one ad is requested/retained. Past ads are removed with the current
/// video anchored, so back-swiping cannot land on a disposed or empty ad page.
class ReelsAdPager extends StatefulWidget {
  final List<String> videoIds;
  final Widget Function(BuildContext, int, bool) videoBuilder;
  final ReelsAdLoader adLoader;
  final double topInset;
  const ReelsAdPager({super.key, required this.videoIds,
    required this.videoBuilder, this.adLoader = loadReelsAd, this.topInset = 64});
  @override
  State<ReelsAdPager> createState() => _ReelsAdPagerState();
}

class _ReelsAdPagerState extends State<ReelsAdPager> with WidgetsBindingObserver {
  final _pages = PageController();
  late final Key _visibilityKey = UniqueKey();
  ReelsAdHandle? _ad;
  Timer? _expiry;
  int? _adIndex;
  int _page = 0, _nextBoundary = 5, _attemptedBoundary = -1, _generation = 0;
  bool _loading = false, _scrolling = false, _seenAd = false, _expired = false;
  bool _visible = false, _foreground = true, _enabled = false, _fitsAd = false;

  int _videoIndex(int page) => page - (_adIndex != null && page > _adIndex! ? 1 : 0);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _syncEnabled(); });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncEnabled();
  }
  void _syncEnabled() {
    if (!mounted) return;
    final enabled = _visible && _foreground && TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (_enabled == enabled) return;
    setState(() => _enabled = enabled);
    if (!enabled) {
      _generation++;
      _removeAd();
    } else {
      _settle();
    }
  }
  @override
  void didUpdateWidget(ReelsAdPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.videoIds, widget.videoIds)) return;
    final oldIndex = oldWidget.videoIds.isEmpty ? 0 : _videoIndex(_page).clamp(0, oldWidget.videoIds.length - 1);
    final anchor = oldWidget.videoIds.isEmpty ? null : oldWidget.videoIds[oldIndex];
    final index = anchor == null ? 0 : widget.videoIds.indexOf(anchor);
    _generation++;
    _releaseAd();
    _page = index < 0 ? 0 : index;
    _nextBoundary = 5;
    while (_nextBoundary <= _page) { _nextBoundary += 8; }
    _attemptedBoundary = -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pages.hasClients) _pages.jumpToPage(_page);
      _settle();
    });
  }
  void _releaseAd() {
    _expiry?.cancel();
    _expiry = null;
    final old = _ad;
    _ad = null;
    _adIndex = null;
    _seenAd = false;
    _expired = false;
    // Let AdWidget leave the tree before releasing its platform view.
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }
  void _removeAd() {
    final index = widget.videoIds.isEmpty ? 0 : _videoIndex(_page).clamp(0, widget.videoIds.length - 1);
    final hadSlot = _adIndex != null;
    setState(() {
      _releaseAd();
      _page = index;
    });
    if (hadSlot && _pages.hasClients) _pages.jumpToPage(index);
  }
  void _settle() {
    if (!mounted || _scrolling || widget.videoIds.isEmpty) return;
    if (_expired) _removeAd();
    if (_adIndex != null) {
      if (_page == _adIndex) { _seenAd = true; return; }
      if (_seenAd || _page > _adIndex! || _page < _adIndex! - 1) _removeAd();
    }
    if (!_enabled || !_fitsAd) return;
    final watched = _videoIndex(_page) + 1;
    while (_nextBoundary < watched) { _nextBoundary += 8; }
    if (_adIndex == null && _ad != null && watched == _nextBoundary && watched < widget.videoIds.length) {
      setState(() {
        _adIndex = watched;
        _nextBoundary += 8;
      });
      return;
    }
    if (_ad == null && !_loading && _nextBoundary < widget.videoIds.length &&
        watched >= _nextBoundary - 2 && _attemptedBoundary != _nextBoundary) {
      _attemptedBoundary = _nextBoundary;
      unawaited(_load());
    }
  }
  Future<void> _load() async {
    _loading = true;
    final generation = _generation;
    ReelsAdHandle? ad;
    try { ad = await widget.adLoader(); } catch (_) { /* No-fill must not block the feed. */ }
    _loading = false;
    if (!mounted || generation != _generation || !_enabled || !_fitsAd) {
      ad?.dispose();
      return;
    }
    if (ad != null) {
      setState(() => _ad = ad);
      _expiry = Timer(const Duration(minutes: 1), () {
        if (!mounted || _seenAd) return;
        // Never change page indices during a gesture. Mark it for removal at rest.
        _expired = true;
        if (!_scrolling) _removeAd();
      });
    }
    _settle();
  }
  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    _ad?.dispose();
    _pages.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (widget.videoIds.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      // Keep the SDK media and CTA usable even in split-screen/landscape.
      final fitsAd = constraints.maxWidth >= 240 &&
          constraints.maxHeight - widget.topInset - MediaQuery.paddingOf(context).vertical - 40 >= 460;
      if (_fitsAd != fitsAd) {
        _fitsAd = fitsAd;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_fitsAd) { _generation++; _removeAd(); }
          else { _settle(); }
        });
      }
      return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) { _visible = info.visibleFraction > .5; _syncEnabled(); },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is ScrollStartNotification) _scrolling = true;
          if (notification is ScrollEndNotification) {
            _scrolling = false;
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _settle(); });
          }
          return false;
        },
        child: PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          itemCount: widget.videoIds.length + (_adIndex == null ? 0 : 1),
          onPageChanged: (index) {
            setState(() { _page = index; if (index == _adIndex) _seenAd = true; });
          },
          itemBuilder: (context, index) {
            if (index == _adIndex) {
              return ColoredBox(
                key: ObjectKey(_ad), color: Colors.black,
                child: SafeArea(child: Padding(
                  padding: EdgeInsets.fromLTRB(12, widget.topInset, 12, 16),
                  child: Column(children: [
                    Expanded(child: _enabled && index == _page
                        ? _ad!.view() : const SizedBox.expand()),
                    const SizedBox(height: 10),
                    const Text('Devam etmek için yukarı kaydır', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                )),
              );
            }
            final videoIndex = _videoIndex(index);
            return KeyedSubtree(key: ValueKey(widget.videoIds[videoIndex]),
              child: widget.videoBuilder(context, videoIndex, _enabled && index == _page));
          },
        ),
      ),
    );
    });
  }
}
