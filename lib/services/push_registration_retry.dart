Future<void> retryPushRegistration({
  required Future<bool> Function() attempt,
  required bool Function() active,
  Future<void> Function(Duration)? wait,
}) async {
  final delay = wait ?? Future<void>.delayed;
  for (var index = 0; index < 5 && active(); index++) {
    try {
      if (await attempt()) return;
    } catch (_) {
      // APNs readiness, network and token writes may recover on the next attempt.
    }
    if (index < 4 && active()) {
      await delay(Duration(milliseconds: 500 * (1 << index)));
    }
  }
}
