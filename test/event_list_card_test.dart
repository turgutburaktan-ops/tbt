import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/social_event.dart';
import '../lib/widgets/event_list_card.dart';
final event = SocialEvent(id:'one',title:'Uzun başlıklı bir yürüyüş etkinliği',type:SocialEventType.walking,customTypeLabel:'',hostId:'owner',hostName:'Owner',startsAt: DateTime(2026,9,16,20,30),capacity:1,participantIds:['owner'],description:'',city:'Elazığ',locationLabel:'Kültür Park ana giriş kapısı',spotId:null,spotName:null,status:'open',approximateLocationOnly:false);
void main() {
  testWidgets('compact cards fit narrow screens with enlarged text and full hosts can open details', (tester) async {
    tester.view.physicalSize = const Size(320,900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(size: Size(320,900),textScaler: TextScaler.linear(1.6)), child: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(14), child: EventListCard(event:event, joined:true, busy:false, onOpen:()=>opened++, onJoin:(){}, icon:Icons.directions_walk)))))));
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Detayları Gör'));
    expect(opened,1);
  });
  testWidgets('full event blocks joining but retains card detail navigation', (tester) async {
    var joined = false, opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EventListCard(event:event,joined:false,busy:false,onOpen:()=>opened=true,onJoin:()=>joined=true,icon:Icons.directions_walk))));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed,isNull);
    await tester.tap(find.text(event.title));
    expect(opened,isTrue);
    expect(joined,isFalse);
  });
}
