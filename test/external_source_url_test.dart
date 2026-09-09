import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/external_source_url.dart';
void main() {
  test('canonical source drops tracking and normalizes old X hosts', () {
    expect(externalSourceUrl('Bak https://www.instagram.com/reel/ABC/?igsh=tracking.').toString(), 'https://instagram.com/reel/ABC/');
    expect(externalSourceUrl('https://mobile.twitter.com/person/status/123?s=20').toString(), 'https://x.com/person/status/123');
  });
  test('rejects spoofed, local and credential-bearing sources', () {
    for (final value in ['https://instagram.com.evil.test/a', 'https://instagram.com@evil.test/a', 'https://u@instagram.com/a', 'https://localhost/a', 'file:///tmp/a', 'https://x.com:8443/a']) {
      expect(externalSourceUrl(value), isNull, reason: value);
    }
  });
}
