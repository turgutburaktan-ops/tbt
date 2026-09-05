import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../widgets/firebase_media_image.dart';
import 'event_deep_link_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';
  final Map<String, Future<Map<String, dynamic>>> _actorCache = {};

  static const _eventTypes = <String>{
    'event_join','social_event_join','event_cancelled','social_event_cancelled',
    'community_event','event_memory','campus_digest',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await AppNotificationService.instance.markAllRead();
      await AppNotificationService.instance.refreshCampusDigest();
    });
  }

  bool _opensEvent(String type) => _eventTypes.contains(type);
  bool _isSocial(String type) => type == 'follow' || type.startsWith('post_') || type.startsWith('story_');

  IconData _iconFor(String type) {
    switch (type) {
      case 'follow': return Icons.person_add_alt_1_rounded;
      case 'post_like': case 'story_like': return Icons.favorite_rounded;
      case 'post_comment': return Icons.mode_comment_rounded;
      case 'post_tag': return Icons.alternate_email_rounded;
      case 'story_reaction': return Icons.emoji_emotions_rounded;
      case 'event_join': case 'social_event_join': return Icons.group_add_rounded;
      case 'event_cancelled': case 'social_event_cancelled': return Icons.event_busy_rounded;
      case 'community_event': return Icons.groups_2_rounded;
      case 'event_memory': return Icons.photo_library_rounded;
      case 'campus_digest': return Icons.school_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _accentFor(String type) {
    if (type == 'post_like' || type == 'story_like') return const Color(0xFFFF8FA3);
    if (_opensEvent(type)) return const Color(0xFF45C9C5);
    if (_isSocial(type)) return const Color(0xFF8172FF);
    return const Color(0xFFB7BCC2);
  }

  Future<Map<String, dynamic>> _loadActor(String actorId) async {
    if (actorId.isEmpty) return const {};
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(actorId).get().timeout(const Duration(seconds: 5));
      return doc.data() ?? const {};
    } catch (_) { return const {}; }
  }

  Future<Map<String, dynamic>> _actor(String id) => _actorCache.putIfAbsent(id, () => _loadActor(id));

  Future<void> _openItem(AppNotificationItem item) async {
    await AppNotificationService.instance.markRead(item.id);
    if (!mounted) return;
    final sourceId = item.sourceId?.trim() ?? '';
    final actorId = item.actorId?.trim() ?? '';
    if (sourceId.isNotEmpty && _opensEvent(item.type)) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: sourceId)));
      return;
    }
    if (item.type.startsWith('post_') && sourceId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(sourceId).get();
      if (!mounted) return;
      if (doc.exists) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...?doc.data(), 'id': doc.id})));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu paylaşım artık mevcut değil.')));
      }
      return;
    }
    if ((item.type == 'follow' || item.type.startsWith('story_')) && actorId.isNotEmpty) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: actorId)));
    }
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'Dün ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${local.day.toString().padLeft(2,'0')}.${local.month.toString().padLeft(2,'0')}';
  }

  String _groupLabel(DateTime? value) {
    if (value == null) return 'Daha eski';
    final d = value.toLocal(), now = DateTime.now();
    final days = DateTime(now.year,now.month,now.day).difference(DateTime(d.year,d.month,d.day)).inDays;
    if (days <= 0) return 'Bugün';
    if (days == 1) return 'Dün';
    return 'Daha eski';
  }

  bool _matchesFilter(AppNotificationItem item) {
    if (_filter == 'social') return _isSocial(item.type);
    if (_filter == 'events') return _opensEvent(item.type);
    return true;
  }

  Widget _filterChip(String key, String label, IconData icon) {
    final selected = _filter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: selected ? const LinearGradient(colors: [Color(0xFF43D5D0), Color(0xFF7C5CFF)]) : null,
          color: selected ? null : const Color(0xFF151719),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: selected ? Colors.white : Colors.white60),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _iconBubble(String type) {
    final accent = _accentFor(type);
    return Container(width: 50,height: 50,decoration: BoxDecoration(color: accent.withValues(alpha:.16),shape: BoxShape.circle),child: Icon(_iconFor(type),color: accent,size: 23));
  }

  Widget _leading(AppNotificationItem item) {
    if (item.type == 'tbt_broadcast') {
      return const CircleAvatar(radius: 25, backgroundColor: Color(0xFF29444D),
        child: Text('TBT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)));
    }
    final actorId = item.actorId?.trim() ?? '';
    if (actorId.isEmpty) return _iconBubble(item.type);
    return FutureBuilder<Map<String,dynamic>>(
      future: _actor(actorId),
      builder: (_, snapshot) {
        final photoUrl = (snapshot.data?['photoUrl'] ?? '').toString();
        return Stack(clipBehavior: Clip.none, children: [
          SizedBox(width:50,height:50,child:ClipOval(child:FirebaseMediaImage(imageUrl:photoUrl,fallbackStoragePaths:FirebaseMediaImage.avatarPaths(actorId),fit:BoxFit.cover,errorWidget:const ColoredBox(color:Color(0xFF1A1D20),child:Icon(Icons.person_rounded,color:Colors.white54))))),
          Positioned(right:-3,bottom:-3,child:Container(width:23,height:23,decoration:BoxDecoration(color:_accentFor(item.type),shape:BoxShape.circle,border:Border.all(color:const Color(0xFF090A0C),width:2)),child:Icon(_iconFor(item.type),size:12,color:Colors.black))),
        ]);
      },
    );
  }

  Widget _itemRow(AppNotificationItem item) {
    return InkWell(
      onTap: () => _openItem(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _leading(item),
          const SizedBox(width:14),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(item.title.isEmpty?'Bildirim':item.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:14.5,height:1.28,fontWeight:FontWeight.w800)),
            if(item.body.isNotEmpty)...[const SizedBox(height:3),Text(item.body,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:13,height:1.3))],
          ])),
          const SizedBox(width:10),
          ConstrainedBox(constraints:const BoxConstraints(maxWidth:82),child:Text(_timeLabel(item.createdAt),textAlign:TextAlign.right,style:const TextStyle(color:Colors.white70,fontSize:11.5,height:1.2))),
          if(!item.read)...[const SizedBox(width:9),Container(width:8,height:8,decoration:const BoxDecoration(color:Color(0xFF8066FF),shape:BoxShape.circle))],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF090A0C),
    appBar: AppBar(
      backgroundColor: const Color(0xFF090A0C),foregroundColor:Colors.white,elevation:0,
      title: const Text('Bildirimler',style:TextStyle(fontWeight:FontWeight.w900)),
      actions:[PopupMenuButton<String>(tooltip:'Bildirim seçenekleri',color:const Color(0xFF181A1D),onSelected:(v){if(v=='read_all') AppNotificationService.instance.markAllRead();},itemBuilder:(_)=>const[PopupMenuItem(value:'read_all',child:Row(children:[Icon(Icons.done_all_rounded,size:20),SizedBox(width:10),Text('Tümünü okundu yap')]))]),const SizedBox(width:4)],
    ),
    body: StreamBuilder<List<AppNotificationItem>>(
      stream: AppNotificationService.instance.watchMine(),
      builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
        final allItems=snapshot.data??const <AppNotificationItem>[];
        final items=allItems.where(_matchesFilter).toList(growable:false);
        return Column(children:[
          SizedBox(height:52,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.fromLTRB(16,4,16,4),children:[_filterChip('all','Tümü',Icons.notifications_none_rounded),const SizedBox(width:10),_filterChip('social','Sosyal',Icons.people_alt_outlined),const SizedBox(width:10),_filterChip('events','Etkinlik',Icons.event_outlined)])),
          const SizedBox(height:8),
          Expanded(child:items.isEmpty?const Center(child:Text('Bu bölümde bildirim yok',style:TextStyle(color:Colors.white60))):ListView.builder(
            padding:const EdgeInsets.fromLTRB(18,0,18,28),itemCount:items.length,itemBuilder:(context,index){
              final item=items[index], group=_groupLabel(item.createdAt), previous=index==0?null:_groupLabel(items[index-1].createdAt);
              return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(group!=previous) Padding(padding:EdgeInsets.only(top:index==0?10:20,bottom:4),child:Text(group,style:const TextStyle(color:Colors.white70,fontSize:14,fontWeight:FontWeight.w900))),
                _itemRow(item),
                if(index<items.length-1) const Divider(height:1,color:Color(0xFF24272A),indent:64),
              ]);
            },
          )),
        ]);
      },
    ),
  );
}
