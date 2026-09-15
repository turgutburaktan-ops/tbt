import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import '../models/social_event.dart';
import 'day_plan_engine.dart';
import 'nearby_venue_service.dart';

class DayPlanData {
  final List<DayPlanStop> stops;
  final List<SocialEvent> events;
  final List<String> notices;
  const DayPlanData(this.stops, this.events, this.notices);
}
class DayPlanService {
  static Future<DayPlanData> load(DayPlanRequest request, List<PhotoSpot> allSpots) async {
    final notices = <String>[];
    final stops = allSpots.where((p) => foldDayCity(p.city) == foldDayCity(request.city))
      .map((p) => DayPlanStop(spot:p)).toList();
    final groups = await Future.wait([NearbyVenueCategory.cafe, NearbyVenueCategory.dining].map((category) async {
      try {
        return await NearbyVenueService.instance.nearby(category:category, latitude:request.latitude, longitude:request.longitude,
          radiusMeters: request.transport == 'Yürüyüş' ? 5000 : 25000, useSelectedCity:false).timeout(const Duration(seconds:14));
      } catch (_) { notices.add('${category.label} bilgileri yenilenemedi; kayıtlı gezilecek yerlerle devam edebilirsin.'); return <NearbyVenue>[]; }
    }));
    final venues = groups.expand((g)=>g).where((v)=>DayPlanEngine.coordinates(v.latitude,v.longitude)).toList()
      ..sort((a,b)=>DayPlanEngine.distance(request.latitude,request.longitude,a.latitude,a.longitude)
        .compareTo(DayPlanEngine.distance(request.latitude,request.longitude,b.latitude,b.longitude)));
    final nearest = venues.take(12).toList();
    for (var offset=0;offset<nearest.length;offset+=4) {
      final chunk=nearest.skip(offset).take(4);
      stops.addAll(await Future.wait(chunk.map((v) async {
        int? floor;
        String note='Fiyat bilgisi teyit edilmeli.';
        try {
          final menu=await FirebaseFirestore.instance.collection('business_venues').doc('${v.category.name}:${v.id}').collection('menu').get().timeout(const Duration(seconds:4));
          final priced=menu.docs.where((d)=>d.data()['active']!=false && d.data()['priceMinor'] is num && (d.data()['priceMinor'] as num)>=0 && (d.data()['currency']??'TRY')=='TRY').toList()
            ..sort((a,b)=>(a.data()['priceMinor'] as num).compareTo(b.data()['priceMinor'] as num));
          if(priced.isNotEmpty) {
            floor=(priced.first.data()['priceMinor'] as num).toInt();
            final item=priced.first.data();
            note='Menü örneği: ${item['name'] ?? item['title'] ?? 'Ürün'} · ${(floor/100).toStringAsFixed(0)} TL. Toplam yemek bedeli değildir; güncel fiyatı teyit et.';
          }
        } catch (_) { /* A failed menu lookup must not invent a price. */ }
        return DayPlanStop(spot:PhotoSpot(id:'venue_${v.category.name}_${v.id}',name:v.name,city:request.city,
          latitude:v.latitude,longitude:v.longitude,rating:0,bestTime:v.openingHours,angle:'',imageUrl:v.imageUrl,category:v.category.label),
          venue:v,minimumPriceMinor:floor,priceNote:note,stayMinutes:v.category==NearbyVenueCategory.cafe?35:60);
      })));
    }
    List<SocialEvent> events=[];
    try {
      final end=request.startAt.add(Duration(minutes:request.minutes));
      final snap=await FirebaseFirestore.instance.collection('social_events').where('visibility',isEqualTo:'public').where('city',isEqualTo:request.city)
        .where('startsAt',isGreaterThanOrEqualTo:Timestamp.fromDate(request.startAt)).where('startsAt',isLessThan:Timestamp.fromDate(end))
        .orderBy('startsAt').limit(150).get().timeout(const Duration(seconds:6));
      events=snap.docs.map(SocialEvent.fromDocument).where((e)=>foldDayCity(e.city)==foldDayCity(request.city) && e.isOpen &&
        e.remainingSlots>=request.people && (!e.isPaid || (e.currency=='TRY' && e.ticketPrice<=request.budgetPerPerson))).take(6).toList();
      if(snap.size==150) notices.add('Etkinlik sonuçları ilk 150 güncel kayıt içinden gösteriliyor.');
    } catch (_) { notices.add('Etkinlikler şu anda yüklenemedi.'); }
    return DayPlanData(stops,events,notices);
  }
}
