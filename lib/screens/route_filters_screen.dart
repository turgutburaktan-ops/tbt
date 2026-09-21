import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/route_design/route_design.dart';

class RouteFilters {
  const RouteFilters({this.mode='',this.city='',this.maxKm=100,this.duration=0,this.roundTrip=false,this.following=false,this.difficulties=const {}});
  final String mode,city;
  final double maxKm;
  final int duration;
  final bool roundTrip,following;
  final Set<String> difficulties;
  bool matches(TravelPlan p, Set<String> followed) {
    if(mode.isNotEmpty&&p.transport!=mode)return false;
    if(city.isNotEmpty&&p.city!=city)return false;
    if(maxKm<100&&(p.distanceKm<=0||p.distanceKm>maxKm))return false;
    if(duration>0&&(p.travelMinutes<=0||(duration==1?p.travelMinutes>60:duration==2?(p.travelMinutes<60||p.travelMinutes>180):p.travelMinutes<=180)))return false;
    if(roundTrip&&p.dayPlan['roundTrip']!=true)return false;
    if(following&&!followed.contains(p.ownerId))return false;
    if(difficulties.isNotEmpty&&!difficulties.contains(p.dayPlan['difficulty']))return false;
    return true;
  }
}
class RouteFiltersScreen extends StatefulWidget {
  const RouteFiltersScreen({super.key,required this.value,required this.cities});
  final RouteFilters value;
  final List<String> cities;
  @override State<RouteFiltersScreen> createState()=>_RouteFiltersScreenState();
}
class _RouteFiltersScreenState extends State<RouteFiltersScreen>{
  late String _mode=widget.value.mode,_city=widget.value.city;
  late double _km=widget.value.maxKm;
  late int _duration=widget.value.duration;
  late bool _round=widget.value.roundTrip,_following=widget.value.following;
  late Set<String> _difficulty={...widget.value.difficulties};
  Widget _label(String s)=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Text(s,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)));
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Parkur filtreleri'),actions:[TextButton(onPressed:()=>setState((){_mode='';_city='';_km=100;_duration=0;_round=false;_following=false;_difficulty={};}),child:const Text('Sıfırla'))]),
    bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:RouteAction(label:'Parkurları göster',onPressed:()=>Navigator.pop(context,RouteFilters(mode:_mode,city:_city,maxKm:_km,duration:_duration,roundTrip:_round,following:_following,difficulties:_difficulty))))),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      DropdownButtonFormField<String>(key:ValueKey(_city),initialValue:widget.cities.contains(_city)?_city:'',decoration:const InputDecoration(labelText:'Bölge'),items:[const DropdownMenuItem(value:'',child:Text('Tüm bölgeler')),for(final c in widget.cities)DropdownMenuItem(value:c,child:Text(c))],onChanged:(v)=>setState(()=>_city=v??'')),
      _label('Aktivite türü'),Wrap(spacing:8,children:[for(final m in ['Araç','Yürüyüş','Bisiklet'])FilterChip(label:Text(m),selected:_mode==m,onSelected:(v)=>setState(()=>_mode=v?m:''))]),
      _label('Mesafe · ${_km==100?'Tümü':'0–${_km.round()} km'}'),Slider(value:_km,min:5,max:100,divisions:19,onChanged:(v)=>setState(()=>_km=v)),
      _label('Tahmini süre'),Wrap(spacing:8,children:[for(var i=1;i<=3;i++)FilterChip(label:Text(['1 saate kadar','1–3 saat','3 saatten fazla'][i-1]),selected:_duration==i,onSelected:(v)=>setState(()=>_duration=v?i:0))]),
      _label('Zorluk'),Wrap(spacing:8,children:[for(final d in ['Kolay','Orta','Zor'])FilterChip(label:Text(d),selected:_difficulty.contains(d),onSelected:(v)=>setState((){v?_difficulty.add(d):_difficulty.remove(d);}))]),
      const Text('Zorluk rota sahibinin değerlendirmesidir. Bilgisi olmayan rotalar zorluk filtresinde gösterilmez.',style:TextStyle(color:AppColors.textMuted,fontSize:12)),
      _label('Rota tipi'),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Başlangıca dönüş'),value:_round,onChanged:(v)=>setState(()=>_round=v)),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Yalnızca takip ettiklerim'),value:_following,onChanged:(v)=>setState(()=>_following=v)),
    ]));
}
