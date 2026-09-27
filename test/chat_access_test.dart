import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/chat_history_filter.dart';
import '../lib/widgets/chat_delete_action.dart';

void main() {
  test('deletion hides old history but allows later and pending messages', () {
    final cutoff = DateTime(2026, 9, 12);
    expect(visibleAfterChatDeletion(cutoff, cutoff), isFalse);
    expect(visibleAfterChatDeletion(cutoff.subtract(const Duration(seconds: 1)), cutoff), isFalse);
    expect(visibleAfterChatDeletion(cutoff.add(const Duration(seconds: 1)), cutoff), isTrue);
    expect(visibleAfterChatDeletion(null, cutoff), isFalse);
    expect(visibleAfterChatDeletion(null, cutoff, pending: true), isTrue);
    expect(visibleAfterChatDeletion(cutoff, null), isTrue);
  });

  test('preferences load before history and both subscriptions cancel', () async {
    var firstCancelled = false;
    var secondCancelled = false;
    final first = StreamController<int>(onCancel: () => firstCancelled = true);
    final second = StreamController<int>(onCancel: () => secondCancelled = true);
    final results = <int>[];
    final sub = combineChatSnapshots(first.stream, second.stream,
        (int a, int b) => a + b).listen(results.add);
    first.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(results, isEmpty);
    second.add(2);
    await Future<void>.delayed(Duration.zero);
    second.add(4);
    await Future<void>.delayed(Duration.zero);
    expect(results, [3, 5]);
    await sub.cancel();
    expect(firstCancelled && secondCancelled, isTrue);
    await first.close();
    await second.close();
  });

  testWidgets('visible menu requires confirmation before deleting', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => ChatDeleteAction(onDelete: () async {
        deleted = await confirmChatDeletion(context);
      })),
    )));
    for (final confirm in [false, true]) {
      await tester.tap(find.byTooltip('Sohbet seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sohbeti sil'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      expect(find.textContaining('yalnızca senin ekranından'), findsOneWidget);
      await tester.tap(find.text(confirm ? 'Sohbeti sil' : 'Vazgeç'));
      await tester.pumpAndSettle();
      expect(deleted, confirm);
    }
  });
}
