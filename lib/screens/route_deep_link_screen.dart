import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import 'travel_plan_detail_screen.dart';

/// A link opens a route but never grants membership or bypasses visibility.
class RouteDeepLinkScreen extends StatelessWidget {
  const RouteDeepLinkScreen({super.key, required this.routeId});
  final String routeId;
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream: FirebaseFirestore.instance.collection('travel_plans').doc(routeId).snapshots(),
    builder: (context,snapshot) {
      if(snapshot.hasData && snapshot.data!.exists) {
        return TravelPlanDetailScreen(plan: TravelPlan.fromDoc(snapshot.data!));
      }
      return Scaffold(appBar:AppBar(title:const Text('Rota')),body:Center(
        child: snapshot.connectionState==ConnectionState.waiting
          ? const CircularProgressIndicator()
          : const Padding(padding:EdgeInsets.all(24),child:Text('Bu rota kaldırılmış veya sana kapalı olabilir. Özel rotalar için organizatörün seni davet etmesi gerekir.',textAlign:TextAlign.center)),
      ));
    },
  );
}
