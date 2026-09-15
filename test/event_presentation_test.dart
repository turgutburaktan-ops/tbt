import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/event_presentation.dart';
void main() {
  test('event dates identify today, tomorrow and year rollover clearly', () {
    final now = DateTime(2026,12,31,22);
    expect(eventStartLabel(DateTime(2026,12,31,23,5),now:now),'Bugün 23:05');
    expect(eventStartLabel(DateTime(2027,1,1,0,15),now:now),'Yarın 00:15');
    expect(eventStartLabel(DateTime(2027,1,2,13,30),now:now),'2.1.2027 13:30');
  });
}
