import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/photo_spot.dart';
import '../lib/widgets/route_stops_step.dart';
import '../lib/widgets/route_editor_map.dart';

PhotoSpot place(String id) => PhotoSpot(id:id,name:id,city:'',latitude:38.7,longitude:39.2,rating:0,bestTime:'',angle:'',imageUrl:'',category:'Gezi');
void main() {
 testWidgets('map-first selection keeps additions, order and removals across views', (tester) async {
  tester.view.physicalSize = const Size(430,950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final stops = [place('İlk durak')];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(context,refresh) => RouteStopsStep(
   city:'',stops:stops,initialShowMap:true,
   loadItems:(_) async => [place('İlk durak'),place('İkinci durak')],
   onAdd:(p)=>refresh(() {if(!stops.any((s)=>s.id==p.id)) stops.add(p);}),
   onRemove:(p)=>refresh(()=>stops.removeWhere((s)=>s.id==p.id)),
   onMapTap:(_){},onSuggest:(){},onSort:(){},onSearch:(){},
   onReorder:(a,b)=>refresh((){if(b>a)b--;stops.insert(b,stops.removeAt(a));}),
   stopBuilder:(i)=>ListTile(key:ValueKey(stops[i].id),title:Text(stops[i].name),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>refresh(()=>stops.removeAt(i)))),
  )))));
  await tester.pump();
  expect(find.byType(RouteEditorMap), findsOneWidget);
  await tester.tap(find.text('Listeden seç'));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('place-İkinci durak')));
  await tester.pump();
  expect(stops.map((p)=>p.id), ['İlk durak','İkinci durak']);
  await tester.tap(find.text('Haritadan seç'));
  await tester.pump();
  expect(tester.widget<RouteEditorMap>(find.byType(RouteEditorMap)).stops.map((p)=>p.id), ['İlk durak','İkinci durak']);
  await tester.tap(find.text('Seçilen duraklar · 2'));
  await tester.pump();
  tester.widget<SliverReorderableList>(find.byType(SliverReorderableList)).onReorder(0,2);
  await tester.pump();
  expect(stops.map((p)=>p.id), ['İkinci durak','İlk durak']);
  await tester.tap(find.descendant(of:find.byKey(const ValueKey('İlk durak')),matching:find.byType(IconButton)));
  await tester.pump();
  await tester.tap(find.text('Haritadan seç'));
  await tester.pump();
  expect(tester.widget<RouteEditorMap>(find.byType(RouteEditorMap)).stops.map((p)=>p.id), ['İkinci durak']);
  await tester.pumpWidget(const SizedBox());
 });
}
