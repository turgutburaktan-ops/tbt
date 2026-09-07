import 'reservation_controls.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ProfileReservations extends StatefulWidget {
  final String userId;
  final bool initiallyExpanded;
  const ProfileReservations({super.key,required this.userId,this.initiallyExpanded=false});
  @override
  State<ProfileReservations> createState() => _ProfileReservationsState();
}
class _ProfileReservationsState extends State<ProfileReservations> with WidgetsBindingObserver {
  List<Map<String,dynamic>>? _items;
  String? _error;
  bool _busy=false, _expanded=false;
  Timer? _timer;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);if(widget.initiallyExpanded){_expanded=true;_load();_timer=Timer.periodic(const Duration(seconds:30),(_)=>_load());}}
  @override
  void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&_expanded)_load();}
  Future<void> _load() async {
    if(_busy||FirebaseAuth.instance.currentUser?.uid!=widget.userId)return;setState(()=>_busy=true);
    try {
      final result=await FirebaseFunctions.instanceFor(region:'europe-west1').httpsCallable('getMyBusinessReservations').call();
      final data=Map<String,dynamic>.from(result.data as Map);
      final rows=(data['reservations'] as List? ?? []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      if(mounted&&FirebaseAuth.instance.currentUser?.uid==widget.userId)setState((){_items=rows;_error=null;});
    } catch(_){if(mounted)setState(()=>_error='Rezervasyonlar yüklenemedi. Yeniden dene.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Card(
    margin:const EdgeInsets.symmetric(horizontal:16,vertical:8),
    child:ExpansionTile(initiallyExpanded:widget.initiallyExpanded,title:const Text('Rezervasyonlarım'),leading:const Icon(Icons.event_seat_outlined),
      onExpansionChanged:(value){_expanded=value;_timer?.cancel();if(value){_load();_timer=Timer.periodic(const Duration(seconds:30),(_)=>_load());}},
      children:[
        TextButton.icon(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh),label:const Text('Yenile')),
        if(_busy&&_items==null)const CircularProgressIndicator(),
        if(_error!=null)Padding(padding:const EdgeInsets.all(16),child:Text(_error!)),
        if(_items!=null&&_items!.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('Henüz rezervasyonun yok.')),
        ...?_items?.map((d){
          final at=DateTime.fromMillisecondsSinceEpoch((d['atMs'] as num).toInt());
          final status={'pending':'Yanıt bekliyor','accepted':'Onaylandı','rejected':'Reddedildi','cancelled':'İptal edildi'}[d['status']]??'Sonuçlandı';
          final orders=(d['orderItems'] as List? ?? []).map((x)=>'${x['quantity']} × ${x['name']}').join('\n');
          final total=((d['orderTotalMinor'] as num? ?? 0)/100).toStringAsFixed(2);
          return Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[ListTile(title:Text('${d['venueName']} · $status'),subtitle:Text('${at.day}.${at.month}.${at.year} ${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')} · ${d['partySize']} kişi\n${d['note']??''}${orders.isEmpty?'':'\n$orders\nSipariş toplamı: $total TL'}')),ReservationControls(data:d,refresh:_load)]));
        }),
      ],
    ),
  );
}
