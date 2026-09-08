import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:best_photo_spot/widgets/app_video_player.dart';
import 'package:best_photo_spot/widgets/playback_indexed_stack.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  int next = 0;
  final playing = <int, bool>{};
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
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
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
