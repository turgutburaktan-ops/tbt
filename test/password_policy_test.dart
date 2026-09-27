import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/password_policy.dart';
import '../lib/screens/password_change_screen.dart';
import '../lib/widgets/change_password_sheet.dart';

void main() {
 test('registration requirements retain Turkish letters and reject short or incomplete passwords',(){
  expect(PasswordPolicy.accepts('Abcdefg1!'),false);
  expect(PasswordPolicy.accepts('Abcdefgh1!'),true);
  expect(PasswordPolicy.accepts('Şçğıöüab1!'),true);
  for(final value in ['abcdefgh1!','ABCDEFGH1!','Abcdefghi!','Abcdefghi1']) {
   expect(PasswordPolicy.accepts(value),false, reason:value);
  }
 });
 for(final sheet in [true,false]) {
  testWidgets('${sheet ? 'sheet' : 'screen'} rejects invalid new passwords before contacting authentication', (tester) async {
   tester.view.physicalSize=const Size(430,1000);
   tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   await tester.pumpWidget(MaterialApp(home: sheet
    ? const Scaffold(body:ChangePasswordSheet(email:'example@example.com'))
    : const PasswordChangeScreen(email:'example@example.com')));
   final fields=find.byType(TextField);
   await tester.enterText(fields.at(0),'oldpass');
   for(final value in ['Abcdefg1!','abcdefghij']) {
    await tester.enterText(fields.at(1),value);
    await tester.enterText(fields.at(2),value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text(PasswordPolicy.message),findsOneWidget);
   }
   await tester.pumpWidget(const SizedBox());
  });
 }
}
