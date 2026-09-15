import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/business_bulk_menu_screen.dart';

void main() {
  test('menu prices retain Turkish decimals without ambiguous rounding', () {
    expect(menuPriceMinor('125,50'), 12550);
    expect(menuPriceMinor('125.5'), 12550);
    expect(menuPriceMinor('0'), 0);
    for (final input in ['', '-1', '1.234', '1,234.56', 'NaN', '1000001']) {
      expect(menuPriceMinor(input), isNull, reason: input);
    }
  });
}
