import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../theme/app_theme.dart';
import '../services/user_facing_error.dart';
import '../services/travel_plan_service.dart';
import '../widgets/route_design/route_design.dart';
import 'travel_plan_invite_screen.dart';
import 'route_sharing_screen.dart';
import 'user_profile_screen.dart';

class RouteParticipantsScreen extends StatelessWidget {
  const RouteParticipantsScreen({super.key,required this.plan});
  final TravelPlan plan;
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Katılımcılar')),
    body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('travel_plans').doc(plan.id).snapshots(),builder:(c,s){
      if(s.hasError)return Center(child:Text(userFacingError(s.error!)));
      final data=s.data?.data();if(data==null)return const Center(child:CircularProgressIndicator());
      final owner=data['ownerId']==FirebaseAuth.instance.currentUser?.uid;
      final ids=List<String>.from(data['memberIds']??[]);
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text(plan.title,style:const TextStyle(color:AppColors.textMuted)),const SizedBox(height:16),
        if(owner)RouteAction(label:'Kişi davet et',outlined:true,icon:Icons.person_add_alt,onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>TravelPlanInviteScreen(planId:plan.id,planTitle:plan.title)))),
        if(owner)...[const SizedBox(height:20),const Text('Katılma istekleri',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),RouteParticipation(routeId:plan.id,data:data,showSettings:false)],
        const SizedBox(height:20),Text('Katılımcılar · ${ids.length}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const SizedBox(height:12),
        RoutePanel(padding:EdgeInsets.zero,child:Column(children:[for(final id in ids)StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(id).snapshots(),builder:(c,p){
          final profile=p.data?.data()??{};final photo=(profile['photoUrl']??'').toString();
          return ListTile(leading:CircleAvatar(backgroundImage:photo.isEmpty?null:NetworkImage(photo),child:photo.isEmpty?const Icon(Icons.person_outline):null),title:Text((profile['displayName']??profile['username']??'Katılımcı').toString()),subtitle:id==data['ownerId']?const Text('Organizatör',style:TextStyle(color:AppColors.cyan)):null,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>UserProfileScreen(userId:id))));
        })])),
        if(owner)ListTile(title:const Text('Katılım ayarları'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>RouteSharingScreen(routeId:plan.id,title:plan.title)))),
      ]);
    }));
}
