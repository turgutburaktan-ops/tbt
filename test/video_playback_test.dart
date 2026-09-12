import 'package:best_photo_spot/widgets/shared_story_video.dart';
import 'package:best_photo_spot/services/video_audio_session.dart';
import 'package:flutter/material.dart';
import 'package:best_photo_spot/widgets/expandable_caption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:best_photo_spot/widgets/app_video_player.dart';
import 'package:best_photo_spot/widgets/playback_indexed_stack.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  int next = 0;
  final playing = <int, bool>{};
  final speeds = <int, double>{};
  final volumes = <int, double>{};
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    playing[++next] = false;
    return next;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 30),
      size: const Size(1920, 1080),
    ),
  );
  @override
  Future<void> dispose(int id) async {
    playing.remove(id);
  }

  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {
    volumes[id] = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {
    speeds[id] = speed;
  }

  @override
  Future<void> play(int id) async {
    playing[id] = true;
  }

  @override
  Future<void> pause(int id) async {
    playing[id] = false;
  }

  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Widget buildView(int id) => const SizedBox.expand();
}

void main() {
  testWidgets('shared story fills the surface, plays sound and pauses with story controls', (tester) async {
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    var active = true;
    Duration? readyDuration;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return Scaffold(body: SharedStoryVideo(
        url: 'https://example.com/story-video.mp4', author: 'Original author',
        active: active, onReady: (duration) => readyDuration = duration,
      ));
    })));
    Future<void> tick() async {
      for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    }
    await tick();
    expect(find.byType(Card), findsNothing);
    expect(find.text('↗ Original author'), findsOneWidget);
    final player = tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer));
    expect(player.fit, BoxFit.cover);
    expect(player.resumePosition, false);
    expect(readyDuration, const Duration(seconds: 15));
    expect(platform.volumes.values.single, 1);
    expect(platform.playing.values.single, true);
    update(() => active = false);
    await tick();
    expect(platform.playing.values.single, false);
    update(() => active = true);
    await tick();
    expect(platform.playing.values.single, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });
  test('story duration respects short clips and the existing 15 second limit', () {
    expect(SharedStoryVideo.storyDuration(const Duration(seconds: 5)), const Duration(seconds: 5));
    expect(SharedStoryVideo.storyDuration(const Duration(seconds: 60)), const Duration(seconds: 15));
  });

  testWidgets(
    'mute and reset update existing and subsequently created video controllers',
    (tester) async {
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final audio = VideoAudioSession();
      var second = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: AppVideoPlayer.network(
                        url: 'https://example.com/shared-one.mp4',
                        autoplay: true,
                        audioSession: audio,
                      ),
                    ),
                    if (second)
                      Expanded(
                        child: AppVideoPlayer.network(
                          url: 'https://example.com/shared-two.mp4',
                          autoplay: true,
                          audioSession: audio,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      Future<void> tick() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tick();
      expect(platform.volumes.values, [1.0]);
      await tester.tap(find.byTooltip('Sesi kapat'));
      await tick();
      expect(platform.volumes.values, [0.0]);
      update(() => second = true);
      await tick();
      expect(platform.volumes.length, 2);
      expect(platform.volumes.values.every((v) => v == 0), true);
      audio.reset();
      await tick();
      expect(platform.volumes.values.every((v) => v == 1), true);
      expect(
        platform.playing.values.where((v) => v).length,
        lessThanOrEqualTo(1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      audio.dispose();
    },
  );
  testWidgets('right hold is 2x only while held; caption keeps playback', (
    tester,
  ) async {
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: AppVideoPlayer.network(
                  url: 'https://example.com/hold.mp4',
                  autoplay: true,
                  holdToSpeed: true,
                ),
              ),
              const Positioned(
                bottom: 20,
                left: 10,
                width: 200,
                child: ExpandableCaption(
                  text: 'Uzun açıklama\nİkinci açıklama satırı',
                  detailsInSheet: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void> tick() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tick();
    final id = platform.playing.keys.single;
    final gesture = await tester.startGesture(const Offset(650, 200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(platform.speeds[id], 2);
    expect(find.text('2x ▶▶'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(platform.speeds[id], 1);
    final left = await tester.startGesture(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(platform.speeds[id], 1);
    await left.up();
    await tester.tap(find.text('Devamını gör'));
    await tick();
    expect(platform.playing[id], true);
    nav.currentState!.pop();
    await tick();
    final cancelled = await tester.startGesture(const Offset(650, 200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(platform.speeds[id], 2);
    await cancelled.cancel();
    await tester.pump();
    expect(platform.speeds[id], 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
    'scrolling replaces the playing video without retaining old audio',
    (tester) async {
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scroll,
              cacheExtent: 900,
              children: const [
                SizedBox(
                  height: 600,
                  child: AppVideoPlayer.network(
                    url: 'https://example.com/scroll-one.mp4',
                    autoplay: true,
                  ),
                ),
                SizedBox(
                  height: 600,
                  child: AppVideoPlayer.network(
                    url: 'https://example.com/scroll-two.mp4',
                    autoplay: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.playing.values.where((p) => p).length, 1);
      final first = platform.playing.entries.firstWhere((p) => p.value).key;
      scroll.jumpTo(600);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.playing[first], false);
      expect(platform.playing.values.where((p) => p).length, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      scroll.dispose();
    },
  );

  testWidgets(
    'only visible tab plays; covered route and background stop playback',
    (tester) async {
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      var selected = 0;
      late StateSetter change;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Scaffold(
                body: PlaybackIndexedStack(
                  index: selected,
                  children: const [
                    AppVideoPlayer.network(
                      url: 'https://example.com/one.mp4',
                      autoplay: true,
                    ),
                    AppVideoPlayer.network(
                      url: 'https://example.com/two.mp4',
                      autoplay: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      Future<void> settleVideo() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settleVideo();
      expect(platform.playing.values.where((v) => v).length, 1);
      final first = platform.playing.entries.firstWhere((e) => e.value).key;
      change(() => selected = 1);
      await settleVideo();
      expect(platform.playing[first], false);
      expect(platform.playing.values.where((v) => v).length, 1);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Başka ekran')),
        ),
      );
      await settleVideo();
      expect(platform.playing.values.any((v) => v), false);
      nav.currentState!.pop();
      await settleVideo();
      expect(platform.playing.values.where((v) => v).length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 200));
      expect(platform.playing.values.any((v) => v), false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}

