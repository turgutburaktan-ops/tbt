import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/route_access.dart';
import '../lib/widgets/route_access_settings.dart';
void main() {
  test('all visibility and audience combinations preserve containment', () {
    for (final v in RouteAccess.labels.keys) {
      for (final a in RouteAccess.labels.keys) {
        final x = RouteAccess(visibility:v,audience:a,enabled:true);
        expect(x.compatible,RouteAccess.rank(a)<=RouteAccess.rank(v));
        expect(RouteAccess(visibility:v,audience:a).compatible,true);
      }
    }
  });
  test('legacy routes retain request approval; inviting is separate from visibility', () {
    final old=RouteAccess.fromMap({'joinEnabled':true,'visibility':'followers'});
    expect(old.audience,'followers');expect(old.approval,true);
    expect(const RouteAccess(audience:'private').fields['joinRequiresApproval'],false);
    expect(const RouteAccess(enabled:true).validate(null),isNotNull);
    expect(const RouteAccess().validate(null),isNull);
  });
  testWidgets('widening participation requires explicit visibility confirmation', (tester) async {
    var value=const RouteAccess(visibility:'private',audience:'private',enabled:true);
    final date=DateTime.now().add(const Duration(days:1));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(c,set)=>
      RouteAccessSettings(value:value,startAt:date,pickDate:()async=>date,onChanged:(v)=>set(()=>value=v))))));
    await tester.tap(find.text('Kimler katılabilir?'));await tester.pumpAndSettle();
    await tester.tap(find.text('Herkes'));await tester.pumpAndSettle();
    expect(value.visibility,'private');
    await tester.tap(find.text('Geri dön'));await tester.pumpAndSettle();
    expect(value.audience,'private');
    await tester.tap(find.text('Kimler katılabilir?'));await tester.pumpAndSettle();
    await tester.tap(find.text('Herkes'));await tester.pumpAndSettle();
    await tester.tap(find.text('Görünürlüğü Herkes yap'));await tester.pumpAndSettle();
    expect(value.visibility,'public');expect(value.audience,'public');
    expect(find.text('Katılım için onayım gereksin'),findsOneWidget);
  });
  testWidgets('cancelling required date leaves participation disabled', (tester) async {
    var value=const RouteAccess();var asked=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:RouteAccessSettings(value:value,startAt:null,
      pickDate:()async{asked=true;return null;},onChanged:(v)=>value=v))));
    await tester.tap(find.text('Katılıma aç'));await tester.pumpAndSettle();
    expect(asked,true);expect(value.enabled,false);
    expect(find.text('Katılım için onayım gereksin'),findsNothing);
  });
}
