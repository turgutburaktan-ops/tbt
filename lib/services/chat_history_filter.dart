import 'dart:async';

// Wait for both snapshots so deleted history never flashes while preferences load.
Stream<R> combineChatSnapshots<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  late A a;
  late B b;
  var hasA = false;
  var hasB = false;
  void emit() {
    if (hasA && hasB) controller.add(combine(a, b));
  }
  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen((value) {
        a = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      secondSub = second.listen((value) {
        b = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );
  return controller.stream;
}

bool visibleAfterChatDeletion(DateTime? createdAt, DateTime? deletedAt,
    {bool pending = false}) {
  return deletedAt == null ||
      (createdAt == null ? pending : createdAt.isAfter(deletedAt));
}
