import 'package:flutter_test/flutter_test.dart';
import '../lib/services/app_update_policy.dart';
void main() {
 test('version comparison is numeric and rejects malformed metadata',(){
  expect(compareAppVersions('1.0.10','1.0.9'),1);
  expect(compareAppVersions('1.2','1.2.0'),0);
  expect(compareAppVersions('1.2.0','1.3.0'),-1);
  expect(compareAppVersions('1.3beta','1.2'),isNull);
  expect(compareAppVersions('','1.2'),isNull);
 });
 test('unavailable minimum build cannot force an Android upgrade',(){
  expect(requiresAndroidUpdate(59,60,61),false);
  expect(requiresAndroidUpdate(59,59,60),false);
  expect(requiresAndroidUpdate(59,61,60),true);
  expect(requiresAndroidUpdate(60,61,60),false);
  expect(requiresAndroidUpdate(59,60,0),false);
 });
 test('iOS minimum applies only when a sufficient newer store version exists',(){
  expect(requiresIosUpdate('1.0.31','1.0.32','1.0.33'),false);
  expect(requiresIosUpdate('1.0.31','1.0.33','1.0.32'),true);
  expect(requiresIosUpdate('1.0.32','1.0.33','1.0.32'),false);
  expect(requiresIosUpdate('1.0.31','1.0.33','invalid'),false);
 });
}
