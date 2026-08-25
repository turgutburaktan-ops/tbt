import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessPublicActions extends StatefulWidget {
  final String venueKey;
  final bool reservationsEnabled;
  const BusinessPublicActions({super.key,required this.venueKey,this.reservationsEnabled=true});
  @override State<BusinessPublicActions> createState()=>_BusinessPublicActionsState();
}

class _BusinessPublicActionsState extends State<BusinessPublicActions>{
  final _functions=FirebaseFunctions.instanceFor(region:'europe-west1');
  bool _following=false,_loading=true,_busy=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{if(FirebaseAuth.instance.currentUser==null)return;if(mounted)setState(()=>_loading=true);try{final r=await _functions.httpsCallable('getBusinessFollowStatus').call({'venueKey':widget.venueKey});final d=Map<String,dynamic>.from(r.data as Map);if(mounted)setState(()=>_following=d['following']==true);}catch(_){ }finally{if(mounted)setState(()=>_loading=false);}}
  Future<void> _follow()async{if(_busy)return;setState(()=>_busy=true);try{final next=!_following;await _functions.httpsCallable('followBusiness').call({'venueKey':widget.venueKey,'follow':next});if(mounted)setState(()=>_following=next);}on FirebaseFunctionsException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message??'İşlem tamamlanamadı.')));}finally{if(mounted)setState(()=>_busy=false);}}
  Future<void> _reservation()async{
    try{await _functions.httpsCallable('recordBusinessMetric').call({'venueKey':widget.venueKey,'metric':'reservation_open'});}catch(_){}
    if(!mounted)return;var at=DateTime.now().add(const Duration(hours:2));var people=2;final note=TextEditingController();
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(title:const Text('Rezervasyon talebi'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(initialValue:people,decoration:const InputDecoration(labelText:'Kişi sayısı'),items:List.generate(12,(i)=>i+1).map((v)=>DropdownMenuItem(value:v,child:Text('$v kişi'))).toList(),onChanged:(v)=>setState(()=>people=v??2)),const SizedBox(height:10),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule_rounded),title:Text('${at.day}.${at.month}.${at.year} • ${at.hour.toString().padLeft(2,'0')}:${at.minute.toString().padLeft(2,'0')}'),onTap:()async{final date=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:180)),initialDate:at);if(date==null||!context.mounted)return;final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(at));if(time!=null)setState(()=>at=DateTime(date.year,date.month,date.day,time.hour,time.minute));}),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Not (isteğe bağlı)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Vazgeç')),FilledButton(onPressed:()async{try{await _functions.httpsCallable('requestBusinessReservation').call({'venueKey':widget.venueKey,'partySize':people,'atMs':at.millisecondsSinceEpoch,'note':note.text.trim()});if(dialogContext.mounted)Navigator.pop(dialogContext);if(mounted)ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content:Text('Rezervasyon talebin işletmeye gönderildi.')));}on FirebaseFunctionsException catch(e){if(mounted)ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content:Text(e.message??'Talep gönderilemedi.')));}},child:const Text('Talep Gönder'))])));
    note.dispose();
  }
  @override Widget build(BuildContext context){if(FirebaseAuth.instance.currentUser==null)return const SizedBox.shrink();return Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_loading||_busy?null:_follow,icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(_following?Icons.notifications_active_rounded:Icons.notifications_none_rounded),label:Text(_following?'Takip Ediliyor':'Takip Et'))),if(widget.reservationsEnabled)...[const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:_reservation,icon:const Icon(Icons.event_seat_outlined),label:const Text('Rezervasyon')))] ]);}
}
