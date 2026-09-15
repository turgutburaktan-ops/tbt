import 'package:flutter_test/flutter_test.dart';
import '../lib/l10n/app_strings.dart';

void main() {
  const keys = ['welcome', 'identifier', 'password', 'login', 'register',
    'resetPassword', 'introDiscover', 'introDiscoverBody', 'introPlan',
    'introPlanBody', 'introShare', 'introShareBody', 'dailyTitle',
    'dailyPost', 'dailyStory', 'dailyEvent', 'language', 'marketing', 'marketingBody'];
  for (final code in ['tr', 'en', 'de', 'ar']) {
    test('core strings exist in $code', () {
      final strings = AppStrings(code);
      for (final key in keys) {
        expect(strings.text(key), isNotEmpty);
        expect(strings.text(key), isNot(key));
      }
    });
  }
  test('unknown language falls back to English', () {
    expect(const AppStrings('xx').text('login'), 'Sign In');
  });
}
