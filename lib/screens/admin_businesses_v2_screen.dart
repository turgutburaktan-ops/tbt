import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../theme/app_theme.dart';
import 'business_panel_preview_screen.dart';

class AdminBusinessesV2Screen extends StatefulWidget {
  const AdminBusinessesV2Screen({super.key});
  @override State<AdminBusinessesV2Screen> createState()=>_AdminBusinessesV2ScreenState();
}

class _AdminBusinessesV2ScreenState extends State<AdminBusinessesV2Screen>{
  bool? _allowed; bool _loading=true; String _filter='all',_query=''; String? _error; List<Map<String,dynamic>> _items=const[];
  @override void initState(){super.initState();_load();}

  Future<void> _load()async{
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final token=await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      if(token?.claims?['admin']!=true){if(mounted)setState((){_allowed=false;_loading=false;});return;}
      final items=await AdminConsoleService.instance.businessClaims();
      if(mounted)setState((){_allowed=true;_items=items;_loading=false;});
    }catch(e){if(mounted)setState((){_allowed=true;_loading=false;_error=e.toString();});}
  }

  void _preview(Map<String,dynamic>d){
    final category=(d['category']??'cafe').toString();
    final name=(d['venueName']??d['legalName']??'TBT Demo İşletme').toString();
    Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessPanelPreviewScreen(venueName:name,category:category)));
  }

  List<Map<String,dynamic>> get _filtered=>_items.where((d){
    final status=(d['status']??'').toString();
    if(_filter!='all'&&status!=_filter)return false;
    if(_query.isEmpty)return true;
    return '${d['venueName']??''} ${d['legalName']??''} ${d['businessEmail']??''} ${d['category']??''}'.toLowerCase().contains(_query);
  }).toList();

  int _count(String status)=>status=='all'?_items.length:_items.where((e)=>(e['status']??'').toString()==status).length;
  String _statusLabel(String s)=>switch(s){'verified'=>'Onaylı','pending_review'=>'Bekleyen','rejected'=>'Reddedildi',_=>'Başvuru yok'};
  String _cat(String c)=>switch(c){'cafe'=>'Kafe','dining'=>'Lezzet','hotel'=>'Otel',_=>'İşletme'};

  @override Widget build(BuildContext context){
    if(_allowed==false)return const Scaffold(backgroundColor:AppColors.background,body:Center(child:Text('Yönetici yetkisi gerekli.')));
    return Scaffold(
      backgroundColor:AppColors.background,
      appBar:AppBar(title:const Text('İşletmeler'),actions:[IconButton(onPressed:_load,tooltip:'Yenile',icon:const Icon(Icons.refresh_rounded))]),
      body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,24),children:[
        _summary(),
        const SizedBox(height:14),
        TextField(onChanged:(v)=>setState(()=>_query=v.trim().toLowerCase()),decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),hintText:'İşletme adı, e-posta veya kategori ara',filled:true,fillColor:AppColors.surface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
        const SizedBox(height:12),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          _chip('all','Tümü',_count('all')),_chip('pending_review','Bekleyen',_count('pending_review')),_chip('verified','Onaylı',_count('verified')),_chip('rejected','Reddedilen',_count('rejected')),
        ])),
        const SizedBox(height:14),
        if(_loading)const Padding(padding:EdgeInsets.only(top:70),child:Center(child:CircularProgressIndicator()))
        else if(_error!=null)_errorCard()
        else if(_filtered.isEmpty)_empty()
        else ..._filtered.map(_businessCard),
      ])),
    );
  }

  Widget _summary()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Row(children:[Icon(Icons.storefront_rounded,color:AppColors.cyan),SizedBox(width:10),Text('İşletme yönetimi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))]),
    const SizedBox(height:7),const Text('Başvuruları kontrol et, doğrulanan mekanların panelini görüntüle ve yönetim durumlarını tek ekrandan takip et.',style:TextStyle(color:Colors.white60,height:1.35)),
    const SizedBox(height:14),Row(children:[Expanded(child:_mini('Toplam',_count('all'))),const SizedBox(width:8),Expanded(child:_mini('Bekleyen',_count('pending_review'))),const SizedBox(width:8),Expanded(child:_mini('Onaylı',_count('verified')))]),
  ]));

  Widget _mini(String label,int n)=>Container(padding:const EdgeInsets.symmetric(vertical:12,horizontal:10),decoration:BoxDecoration(color:AppColors.surfaceStrong,borderRadius:BorderRadius.circular(14)),child:Column(children:[Text('$n',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(label,style:const TextStyle(color:Colors.white54,fontSize:11))]));
  Widget _chip(String value,String label,int n)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(selected:_filter==value,onSelected:(_)=>setState(()=>_filter=value),label:Text('$label  $n')));

  Widget _businessCard(Map<String,dynamic>d){
    final status=(d['status']??'').toString(),name=(d['venueName']??d['legalName']??'İşletme').toString(),category=(d['category']??'').toString();
    return Card(margin:const EdgeInsets.only(bottom:9),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>_preview(d),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
      CircleAvatar(radius:24,backgroundColor:status=='verified'?AppColors.cyan.withValues(alpha:.12):AppColors.surfaceStrong,child:Icon(status=='verified'?Icons.verified_rounded:Icons.storefront_outlined,color:status=='verified'?AppColors.cyan:Colors.white70)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),const SizedBox(height:4),Text('${_cat(category)} • ${_statusLabel(status)}',style:const TextStyle(color:Colors.white60)),if((d['businessEmail']??'').toString().isNotEmpty)...[const SizedBox(height:3),Text((d['businessEmail']??'').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white38,fontSize:12))]])),
      IconButton(tooltip:'Detay',onPressed:()=>_details(d),icon:const Icon(Icons.info_outline_rounded)),const Icon(Icons.chevron_right_rounded,color:Colors.white38)
    ]))));
  }

  void _details(Map<String,dynamic>d)=>showModalBottomSheet<void>(context:context,useSafeArea:true,showDragHandle:true,builder:(_)=>Padding(padding:const EdgeInsets.fromLTRB(18,4,18,28),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text((d['venueName']??d['legalName']??'İşletme').toString(),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:14),
    _info('Durum',_statusLabel((d['status']??'').toString())),_info('Kategori',_cat((d['category']??'').toString())),_info('E-posta',(d['businessEmail']??'-').toString()),_info('Telefon',(d['businessPhone']??'-').toString()),
    const SizedBox(height:14),FilledButton.icon(onPressed:(){Navigator.pop(context);_preview(d);},icon:const Icon(Icons.dashboard_customize_outlined),label:const Text('Paneli Görüntüle')),
  ])));
  Widget _info(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[SizedBox(width:90,child:Text(a,style:const TextStyle(color:Colors.white54))),Expanded(child:Text(b,style:const TextStyle(fontWeight:FontWeight.w700)))]));
  Widget _empty()=>Padding(padding:const EdgeInsets.only(top:74),child:Column(children:[const Icon(Icons.storefront_outlined,size:48,color:Colors.white24),const SizedBox(height:12),Text(_query.isNotEmpty?'Aramana uygun işletme yok.':'Bu bölümde henüz işletme yok.',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),const Text('Yeni başvurular geldiğinde burada görünecek.',style:TextStyle(color:Colors.white54))]));
  Widget _errorCard()=>Padding(padding:const EdgeInsets.only(top:50),child:Column(children:[const Icon(Icons.cloud_off_rounded,size:46,color:Colors.white38),const SizedBox(height:10),const Text('İşletmeler yüklenemedi',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:12),OutlinedButton.icon(onPressed:_load,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar Dene'))]));
}
