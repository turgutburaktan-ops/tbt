import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/turkey_selection_data.dart';
import '../models/photo_spot.dart';
import '../models/travel_plan.dart';
import '../services/day_plan_engine.dart';
import '../services/day_plan_service.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/spot_repository.dart';
import '../services/travel_plan_service.dart';
import '../services/travel_plan_collaboration_service.dart';
import '../widgets/searchable_selection_field.dart';
import '../widgets/spot_image.dart';
import 'business_profile_screen.dart';
import 'event_deep_link_screen.dart';
import 'login_screen.dart';
import 'route_planner_screen.dart';
import 'spot_detail_screen.dart';
import 'travel_plan_detail_screen.dart';
import 'travel_plan_invite_screen.dart';
import 'travel_plans_screen.dart';

class TodayPlanScreen extends StatefulWidget {
  final bool exploreTurkey;
  const TodayPlanScreen({super.key, this.exploreTurkey=false});
  @override
  State<TodayPlanScreen> createState()=>_TodayPlanScreenState();
}
class _TodayPlanScreenState extends State<TodayPlanScreen> {
  final _city=TextEditingController(text:'Elazığ'), _budget=TextEditingController(text:'600');
  List<PhotoSpot> _spots=[];
  List<DayPlanAlternative> _alternatives=[];
  DayPlanData? _data;
  DayPlanRequest? _request;
  String _transport='Araç',_company='Arkadaşlarla',_mood='Karışık';
  int _hours=3,_people=2,_generation=0;
  late bool _turkey=widget.exploreTurkey;
  bool _loading=true,_generating=false,_saving=false,_locating=false;
  String? _error;
  double? _latitude,_longitude;
  DateTime _startAt=DateTime.now().add(const Duration(minutes:30));
  final Map<int,String> _saved={};
  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){_generation++;_city.dispose();_budget.dispose();super.dispose();}
  Future<void> _load() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final spots=await SpotRepository.instance.loadSpots();
      if(!mounted)return;
      final remembered=prefs.getString('today_plan_city') ?? NearbyVenueService.instance.selectedCityName;
      setState((){_spots=spots;_loading=false;_error=null;if(remembered!=null&&turkeyCities.contains(remembered))_city.text=remembered;});
    }catch(_){if(mounted)setState((){_loading=false;_error='Yerler yüklenemedi. Yeniden dene.';});}
  }
  void _invalidate(){_generation++;_alternatives=[];_data=null;_request=null;_saved.clear();_error=null;_generating=false;}
  void _change(VoidCallback change){setState((){change();_invalidate();});}
  Future<void> _locate() async {
    if(_locating||_generating)return;
    setState(()=>_locating=true);
    final position=await LocationService.getCurrentPosition(forceRefresh:true);
    if(!mounted)return;
    setState(()=>_locating=false);
    if(position==null){_message('Konum alınamadı. Şehir seçerek devam edebilirsin.');return;}
    // Resolve the nearest catalog city only after the user requests location.
    final valid=_spots.where((s)=>DayPlanEngine.coordinates(s.latitude,s.longitude)&&turkeyCities.contains(s.city)).toList()
      ..sort((a,b)=>DayPlanEngine.distance(position.latitude,position.longitude,a.latitude,a.longitude).compareTo(DayPlanEngine.distance(position.latitude,position.longitude,b.latitude,b.longitude)));
    if(valid.isEmpty||DayPlanEngine.distance(position.latitude,position.longitude,valid.first.latitude,valid.first.longitude)>70){_message('Yakınındaki şehir belirlenemedi. Şehrini listeden seç.');return;}
    _change((){_city.text=valid.first.city;_latitude=position.latitude;_longitude=position.longitude;_turkey=false;});
  }
  Future<void> _pickStart() async {
    final now=DateTime.now();
    final date=await showDatePicker(context:context,initialDate:_startAt.isBefore(now)?now:_startAt,firstDate:DateTime(now.year,now.month,now.day),lastDate:now.add(const Duration(days:90)));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(_startAt));
    if(time==null||!mounted)return;
    final start=DateTime(date.year,date.month,date.day,time.hour,time.minute);
    if(start.isBefore(DateTime.now())){_message('Gelecekte bir başlangıç saati seç.');return;}
    _change(()=>_startAt=start);
  }
  Future<void> _generate() async {
    if(_generating||_saving)return;
    final city=turkeyCities.where((c)=>foldDayCity(c)==foldDayCity(_city.text)).firstOrNull;
    final budget=int.tryParse(_budget.text);
    if(city==null){_message('Listeden bir Türkiye şehri seç.');return;}
    if(budget==null||budget<0||budget>100000){_message('Kişi başı bütçeni 0–100.000 TL arasında gir.');return;}
    if(_startAt.isBefore(DateTime.now())){_message('Başlangıç saati geçti; yeni saat seç.');return;}
    _invalidate();final generation=_generation;
    setState((){_generating=true;_city.text=city;});
    try {
      var lat=_latitude,lon=_longitude;
      if(lat==null||lon==null){
        final area=await NearbyVenueService.instance.findCity(city).timeout(const Duration(seconds:14));
        if(area==null)throw Exception('Şehir merkezi bulunamadı. Bağlantını kontrol edip yeniden dene.');
        lat=area.latitude;lon=area.longitude;
      }
      if(!mounted||generation!=_generation)return;
      final request=DayPlanRequest(city:city,transport:_transport,company:_company,mood:_mood,minutes:_hours*60,people:_people,
        budgetPerPerson:budget,latitude:lat,longitude:lon,startAt:_startAt);
      final data=await DayPlanService.load(request,_spots);
      if(!mounted||generation!=_generation)return;
      final options=DayPlanEngine.build(request,data.stops);
      setState((){_request=request;_data=data;_alternatives=options;_generating=false;});
      try {final prefs=await SharedPreferences.getInstance();await prefs.setString('today_plan_city',city);}catch(_){}
    }catch(e){if(mounted&&generation==_generation)setState((){_generating=false;_error=e.toString().replaceFirst('Exception: ','');});}
  }
  void _message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  String _clock(DateTime t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  Future<void> _save(int index,{bool friends=false}) async {
    if(_saving)return;
    if(FirebaseAuth.instance.currentUser==null){await Navigator.push(context,MaterialPageRoute(builder:(_)=>const LoginScreen()));if(!mounted||FirebaseAuth.instance.currentUser==null)return;}
    final r=_request!,option=_alternatives[index];
    setState(()=>_saving=true);
    try{
      var id=_saved[index];
      if(id==null){
        id=await TravelPlanService.instance.create(title:'${r.city} · ${option.title}',city:r.city,durationHours:r.minutes~/60,
          budget:'Kişi başı hedef ${r.budgetPerPerson} TL',transport:r.transport,interests:[r.mood],spots:option.stops.map((s)=>s.spot).toList(),
          startAt:r.startAt,distanceKm:option.distanceKm,travelMinutes:option.travelMinutes,estimatedBudget:0,
          dayPlan:{'people':r.people,'company':r.company,'budgetPerPerson':r.budgetPerPerson,'totalMinutes':option.totalMinutes,
            'minimumPriceMinor':option.minimumPriceMinor,'pricesComplete':false,'travelEstimated':true,
            'originLatitude':r.latitude,'originLongitude':r.longitude,'returnIncluded':true},
          stopDetails:option.stops.map((s)=>{'id':s.spot.id,'priceNote':s.priceNote,'minimumPriceMinor':s.minimumPriceMinor,
            'stayMinutes':s.stayMinutes,if(s.venue!=null)'venue':s.venue!.toJson()}).toList());
        _saved[index]=id;
      }
      if(!mounted)return;
      if(friends){
        await Navigator.push(context,MaterialPageRoute(builder:(_)=>TravelPlanInviteScreen(planId:id!,planTitle:'${r.city} · ${option.title}')));
      }else{
        final doc=await FirebaseFirestore.instance.collection('travel_plans').doc(id).get();
        if(!mounted)return;
        await Navigator.push(context,MaterialPageRoute(builder:(_)=>TravelPlanDetailScreen(plan:TravelPlan.fromDoc(doc))));
      }
    }catch(_){_message('Plan kaydedilemedi veya açılamadı. Tekrar dene.');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  Future<void> _proposeAlternative(int index) async {
    final id=_saved[index];if(id==null)return;
    setState(()=>_saving=true);
    try {
      final selected=_alternatives[index].stops.map((s)=>s.id).toSet();
      final others=_alternatives.where((p)=>p!=_alternatives[index]).expand((p)=>p.stops).where((s)=>!selected.contains(s.id));
      for(final stop in others){
        await TravelPlanCollaborationService.instance.proposeStopIfAbsent(id,stop.spot.name,spotId:stop.spot.id,
          latitude:stop.spot.latitude,longitude:stop.spot.longitude,city:stop.spot.city);
      }
      _message('Alternatif duraklar planın oylama bölümüne eklendi.');
    }catch(_){_message('Durak önerileri eklenemedi.');}
    finally{if(mounted)setState(()=>_saving=false);}
  }
  void _openStop(DayPlanStop stop)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>stop.venue!=null?BusinessProfileScreen(venue:stop.venue!):SpotDetailScreen(spot:stop.spot)));
  Widget _choices<T>(String title,List<T> values,T selected,ValueChanged<T> onChanged)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.only(top:14,bottom:5),child:Text(title,style:const TextStyle(fontWeight:FontWeight.bold))),
    Wrap(spacing:8,runSpacing:4,children:values.map((v)=>ChoiceChip(label:Text('$v'),selected:v==selected,onSelected:_generating||_saving?null:(_)=>_change(()=>onChanged(v)))).toList()),
  ]);
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF081426),
    appBar:AppBar(title:const Text('Bugün ne yapalım?'),actions:[IconButton(tooltip:'Seyahat planlarım',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TravelPlansScreen())),icon:const Icon(Icons.bookmarks_outlined))]),
    body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.fromLTRB(16,8,16,32),children:[
      const Text('Birlikte güzel bir gün planlayalım.',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('Süreni ve bütçeni seç. Durakları karşılaştır, arkadaşlarınla karar ver ve yola çık.'),
      const SizedBox(height:14),
      Wrap(spacing:8,children:[
        ChoiceChip(label:const Text('Yakınımda'),selected:!_turkey,onSelected:_generating||_saving?null:(_)=>_change(()=>_turkey=false)),
        ChoiceChip(label:const Text('Türkiye’yi keşfet'),selected:_turkey,onSelected:_generating||_saving?null:(_)=>_change((){_turkey=true;_latitude=null;_longitude=null;})),
      ]),
      const SizedBox(height:12),
      SearchableSelectionField(controller:_city,options:turkeyCities,labelText:_turkey?'Hangi şehre gitmek istersin?':'Hangi şehirdesin?',hintText:'Elazığ, İstanbul, Ankara…',prefixIcon:Icons.location_city,
        enabled:!_generating&&!_saving,maxSuggestions:6,onChanged:(_)=>_change((){_latitude=null;_longitude=null;}),onSelected:(_)=>_change((){_latitude=null;_longitude=null;})),
      if(!_turkey) TextButton.icon(onPressed:_generating||_locating||_saving?null:_locate,icon:const Icon(Icons.my_location),label:Text(_locating?'Konum bulunuyor…':'Bulunduğum yerden başla')),
      Text(_latitude==null?'Rota seçtiğin şehrin merkezinden başlar.':'Rota seçtiğin mevcut konumdan başlar.',style:const TextStyle(fontSize:12,color:Colors.white70)),
      if(foldDayCity(_city.text)=='elazig') const Padding(padding:EdgeInsets.only(top:8),child:Text('İlk durağımız Elazığ. Türkiye’nin 81 ilinde plan yapabilirsin.',style:TextStyle(color:Color(0xFF63D5CC)))),
      _choices('Kaç saatin var?',[1,2,3,5,8],_hours,(v)=>_hours=v),
      _choices('Kimlerle?', ['Tek başıma','İki kişi','Arkadaşlarla','Aile'],_company,(v){_company=v;_people=v=='Tek başıma'?1:v=='İki kişi'?2:_people.clamp(2,12);}),
      Row(children:[const Expanded(child:Text('Kişi sayısı')),IconButton(onPressed:_people<=1||_generating||_saving?null:()=>_change((){_people--;_company=_people==1?'Tek başıma':_people==2?'İki kişi':_company;}),icon:const Icon(Icons.remove_circle_outline)),Text('$_people'),IconButton(onPressed:_people>=12||_generating||_saving?null:()=>_change((){_people++;if(_company=='Tek başıma'||_company=='İki kişi')_company=_people==2?'İki kişi':'Arkadaşlarla';}),icon:const Icon(Icons.add_circle_outline))]),
      TextField(controller:_budget,enabled:!_generating&&!_saving,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(6)],decoration:const InputDecoration(labelText:'Kişi başı harcama sınırı',suffixText:'TL'),onChanged:(_)=>_change((){})),
      Padding(padding:const EdgeInsets.only(top:5),child:Text('Grup bütçesi: ${(int.tryParse(_budget.text)??0)*_people} TL · Harcama hedefidir; mekân fiyatı değildir.',style:const TextStyle(fontSize:12))),
      _choices('Nasıl gideceksiniz?', ['Yürüyüş','Bisiklet','Araç'],_transport,(v)=>_transport=v),
      _choices('Bugünün havası', ['Karışık','Gezinti','Yemek ve kahve'],_mood,(v)=>_mood=v),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule),title:const Text('Başlangıç'),subtitle:Text('${_startAt.day}.${_startAt.month}.${_startAt.year} · ${_clock(_startAt)}'),trailing:const Icon(Icons.edit_outlined),onTap:_generating||_saving?null:_pickStart),
      FilledButton.icon(onPressed:_generating||_saving?null:_generate,icon:const Icon(Icons.route),label:Text(_generating?'Seçenekler hazırlanıyor…':'Günümü planla')),
      if(_generating)const Padding(padding:EdgeInsets.all(12),child:LinearProgressIndicator()),
      if(_error!=null) ...[Text(_error!,style:const TextStyle(color:Colors.orangeAccent)),TextButton(onPressed:_spots.isEmpty?_load:_generate,child:const Text('Yeniden dene'))],
      if(_request!=null&&_alternatives.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('Bu süre ve başlangıç noktasına uygun rota bulunamadı. Süreyi artırabilir veya başka bir şehir seçebilirsin.')),
      if(_request!=null&&_alternatives.isNotEmpty) ...[
        const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('Sana uygun seçenekler',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
        const Text('Süreler yol ve durak tahminlerini, başlangıç noktasına dönüşü içerir. Trafik, yol erişimi ve çalışma saatleri teyit edilmeli. Fiyatı bilinmeyen duraklar ücretsiz sayılmadı.',style:TextStyle(fontSize:12,color:Colors.white70)),
        ..._alternatives.asMap().entries.map((e)=>_option(e.key,e.value)),
      ],
      if(_data!=null&&_data!.events.isNotEmpty) ...[
        const Padding(padding:EdgeInsets.only(top:20,bottom:8),child:Text('Bu saatlerde şehirde',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
        const Text('Etkinlikler rotaya otomatik eklenmez. Katılım koşullarını ve ulaşım süresini kontrol et.',style:TextStyle(fontSize:12)),
        ..._data!.events.map((e)=>Card(child:ListTile(title:Text(e.title),subtitle:Text('${_clock(e.startsAt.toLocal())} · ${e.isPaid?'${e.ticketPrice.toStringAsFixed(0)} TL / kişi':'Ücretsiz katılım'} · ${e.remainingSlots} kişilik yer'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EventDeepLinkScreen(eventId:e.id)))))),
      ],
      if(_data!=null&&_data!.events.isEmpty&&!_data!.notices.any((n)=>n.startsWith('Etkinlik')))const Padding(padding:EdgeInsets.only(top:16),child:Text('Seçtiğin saat ve bütçede uygun etkinlik bulunamadı.')),
      if(_data!=null)..._data!.notices.map((n)=>Padding(padding:const EdgeInsets.only(top:8),child:Text(n,style:const TextStyle(color:Colors.orangeAccent)))),
    ]),
  );
  Widget _option(int index,DayPlanAlternative option){
    final r=_request!;
    return Card(color:const Color(0xFF0D1B30),margin:const EdgeInsets.only(top:16),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(option.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      Text('${option.stops.length} durak · yaklaşık ${option.totalMinutes} dk · ${option.distanceKm.toStringAsFixed(1)} km'),
      Text('${option.travelMinutes} dk yol · ${r.people} kişi · dönüş ${_clock(r.startAt.add(Duration(minutes:option.totalMinutes)))}',style:const TextStyle(color:Colors.white70,fontSize:12)),
      const SizedBox(height:8),
      Text(option.minimumPriceMinor>0?'Yayınlanan menü örnekleri toplamı ${(option.minimumPriceMinor/100).toStringAsFixed(0)} TL / kişi. Diğer harcamalar dahil değil; toplam bütçe teyidi gerekli.':'Toplam harcama hesaplanamıyor; güncel fiyatları duraklardan kontrol et.',style:const TextStyle(color:Color(0xFF63D5CC))),
      ...option.stops.asMap().entries.map((entry){final stop=entry.value;return ListTile(contentPadding:EdgeInsets.zero,leading:SizedBox(width:44,height:44,child:SpotImage(spot:stop.spot,borderRadius:BorderRadius.circular(10))),
        title:Text('${_clock(r.startAt.add(Duration(minutes:option.arrivalMinutes[entry.key])))} · ${stop.spot.name}'),
        subtitle:Text('${stop.priceNote}\n${stop.venue==null?'Yer ayrıntıları':'Menü, deneyimler ve rezervasyon'}'),isThreeLine:false,onTap:()=>_openStop(stop));}),
      OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>RoutePlannerScreen(initialSpots:dayPlanRouteStops(option.stops.map((s)=>s.spot).toList(),r.latitude,r.longitude,r.city),initialUseCurrentLocation:false,initialTransport:r.transport))),icon:const Icon(Icons.map_outlined),label:const Text('Haritada incele')),
      Wrap(spacing:8,children:[
        FilledButton(onPressed:_saving?null:()=>_save(index),child:Text(_saved.containsKey(index)?'Planımı aç':'Planı kaydet')),
        OutlinedButton.icon(onPressed:_saving?null:()=>_save(index,friends:true),icon:const Icon(Icons.group_add_outlined),label:const Text('Arkadaşlarla karar ver')),
      ]),
      if(_saved.containsKey(index)&&_alternatives.length>1)TextButton(onPressed:_saving?null:()=>_proposeAlternative(index),child:const Text('Diğer durakları oylamaya ekle')),
      if(_saving)const LinearProgressIndicator(),
    ])));
  }
}
