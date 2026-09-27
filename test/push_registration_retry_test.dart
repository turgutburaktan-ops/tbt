import 'package:flutter_test/flutter_test.dart';
import '../lib/services/push_registration_retry.dart';

void main() {
  test('late APNs or failed token write retries until registered', () async {
    var attempts = 0;
    final delays = <Duration>[];
    await retryPushRegistration(active: () => true, attempt: () async {
      attempts++;
      if (attempts == 1) return false;
      if (attempts == 2) throw StateError('network temporarily unavailable');
      return true;
    }, wait: (delay) async { delays.add(delay); });
    expect(attempts, 3);
    expect(delays, [const Duration(milliseconds: 500), const Duration(seconds: 1)]);
  });

  test('logout or disposal cancels the next registration attempt', () async {
    var active = true;
    var attempts = 0;
    await retryPushRegistration(active: () => active,
      attempt: () async { attempts++; return false; },
      wait: (_) async { active = false; });
    expect(attempts, 1);
  });

  test('bounded failure allows a later resume to try again', () async {
    var attempts = 0;
    Future<bool> attempt() async { attempts++; return attempts > 5; }
    await retryPushRegistration(active: () => true, attempt: attempt, wait: (_) async {});
    expect(attempts, 5);
    await retryPushRegistration(active: () => true, attempt: attempt, wait: (_) async {});
    expect(attempts, 6);
  });
}
