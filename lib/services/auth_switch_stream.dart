import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Switches the active inner stream immediately when Firebase Auth changes.
/// Unlike asyncExpand with a never-ending Firestore snapshots() stream, this
/// does not wait for the previous user's stream to complete before moving on.
Stream<T> switchAuthStream<T>({
  required FirebaseAuth auth,
  required Stream<T> Function(User user) signedIn,
  required T signedOutValue,
}) {
  return Stream<T>.multi((subscriber) {
    StreamSubscription<T>? inner;
    var generation = 0;

    final authSubscription = auth.authStateChanges().listen(
      (user) {
        final currentGeneration = ++generation;
        final previous = inner;
        inner = null;
        if (previous != null) unawaited(previous.cancel());

        if (user == null) {
          subscriber.add(signedOutValue);
          return;
        }

        inner = signedIn(user).listen(
          (value) {
            if (currentGeneration == generation) subscriber.add(value);
          },
          onError: (Object error, StackTrace stack) {
            if (currentGeneration == generation) {
              subscriber.addError(error, stack);
            }
          },
        );
      },
      onError: subscriber.addError,
    );

    subscriber.onCancel = () {
      generation++;
      final currentInner = inner;
      inner = null;
      if (currentInner != null) unawaited(currentInner.cancel());
      unawaited(authSubscription.cancel());
    };
  });
}
