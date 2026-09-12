import 'package:flutter_test/flutter_test.dart';

import '../lib/services/person_search_match.dart';

void main() {
  test('city alone is not a person match', () {
    expect(
      personMatchScore({
        'displayName': 'Emre Türk özmen',
        'city': 'Elazığ',
      }, 'elazığ'),
      0,
    );
  });
  test('Turkish spelling and handles match', () {
    expect(
      personMatchScore({'displayName': 'İlker Şahin'}, 'ilker sahin'),
      greaterThan(0),
    );
    expect(
      personMatchScore({'username': '@emreturkozmen'}, '@emre'),
      greaterThan(0),
    );
  });
  test('exact names precede partial matches', () {
    expect(
      personMatchScore({'displayName': 'Emre'}, 'emre'),
      greaterThan(personMatchScore({'displayName': 'Emre Tan'}, 'emre')),
    );
    expect(personMatchScore({'displayName': 'Emre'}, ''), 0);
  });
}
