import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../services/content_engagement_service.dart';
import '../services/post_service.dart';
import '../services/social_event_service.dart';
import '../services/social_service.dart';
import '../widgets/app_video_player.dart';
import '../widgets/content_engagement_bar.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/post_media_carousel.dart';
import 'social_events_screen.dart';
import 'user_profile_screen.dart';

enum FeedMode { forYou, following }

class FeedScreen extends StatelessWidget {
  final FeedMode mode;
  final bool embedded;
  final bool includeEvents;

  const FeedScreen({
    super.key,
    this.mode = FeedMode.forYou,
    this.embedded = false,
    this.includeEvents = true,
  });

  List<String> _strings(dynamic value) => value is Iterable
      ? value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList()
      : const <String>[];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final body = currentUser == null
        ? const _SignedOutFeed()
        : StreamBuilder<List<String>>(
            stream: SocialService.instance.followingIds(),
            builder: (context, followingSnapshot) {
              if (followingSnapshot.connectionState == ConnectionState.waiting) return const _FeedLoading();
              final followingIds = followingSnapshot.data ?? <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(120).snapshots(),
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState == ConnectionState.waiting) return const _FeedLoading();
                  if (postsSnapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('Akış yüklenemedi.\n${postsSnapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))));
                  final docs = postsSnapshot.data?.docs.toList() ?? [];
                  if (mode == FeedMode.following) {
                    docs.removeWhere((doc) { final owner = (doc.data()['userId'] ?? '').toString(); return owner != currentUser.uid && !followingIds.contains(owner); });
                  } else {
                    docs.sort((a, b) {
                      final aOwner = (a.data()['userId'] ?? '').toString();
                      final bOwner = (b.data()['userId'] ?? '').toString();
                      final aFollowing = followingIds.contains(aOwner) ? 1 : 0;
                      final bFollowing = followingIds.contains(bOwner) ? 1 : 0;
                      if (aFollowing != bFollowing) return bFollowing.compareTo(aFollowing);
                      final aTime = a.data()['createdAt']; final bTime = b.data()['createdAt'];
                      if (aTime is Timestamp && bTime is Timestamp) return bTime.compareTo(aTime);
                      return 0;
                    });
                  }
                  return StreamBuilder<List<SocialEvent>>(
                    stream: SocialEventService.instance.watchUpcoming(limit: 50),
                    builder: (context, eventsSnapshot) {
                      final now = DateTime.now();
                      var events = (includeEvents ? eventsSnapshot.data ?? const <SocialEvent>[] : const <SocialEvent>[]).where((event) {
                        final visible = event.visibility == EventVisibility.public || event.hostId == currentUser.uid || event.participantIds.contains(currentUser.uid) || event.allowedUserIds.contains(currentUser.uid);
                        if (!visible) return false;
                        if (mode == FeedMode.following && !(followingIds.contains(event.hostId) || event.participantIds.any(followingIds.contains))) return false;
                        return true;
                      }).toList()..sort((a,b)=>a.startsAt.compareTo(b.startsAt));
                      final tonight = events.where((event) { final d=event.startsAt.toLocal(); return d.year==now.year&&d.month==now.month&&d.day==now.day; }).take(6).toList();
                      final feedItems=<Widget>[];
                      if(mode==FeedMode.forYou&&tonight.isNotEmpty) feedItems.add(_TonightStrip(events:tonight,followingIds:followingIds));
                      var eventIndex=0;
                      for(var i=0;i<docs.length;i++){
                        final doc=docs[i]; final data=doc.data(); final videoUrl=(data['videoUrl']??'').toString(); final mediaType=(data['mediaType']??'').toString();
                        var mediaUrls=_strings(data['mediaUrls']); var mediaPaths=_strings(data['mediaStoragePaths']);
                        final legacyUrl=(data['imageUrl']??'').toString(); final legacyPath=(data['storagePath']??'').toString();
                        if(mediaUrls.isEmpty&&legacyUrl.isNotEmpty) mediaUrls=[legacyUrl];
                        if(mediaPaths.isEmpty&&legacyPath.isNotEmpty) mediaPaths=[legacyPath];
                        feedItems.add(_FeedPostCard(postId:doc.id,userId:(data['userId']??'').toString(),userName:(data['userName']??'Topluluk üyesi').toString(),userPhotoUrl:(data['userPhotoUrl']??data['photoUrl']??'').toString(),mediaType:mediaType=='video'||videoUrl.isNotEmpty?'video':'image',imageUrl:legacyUrl,storagePath:legacyPath,mediaUrls:mediaUrls,mediaStoragePaths:mediaPaths,videoUrl:videoUrl,videoStoragePath:(data['videoStoragePath']??'').toString(),thumbnailUrl:(data['thumbnailUrl']??data['imageUrl']??'').toString(),thumbnailStoragePath:(data['thumbnailStoragePath']??data['storagePath']??'').toString(),caption:(data['caption']??'').toString(),spotName:(data['spotName']??'').toString(),createdAt:data['createdAt']));
                        if((i+1)%4==0&&eventIndex<events.length) feedItems.add(_EventFeedCard(event:events[eventIndex++],followingIds:followingIds));
                      }
                      while(eventIndex<events.length&&feedItems.length<10) feedItems.add(_EventFeedCard(event:events[eventIndex++],followingIds:followingIds));
                      if(docs.isEmpty&&events.isEmpty) feedItems.add(_EmptyFeed(mode:mode));
                      return RefreshIndicator(onRefresh:()=>Future<void>.delayed(const Duration(milliseconds:450)),child:ListView.builder(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.only(bottom:34),itemCount:feedItems.length,itemBuilder:(_,i)=>feedItems[i]));
                    },
                  );
                },
              );
            },
          );
    if(embedded)return body;
    return Scaffold(backgroundColor:const Color(0xFF090A0C),appBar:AppBar(backgroundColor:const Color(0xFF090A0C),title:Text(mode==FeedMode.following?'Takip':'Sana Özel')),body:body);
  }
}

