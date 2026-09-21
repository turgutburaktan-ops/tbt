import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../lib/services/route_geometry.dart';
import '../lib/models/photo_spot.dart';

void main() {
  const a=LatLng(38.7,39.2), b=LatLng(38.71,39.21);
  test('manual geometry survives storage without invented travel time', () {
    final route=RouteGeometry.manual([a,b,a]);
    final restored=RouteGeometry.decode(RouteGeometry.encode(route,'test',manual:true,roundTrip:true))!;
    expect(restored.points,[a,b,a]);
    expect(restored.meters,greaterThan(2000));
    expect(restored.seconds,0);
  });
  test('reject invalid raw coordinates before LatLng clamps them', () {
    for(final bad in [91.0,double.nan,double.infinity]) {
      expect(RouteGeometry.decode({'geometry':[{'lat':bad,'lng':39},{'lat':38,'lng':39}],'legs':[]}),isNull);
    }
    expect(RouteGeometry.decode({'geometry':[{'lat':38,'lng':181},{'lat':38,'lng':39}],'legs':[]}),isNull);
  });
  test('origin and round trip affect both waypoints and saved signature', () {
    const s=PhotoSpot(id:'s',name:'S',city:'Elazığ',latitude:38.71,longitude:39.21,rating:0,bestTime:'',angle:'',imageUrl:'');
    expect(RouteGeometry.waypoints([s],origin:a,roundTrip:true),[a,b,a]);
    expect(RouteGeometry.signature([s],'Yürüyüş',origin:a),isNot(RouteGeometry.signature([s],'Yürüyüş',origin:a,roundTrip:true)));
    expect(RouteGeometry.signature([s],'Yürüyüş'),isNot(RouteGeometry.signature([s],'Bisiklet')));
  });
}
