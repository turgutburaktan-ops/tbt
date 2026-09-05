import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/widgets/daily_goals_prompt.dart';

void main() {
  test('daily goals roll over at Turkey midnight', () {
    expect(dailyGoalsDayKey(DateTime.utc(2026, 9, 5, 20, 59)), '20260905');
    expect(dailyGoalsDayKey(DateTime.utc(2026, 9, 5, 21)), '20260906');
  });
  test('daily goals handle the year boundary', () {
    expect(dailyGoalsDayKey(DateTime.utc(2026, 12, 31, 21)), '20270101');
  });
}
