import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import 'tbt_dialog.dart';

class RouteManagementMenu extends StatefulWidget {
  const RouteManagementMenu({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<RouteManagementMenu> createState() => _RouteManagementMenuState();
}

class _RouteManagementMenuState extends State<RouteManagementMenu> {
  bool _busy=false;
  Future<void> _act(bool owner) async {
    final accepted=await showTbtDialog<bool>(context:context,builder:(c)=>TbtDialog(
      title:Text(owner?'Rotayı sil':'Rotadan ayrıl'),
      content:Text(owner?'“${widget.plan.title}” silinsin mi? Ortak rotaysa katılımcılar da artık bu rotaya erişemez.':'“${widget.plan.title}” rotasından ayrılmak istiyor musun?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(owner?'Sil':'Ayrıl'))],
    ));
    if(accepted!=true||!mounted)return;
    final messenger=ScaffoldMessenger.of(context);
    setState(()=>_busy=true);
    try {
      if(owner){await TravelPlanService.instance.delete(widget.plan.id);}
      else {await FirebaseFunctions.instanceFor(region:'europe-west1').httpsCallable('leaveTravelPlan').call({'planId':widget.plan.id});}
      messenger.showSnackBar(SnackBar(content:Text(owner?'Rota silindi.':'Rotadan ayrıldın.')));
    }catch(_){messenger.showSnackBar(SnackBar(content:Text(owner?'Rota silinemedi. Tekrar dene.':'Rotadan ayrılamadın. Tekrar dene.')));}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context){
    final uid=FirebaseAuth.instance.currentUser?.uid,owner=uid==widget.plan.ownerId;
    if(uid==null||(!owner&&!widget.plan.memberIds.contains(uid)))return const SizedBox.shrink();
    return PopupMenuButton<String>(
      enabled:!_busy,tooltip:'Rota işlemleri',icon:const Icon(Icons.more_vert),
      onSelected:(_)=>_act(owner),
      itemBuilder:(_)=>[PopupMenuItem(value:'remove',child:Text(owner?'Rotayı sil':'Rotadan ayrıl'))],
    );
  }
}
