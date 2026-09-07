import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/profile_reservations.dart';
class ReservationInboxScreen extends StatelessWidget {
  const ReservationInboxScreen({super.key});
  @override
  Widget build(BuildContext context){
    final uid=FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(appBar:AppBar(title:const Text('Rezervasyonlarım')),body:uid==null?const Center(child:Text('Rezervasyonlarını görmek için giriş yap.')):SingleChildScrollView(child:ProfileReservations(userId:uid,initiallyExpanded:true)));
  }
}
