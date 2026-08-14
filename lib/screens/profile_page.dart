import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import 'create_post_screen.dart';
import 'follow_list_screen.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: AuthService.instance.authStateChanges,
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) return const SafeArea(child: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))));
      final user = auth.data;
      if (user == null) return SafeArea(child: Center(child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('Giriş Yap / Kayıt Ol'))));
      return _ProfileBody(user: user);
    },
  );
}

class _ProfileBody extends StatefulWidget {
  final User user;
  const _ProfileBody({required this.user});
  @override State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  OverlayEntry? _preview;
  @override void initState() { super.initState(); SocialService.instance.ensureUserProfile(); }
  @override void dispose() { _hidePreview(); super.dispose(); }

  void _openPhoto(String url, String name) { if (url.isEmpty) return; Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, title: Text(name)), body: InteractiveViewer(minScale: 1, maxScale: 5, clipBehavior: Clip.none, child: Center(child: Image.network(url, fit: BoxFit.contain)))))); }
  void _openFollowList(bool followers) => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: widget.user.uid, followers: followers)));

  void _showPreview(String url) {
    if (url.isEmpty || _preview != null) return;
    _preview = OverlayEntry(builder: (_) => Material(color: Colors.black54, child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(30), child: InteractiveViewer(minScale: 1, maxScale: 4, clipBehavior: Clip.none, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))))))));
    Overlay.of(context).insert(_preview!);
  }
  void _hidePreview() { _preview?.remove(); _preview = null; }

  @override
  Widget build(BuildContext context) => SafeArea(child: StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream: SocialService.instance.userProfile(widget.user.uid),
    builder: (context, ps) {
      final p = ps.data?.data() ?? const <String,dynamic>{};
      final name = (p['displayName'] ?? widget.user.displayName ?? 'Fotoğrafçı').toString();
      final bio = (p['bio'] ?? '').toString();
      final photo = (p['photoUrl'] ?? widget.user.photoURL ?? '').toString();
      return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: SocialService.instance.userPosts(widget.user.uid),
        builder: (context, ss) {
          final posts = [...(ss.data?.docs ?? <QueryDocumentSnapshot<Map<String,dynamic>>>[])];
          posts.sort((a,b) { final x=a.data()['createdAt'], y=b.data()['createdAt']; return x is Timestamp && y is Timestamp ? y.compareTo(x) : 0; });
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8), child: Row(children:[Expanded(child: Text(name, style: const TextStyle(fontSize:21,fontWeight:FontWeight.w900))), IconButton(onPressed:()=>_editProfile(name,bio),icon:const Icon(Icons.edit_outlined,color:Color(0xFFFFC107))),IconButton(onPressed:()=>AuthService.instance.logout(),icon:const Icon(Icons.logout_rounded,color:Colors.white60))]))),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18,6,18,18), child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[GestureDetector(onTap:()=>_openPhoto(photo,name),child:CircleAvatar(radius:46,backgroundColor:const Color(0xFFFFC107),child:CircleAvatar(radius:42,backgroundColor:const Color(0xFF171C24),backgroundImage:photo.isNotEmpty?NetworkImage(photo):null,child:photo.isEmpty?const Icon(Icons.person,size:46):null))),const SizedBox(width:18),Expanded(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_Stat('${posts.length}','Gönderi'),StreamBuilder<int>(stream:SocialService.instance.followersCount(widget.user.uid),builder:(_,s)=>_Stat('${s.data??0}','Takipçi',onTap:()=>_openFollowList(true))),StreamBuilder<int>(stream:SocialService.instance.followingCount(widget.user.uid),builder:(_,s)=>_Stat('${s.data??0}','Takip',onTap:()=>_openFollowList(false)))]))]),
              const SizedBox(height:14),Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(bio.trim().isEmpty?'Profiline bir açıklama ekle':bio,style:TextStyle(color:bio.trim().isEmpty?Colors.white38:Colors.white70,height:1.35)),const SizedBox(height:14),SizedBox(width:double.infinity,height:42,child:OutlinedButton(onPressed:()=>_editProfile(name,bio),child:const Text('Profili Düzenle')))
            ]))),
            const SliverToBoxAdapter(child:Divider(height:1,color:Colors.white12)),
            if (ss.connectionState==ConnectionState.waiting) const SliverFillRemaining(child:Center(child:CircularProgressIndicator(color:Color(0xFFFFC107))))
            else if(posts.isEmpty) SliverFillRemaining(hasScrollBody:false,child:Center(child:FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const CreatePostScreen())),icon:const Icon(Icons.add_a_photo_outlined),label:const Text('İlk Fotoğrafını Paylaş'))))
            else SliverPadding(padding:const EdgeInsets.fromLTRB(0,2,0,100),sliver:SliverGrid(gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:2,mainAxisSpacing:2),delegate:SliverChildBuilderDelegate((context,i){final data=posts[i].data();final url=(data['imageUrl']??'').toString();return GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PostDetailScreen(post:data))),onLongPressStart:(_)=>_showPreview(url),onLongPressEnd:(_)=>_hidePreview(),child:Container(color:const Color(0xFF171C24),child:url.isEmpty?const Icon(Icons.image_outlined,color:Colors.white30):Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined,color:Colors.white30))));},childCount:posts.length)))
          ]);
        },
      );
    },
  ));

  Future<void> _editProfile(String name,String bio) async {
    final nc=TextEditingController(text:name), bc=TextEditingController(text:bio); File? file; bool saving=false;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:const Color(0xFF0D1117),builder:(sheet)=>StatefulBuilder(builder:(context,setS){Future<void> pick() async {final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:1200);if(x!=null)setS(()=>file=File(x.path));} return Padding(padding:EdgeInsets.fromLTRB(20,16,20,MediaQuery.of(context).viewInsets.bottom+24),child:SingleChildScrollView(child:Column(children:[Row(children:[const Expanded(child:Text('Profili Düzenle',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(sheet),icon:const Icon(Icons.close))]),GestureDetector(onTap:pick,child:CircleAvatar(radius:48,backgroundImage:file!=null?FileImage(file!):null,child:file==null?const Icon(Icons.add_a_photo_outlined):null)),TextButton(onPressed:pick,child:const Text('Profil fotoğrafı seç')),TextField(controller:nc,decoration:const InputDecoration(labelText:'Ad / kullanıcı adı')),const SizedBox(height:12),TextField(controller:bc,maxLength:160,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'Açıklama')),const SizedBox(height:14),SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:saving?null:()async{setS(()=>saving=true);try{await ProfileService.instance.updateProfile(displayName:nc.text,bio:bc.text,photo:file);if(sheet.mounted)Navigator.pop(sheet);}catch(e){setS(()=>saving=false);}},child:Text(saving?'Kaydediliyor...':'Kaydet')))]))));})); nc.dispose();bc.dispose();
  }
}

class _Stat extends StatelessWidget { final String value,label; final VoidCallback? onTap; const _Stat(this.value,this.label,{this.onTap}); @override Widget build(BuildContext context){final c=Column(mainAxisSize:MainAxisSize.min,children:[Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:Colors.white60,fontSize:12))]);return onTap==null?c:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(6),child:c));}}
