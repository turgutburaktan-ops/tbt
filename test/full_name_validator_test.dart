import 'package:flutter_test/flutter_test.dart';
import '../lib/services/full_name_validator.dart';

void main() {
  test('full names accept supported writing systems', () {
    for (final name in ['Turgut Burak TAN', 'Çağrı Şahin', 'أحمد محمد',
      '李 小龍', 'Anne-Marie O’Neill', 'Jose\u0301 García']) {
      expect(validFullName(name), isTrue, reason: name);
    }
  });
  test('reject missing surname, numbers, symbols and excessively long names', () {
    for (final name in ['', 'Burak', 'Test 123', 'Name <script>', '- Name', '${'a' * 80} B']) {
      expect(validFullName(name), isFalse, reason: name);
    }
  });
}