class _TonightStrip extends StatelessWidget {
  final List<SocialEvent> events; final List<String> followingIds;
  const _TonightStrip({required this.events,required this.followingIds});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(10,4,0,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.only(right:10,bottom:8),child:Row(children:[const Expanded(child:Text('Bu Akşam 🔥',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SocialEventsScreen())),child:const Text('Tümünü gör'))])),SizedBox(height:154,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:events.length,separatorBuilder:(_,__)=>const SizedBox(width:9),itemBuilder:(_,i)=>SizedBox(width:230,child:_CompactEventCard(event:events[i],followingIds:followingIds))))]));
}
class _CompactEventCard extends StatelessWidget { final SocialEvent event; final List<String> followingIds; const _CompactEventCard({required this.event,required this.followingIds}); @override Widget build(BuildContext context){final friendCount=event.participantIds.where(followingIds.contains).length;final local=event.startsAt.toLocal();final time='${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF15181B),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF2A2E33))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:const Color(0xFF25292E),borderRadius:BorderRadius.circular(20)),child:Text(time,style:const TextStyle(fontWeight:FontWeight.w900))),const Spacer(),const Icon(Icons.groups_2_outlined,size:16,color:Colors.white54),const SizedBox(width:4),Text('${event.participantCount}',style:const TextStyle(fontSize:12,color:Colors.white70))]),const SizedBox(height:10),Text(event.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(event.locationLabel.isNotEmpty?event.locationLabel:event.city,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:Colors.white54)),const Spacer(),if(friendCount>0)Text('$friendCount takip ettiğin kişi katılıyor',style:const TextStyle(fontSize:11,color:Color(0xFFB7BCC2),fontWeight:FontWeight.w800))]));}}
class _EventFeedCard extends StatelessWidget { final SocialEvent event; final List<String> followingIds; const _EventFeedCard({required this.event,required this.followingIds}); @override Widget build(BuildContext context){final uid=FirebaseAuth.instance.currentUser?.uid;final joined=uid!=null&&event.participantIds.contains(uid);final friendCount=event.participantIds.where(followingIds.contains).length;final local=event.startsAt.toLocal();final date='${local.day.toString().padLeft(2,'0')}.${local.month.toString().padLeft(2,'0')} • ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';Future<void> join()async{try{await SocialEventService.instance.join(event.id);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Etkinliğe katıldın.')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}return Container(margin:const EdgeInsets.fromLTRB(10,5,10,13),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF121416),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF2A2E33))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFF202327),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.celebration_outlined)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Yakınında bir etkinlik var',style:TextStyle(color:Colors.white54,fontSize:11,fontWeight:FontWeight.w700)),Text(event.hostName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900))])),if(friendCount>0)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:const Color(0xFF23272B),borderRadius:BorderRadius.circular(12)),child:Text('$friendCount arkadaş',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)))]),const SizedBox(height:14),Text(event.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:8),Row(children:[const Icon(Icons.schedule,size:16,color:Colors.white54),const SizedBox(width:6),Text(date,style:const TextStyle(color:Colors.white70))]),const SizedBox(height:6),Row(children:[const Icon(Icons.place_outlined,size:16,color:Colors.white54),const SizedBox(width:6),Expanded(child:Text(event.locationLabel.isNotEmpty?'${event.locationLabel} • ${event.city}':event.city,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70)))]),const SizedBox(height:6),Row(children:[const Icon(Icons.groups_2_outlined,size:16,color:Colors.white54),const SizedBox(width:6),Text('${event.participantCount} kişi katılıyor',style:const TextStyle(color:Colors.white70))]),const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SocialEventsScreen())),child:const Text('Etkinliği Gör'))),const SizedBox(width:9),Expanded(child:FilledButton(onPressed:joined||event.isFull?null:join,child:Text(joined?'Katıldın':event.isFull?'Dolu':'Katıl')))]),const SizedBox(height:5),ContentEngagementBar(collection:'social_events',contentId:event.id,ownerId:event.hostId,title:event.title,sourceType:'social_event')]));}}
class _SignedOutFeed extends StatelessWidget{const _SignedOutFeed();@override Widget build(BuildContext context)=>const Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.dynamic_feed_outlined,size:62,color:Colors.white38),SizedBox(height:14),Text('Sosyal akış için giriş yap',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('Takip ettiğin kişilerin fotoğraf ve videolarını, keşiflerini ve etkinlik anılarını burada göreceksin.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white60,height:1.4))])));}
class _EmptyFeed extends StatelessWidget{final FeedMode mode;const _EmptyFeed({required this.mode});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(30),child:Column(children:[const SizedBox(height:36),Icon(mode==FeedMode.following?Icons.people_outline_rounded:Icons.photo_library_outlined,size:66,color:Colors.white30),const SizedBox(height:16),Text(mode==FeedMode.following?'Takip akışın henüz sakin':'Henüz paylaşım yok',textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(mode==FeedMode.following?'Yeni insanları takip ettikçe onların paylaşımları ve katıldıkları etkinlikler burada görünür.':'İlk fotoğraf, video ve etkinlik anıları geldikçe burası canlanacak.',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white54,height:1.4))]));}

class _FeedPostCard extends StatelessWidget{
 final String postId,userId,userName,userPhotoUrl,mediaType,imageUrl,storagePath,videoUrl,videoStoragePath,thumbnailUrl,thumbnailStoragePath,caption,spotName; final List<String> mediaUrls,mediaStoragePaths; final dynamic createdAt;
 const _FeedPostCard({required this.postId,required this.userId,required this.userName,required this.userPhotoUrl,required this.mediaType,required this.imageUrl,required this.storagePath,required this.mediaUrls,required this.mediaStoragePaths,required this.videoUrl,required this.videoStoragePath,required this.thumbnailUrl,required this.thumbnailStoragePath,required this.caption,required this.spotName,required this.createdAt});
 bool get _isVideo=>mediaType=='video'&&videoUrl.isNotEmpty;
 String _timeLabel(){if(createdAt is! Timestamp)return'';final date=(createdAt as Timestamp).toDate();final diff=DateTime.now().difference(date);if(diff.inMinutes<1)return'şimdi';if(diff.inMinutes<60)return'${diff.inMinutes} dk';if(diff.inHours<24)return'${diff.inHours} sa';if(diff.inDays<7)return'${diff.inDays} gün';return'${date.day}.${date.month}.${date.year}';}
 Widget _media(BuildContext context){if(_isVideo)return AppVideoPlayer.network(url:videoUrl,autoplay:true,muted:true,loop:true,showControls:true,fit:BoxFit.cover,loading:FirebaseMediaImage(imageUrl:thumbnailUrl,storagePath:thumbnailStoragePath,width:double.infinity,height:double.infinity,fit:BoxFit.cover));return PostMediaCarousel(imageUrls:mediaUrls.isEmpty?<String>[imageUrl]:mediaUrls,storagePaths:mediaStoragePaths.isEmpty?<String>[storagePath]:mediaStoragePaths,fallbackStoragePaths:FirebaseMediaImage.postPaths(userId,postId),fit:BoxFit.cover,onDoubleTap:()=>_doubleTapLike(context));}
 Future<void> _doubleTapLike(BuildContext context)async{if(postId.trim().isEmpty)return;try{final liked=await ContentEngagementService.instance.isLiked('posts',postId).first;if(liked)return;await ContentEngagementService.instance.toggleLike(collection:'posts',id:postId,ownerId:userId,title:caption.trim().isEmpty?(_isVideo?'Video paylaşımı':'Fotoğraf paylaşımı'):caption,sourceType:'post');}catch(e){if(context.mounted)ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _delete(BuildContext context)async{final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Gönderiyi sil'),content:const Text('Bu gönderi kalıcı olarak silinecek. Devam etmek istiyor musun?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),style:FilledButton.styleFrom(backgroundColor:Colors.redAccent),child:const Text('Sil'))]));if(confirmed!=true||!context.mounted)return;try{await PostService.instance.deletePost(postId:postId,storagePath:storagePath,videoStoragePath:videoStoragePath,thumbnailStoragePath:thumbnailStoragePath);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Gönderi silindi.')));}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.fromLTRB(8,4,8,14),decoration:BoxDecoration(color:const Color(0xFF0E1012),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF20242A))),clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[InkWell(onTap:userId.isEmpty?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserProfileScreen(userId:userId))),child:Padding(padding:const EdgeInsets.fromLTRB(12,11,8,10),child:Row(children:[SizedBox(width:40,height:40,child:ClipOval(child:FirebaseMediaImage(imageUrl:userPhotoUrl,fallbackStoragePaths:FirebaseMediaImage.avatarPaths(userId),errorWidget:const ColoredBox(color:Color(0xFF22262A),child:Center(child:Icon(Icons.person_outline,color:Colors.white60)))))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Flexible(child:Text(userName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15))),if(_isVideo)...[const SizedBox(width:6),const Icon(Icons.videocam_rounded,size:16,color:Colors.white54)]]),Row(children:[if(spotName.isNotEmpty)...[const Icon(Icons.location_on_outlined,size:13,color:Colors.white54),const SizedBox(width:2),Flexible(child:Text(spotName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Colors.white54))),const Text('  •  ',style:TextStyle(color:Colors.white30))],Text(_timeLabel(),style:const TextStyle(fontSize:11,color:Colors.white38))])])),if(FirebaseAuth.instance.currentUser?.uid==userId)PopupMenuButton<String>(tooltip:'Gönderi seçenekleri',onSelected:(v){if(v=='delete')_delete(context);},itemBuilder:(_)=>const[PopupMenuItem<String>(value:'delete',child:Row(children:[Icon(Icons.delete_outline_rounded,color:Colors.redAccent),SizedBox(width:10),Text('Gönderiyi sil')]))],icon:const Icon(Icons.more_horiz_rounded,color:Colors.white70))else const Icon(Icons.more_horiz_rounded,color:Colors.white38)]))),AspectRatio(aspectRatio:4/5,child:_media(context)),Padding(padding:const EdgeInsets.fromLTRB(8,4,8,0),child:ContentEngagementBar(collection:'posts',contentId:postId,ownerId:userId,title:caption.trim().isEmpty?(_isVideo?'Video paylaşımı':'Fotoğraf paylaşımı'):caption,sourceType:'post')),if(caption.trim().isNotEmpty)Padding(padding:const EdgeInsets.fromLTRB(13,0,13,8),child:Text.rich(TextSpan(children:[TextSpan(text:'$userName ',style:const TextStyle(fontWeight:FontWeight.w900)),TextSpan(text:caption,style:const TextStyle(color:Colors.white70,height:1.35))]))),const SizedBox(height:4)]));
}
class _FeedLoading extends StatelessWidget{const _FeedLoading();@override Widget build(BuildContext context)=>ListView.separated(physics:const NeverScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(14,10,14,28),itemCount:3,separatorBuilder:(_,__)=>const SizedBox(height:14),itemBuilder:(_,__)=>Container(height:290,decoration:BoxDecoration(color:const Color(0xFF121416),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white10)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:EdgeInsets.all(14),child:Row(children:[CircleAvatar(radius:18,backgroundColor:Color(0xFF25292D)),SizedBox(width:10),Expanded(child:SizedBox(height:12,child:DecoratedBox(decoration:BoxDecoration(color:Color(0xFF25292D)))))])),Expanded(child:ColoredBox(color:Color(0xFF1A1D20)))])));}
