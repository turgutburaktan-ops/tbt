import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/social_event.dart';
import '../services/event_chat_service.dart';
import '../services/user_facing_error.dart';
import '../widgets/route_chat_bubble.dart';
import '../widgets/event_chat_attachment.dart';
import '../widgets/chat_voice_message.dart';
import 'event_location_picker_screen.dart';
import 'user_profile_screen.dart';

class EventChatScreen extends StatefulWidget {
  const EventChatScreen({super.key, required this.event});
  final SocialEvent event;
  @override State<EventChatScreen> createState() => _EventChatScreenState();
}
class _EventChatScreenState extends State<EventChatScreen> {
  final _text = TextEditingController(), _scroll = ScrollController();
  Map<String, dynamic>? _reply;
  bool _busy = false;
  late final _messages = EventChatService.instance.messages(widget.event.id).orderBy('createdAt', descending: true).limit(120).snapshots();
  late final _event = FirebaseFirestore.instance.collection('social_events').doc(widget.event.id).snapshots();
  late final _info = FirebaseFirestore.instance.collection('social_events').doc(widget.event.id).collection('info').doc('main').snapshots();
  @override void dispose() { _text.dispose(); _scroll.dispose(); super.dispose(); }
  void _error(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(e)))); }
  Future<void> _run(Future<void> Function(Map<String, dynamic>? reply) send, {String? text}) async {
    if (_busy) return;
    final reply = _reply; setState(() => _busy = true);
    try {
      await send(reply);
      if (!mounted) return;
      setState(() { if (identical(reply, _reply)) _reply = null; if (text != null && _text.text == text) _text.clear(); });
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } catch (e) { _error(e); } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _plus() async {
    final kind = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Fotoğraf / video'), onTap: () => Navigator.pop(c, 'media')),
      ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('Konum paylaş'), onTap: () => Navigator.pop(c, 'location')),
    ])));
    if (!mounted || kind == null) return;
    try {
      if (kind == 'media') {
        final file = await ImagePicker().pickMedia(); if (file == null || !mounted) return;
        await _run((reply) => EventChatService.instance.media(widget.event.id, file, reply: reply));
      } else {
        final p = await Navigator.push<EventLocationSelection>(context, MaterialPageRoute(builder: (_) => EventLocationPickerScreen(city: widget.event.city, addressLabel: '', title: 'Konum paylaş')));
        if (p == null || !mounted) return;
        await _run((reply) => EventChatService.instance.location(widget.event.id, p.label, p.latitude, p.longitude, reply: reply));
      }
    } catch (e) { _error(e); }
  }
  Widget _message(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool canWrite) {
    final d = doc.data(), uid = FirebaseAuth.instance.currentUser?.uid;
    final mine = d['senderId'] == uid, name = '${d['senderName'] ?? 'Katılımcı'}', text = '${d['text'] ?? ''}';
    final at = d['createdAt'];
    final date = at is Timestamp ? at.toDate().toLocal() : null;
    final time = date == null ? '' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final type = d['type'] ?? 'text';
    Widget? attachment;
    if (['image','video','audio'].contains(type)) attachment = EventChatAttachment(eventId: widget.event.id, messageId: doc.id, data: d, mine: mine);
    if (type == 'location') attachment = TextButton.icon(icon: const Icon(Icons.location_on_outlined), label: const Text('Haritada aç'), onPressed: () async {
      try { final uri = Uri.https('www.google.com', '/maps/search/', {'api':'1','query':'${d['latitude']},${d['longitude']}'}); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception('Harita açılamadı.'); } catch(e) { _error(e); }
    });
    return RouteChatBubble(key: ValueKey(doc.id), mine: mine, name: name, text: text, time: time, pending: doc.metadata.hasPendingWrites, attachment: attachment,
      replyText: d['reply'] is Map ? '${d['reply']['name']}: ${d['reply']['text']}' : null,
      onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: '${d['senderId']}'))),
      onReply: () { if (canWrite) setState(() => _reply = {'id':doc.id,'name':name,'text':text.substring(0,text.length.clamp(0,300))}); },
    );
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF08090B), appBar: AppBar(title: Text(widget.event.title)),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: _event, builder: (context, eventSnap) {
      final e = eventSnap.data?.data(), uid = FirebaseAuth.instance.currentUser?.uid;
      final member = uid != null && e != null && (e['hostId'] == uid || (e['participantIds'] as List? ?? []).contains(uid));
      final canWrite = member && e?['status'] == 'open';
      if (!eventSnap.hasData && !eventSnap.hasError) return const Center(child: CircularProgressIndicator());
      if (!member) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sohbet yalnızca etkinlik katılımcılarına açık.')));
      return Column(children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: _info, builder: (_, s) {
          final text = '${s.data?.data()?['announcement'] ?? ''}';
          return text.isEmpty ? const SizedBox.shrink() : ListTile(leading: const Icon(Icons.push_pin_outlined), title: Text(text));
        }),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _messages, builder: (_, s) {
          if (s.hasError) return const Center(child: Text('Mesajlar yüklenemedi. Bağlantını ve katılımını kontrol et.'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs;
          if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.forum_outlined, size:36, color:Color(0xFF9828FF)), SizedBox(height:14), Text('Etkinliğin sohbeti burada', style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)), SizedBox(height:8), Text('Bir merhaba yaz veya buluşma için konum paylaş.', textAlign:TextAlign.center,style:TextStyle(color:Colors.white60))])));
          return ListView.builder(controller:_scroll, reverse:true, padding:const EdgeInsets.symmetric(vertical:14), itemCount:docs.length, itemBuilder:(_,i)=>_message(docs[i],canWrite));
        })),
        if (!canWrite) const SafeArea(top:false, child:Padding(padding:EdgeInsets.all(16),child:Text('Etkinlik iptal edildi. Yeni mesaj gönderilemez.')))
        else Container(decoration:const BoxDecoration(color:Color(0xFF14161B),border:Border(top:BorderSide(color:Color(0xFF262832)))),child:SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(8),child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(_reply!=null) Row(children:[const Icon(Icons.reply,size:18,color:Color(0xFF9828FF)),const SizedBox(width:8),Expanded(child:Text('${_reply!['name']}: ${_reply!['text']}',maxLines:2,overflow:TextOverflow.ellipsis)),IconButton(onPressed:()=>setState(()=>_reply=null),icon:const Icon(Icons.close))]),
          Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            IconButton(tooltip:'Fotoğraf, video veya konum ekle',onPressed:_busy?null:_plus,icon:const Icon(Icons.add_circle_outline,color:Color(0xFF267CFF))),
            Expanded(child:TextField(controller:_text,minLines:1,maxLines:4,maxLength:1500,onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'Gruba mesaj yaz',counterText:'',filled:true,fillColor:Color(0xFF20232C),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(24)),borderSide:BorderSide.none),contentPadding:EdgeInsets.symmetric(horizontal:15,vertical:12)))),
            if(_text.text.trim().isNotEmpty) IconButton.filled(tooltip:'Gönder',onPressed:_busy?null:(){final text=_text.text;_run((reply)=>EventChatService.instance.send(widget.event.id,text,reply:reply),text:text);},style:IconButton.styleFrom(backgroundColor:const Color(0xFF267CFF),foregroundColor:Colors.white),icon:const Icon(Icons.arrow_upward_rounded))
            else ChatVoiceRecordButton(disabled:_busy,onError:_error,onRecorded:(bytes,duration)=>_run((reply)=>EventChatService.instance.audio(widget.event.id,bytes,duration,reply:reply))),
          ]),
        ])))),
      ]);
    }),
  );
}
