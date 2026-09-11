import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/models/photo_spot.dart';
import 'package:best_photo_spot/models/nearby_venue.dart';
import 'package:best_photo_spot/services/day_plan_engine.dart';

DayPlanRequest request({String city='Elazığ',String transport='Yürüyüş',int minutes=180,int budget=600,String company='Arkadaşlarla',int people=2})=>DayPlanRequest(city:city,transport:transport,company:company,mood:'Karışık',minutes:minutes,people:people,budgetPerPerson:budget,latitude:38.6748,longitude:39.2225,startAt:DateTime(2026,9,12,12));
DayPlanStop stop(String id,{String city='Elazığ',double lat=38.677,double lon=39.223,int stay=45,int? price,NearbyVenue? venue})=>DayPlanStop(spot:PhotoSpot(id:id,name:id,city:city,latitude:lat,longitude:lon,rating:4,bestTime:'',angle:'',imageUrl:''),stayMinutes:stay,minimumPriceMinor:price,venue:venue);
void main(){
  test('short walks include travel, visits and return within the available time',(){
    final plans=DayPlanEngine.build(request(minutes:60),[stop('near',stay:35),stop('far',lat:38.9,stay:35)]);
    expect(plans,isNotEmpty);
    for(final p in plans){expect(p.totalMinutes,lessThanOrEqualTo(60));expect(p.travelMinutes,greaterThan(0));expect(p.stops.map((s)=>s.spot.id),isNot(contains('far')));}
  });
  test('national cities work and never mix selected city with another city',(){
    final plans=DayPlanEngine.build(request(city:'ANKARA'),[stop('ankara',city:'Ankara'),stop('elazig')]);
    expect(plans.single.stops.single.spot.id,'ankara');
    expect(foldDayCity('İSTANBUL'),foldDayCity('istanbul'));
    expect(foldDayCity('Elazığ'),foldDayCity('ELAZIG'));
  });
  test('known price floors above budget are excluded, unknown prices stay unknown',(){
    final plans=DayPlanEngine.build(request(budget:100),[stop('too-expensive',price:10100),stop('unknown'),stop('known',price:8000)]);
    expect(plans,isNotEmpty);
    for(final p in plans){expect(p.minimumPriceMinor,lessThanOrEqualTo(10000));expect(p.stops.map((s)=>s.spot.id),isNot(contains('too-expensive')));}
    expect(plans.first.stops.firstWhere((s)=>s.spot.id=='unknown').minimumPriceMinor,isNull);
  });
  test('invalid coordinates, wrong cities, negative prices and duplicate IDs cannot enter routes',(){
    final plans=DayPlanEngine.build(request(),[stop('ok'),stop('ok'),stop('bad',lat:double.nan),stop('bad2',lat:0,lon:0),stop('negative',price:-1),stop('other',city:'İzmir')]);
    expect(plans.single.stops.length,1);expect(plans.single.stops.single.spot.id,'ok');
  });
  test('walking and driving produce different feasible reach',(){
    final distant=stop('distant',lat:38.75,stay:30);
    expect(DayPlanEngine.build(request(minutes:60),[distant]),isEmpty);
    expect(DayPlanEngine.build(request(minutes:60,transport:'Araç'),[distant]),isNotEmpty);
  });
  test('family pace and large groups cannot make an itinerary faster',(){
    final stops=[stop('a',stay:40),stop('b',lat:38.678,stay:40)];
    final alone=DayPlanEngine.build(request(company:'Tek başıma',people:1),stops).first;
    final family=DayPlanEngine.build(request(company:'Aile',people:6),stops).first;
    expect(family.totalMinutes,greaterThan(alone.totalMinutes));
  });
  test('two alternatives have different stop sets, not merely reversed order',(){
    final plans=DayPlanEngine.build(request(minutes:70),[stop('a'),stop('b',lat:38.6775),stop('c',lat:38.678)]);
    expect(plans.length,2);
    expect(plans[0].stops.map((s)=>s.id).toSet(),isNot(equals(plans[1].stops.map((s)=>s.id).toSet())));
  });
  test('a single feasible route is not duplicated to fake two options',(){
    expect(DayPlanEngine.build(request(),[stop('only')]).length,1);
    expect(DayPlanEngine.build(request(),[]),isEmpty);
  });
  test('zero budget does not mark an unknown-cost stop as free',(){
    final plan=DayPlanEngine.build(request(budget:0),[stop('unknown')]).single;
    expect(plan.stops.single.minimumPriceMinor,isNull);
    expect(plan.stops.single.priceNote,contains('teyit'));
  });
  test('map route has an explicit start and return with distinct IDs',(){
    final stops=dayPlanRouteStops([stop('a').spot],38.67,39.22,'Elazığ');
    expect(stops.length,3);expect(stops.first.latitude,stops.last.latitude);
    expect(stops.first.longitude,stops.last.longitude);expect(stops.first.id,isNot(stops.last.id));
  });
}
