import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_context_link_service.dart';
import '../services/story_service.dart';
import 'story_context_template_picker.dart';

class StoryPhotoEditorScreen extends StatefulWidget {
  final File photo;
  const StoryPhotoEditorScreen({super.key, required this.photo});
  @override
  State<StoryPhotoEditorScreen> createState() => _StoryPhotoEditorScreenState();
}

class _StoryPhotoEditorScreenState extends State<StoryPhotoEditorScreen> {
  final _canvasKey = GlobalKey();
  final _textController = TextEditingController();
  final _textFocus = FocusNode();
  final _picker = ImagePicker();
  final List<_OverlayItem> _items = [];
  final List<_Stroke> _strokes = [];
  final List<File?> _layoutSlots = [];
  int? _selected;
  int _layoutCount = 0;
  StoryContextTemplateSelection? _contextTemplate;
  bool _sharing = false, _exporting = false, _editingText = false, _drawing = false, _editingBackground = false, _moving = false, _overTrash = false;
  _Stroke? _activeStroke;
  double _bgScale = 1, _bgRotation = 0, _bgStartScale = 1, _bgStartRotation = 0;
  Offset _bgOffset = Offset.zero;
  String _font = 'sans-serif';
  Color _textColor = Colors.white, _drawColor = Colors.white;

  static const _fonts = ['sans-serif', 'serif', 'monospace', 'sans-serif-medium', 'sans-serif-light'];
  static const _colors = [Colors.white, Colors.black, Color(0xFFFFE25C), Color(0xFFFF5C8A), Color(0xFF74E7FF), Color(0xFFC79AFF), Color(0xFF8EFFB5)];
  static const _emojis = ['😂','❤️','😍','🔥','🥰','😭','👏','✨','😎','🥳','🤍','💜','💯','🙌','🤩','😋','🌟','🎉','📸','📍','✈️','☕','🍕','🌊','🌅','🎶','⚡','🫶','🤝','😜'];

  @override
  void dispose() { _textFocus.dispose(); _textController.dispose(); super.dispose(); }

  void _finishMode() {
    if (_editingText && _textController.text.trim().isNotEmpty) { _commitText(); return; }
    _textFocus.unfocus();
    setState(() { _editingText = false; _drawing = false; _editingBackground = false; _selected = null; _activeStroke = null; _moving = false; _overTrash = false; });
  }

  void _openText() {
    if (_sharing) return;
    setState(() { _editingText = true; _drawing = false; _editingBackground = false; _selected = null; _textController.clear(); _font = _fonts.first; _textColor = Colors.white; });
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _textFocus.requestFocus(); });
  }

  void _commitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) { setState(() => _editingText = false); _textFocus.unfocus(); return; }
    final s = MediaQuery.sizeOf(context);
    setState(() { _items.add(_OverlayItem.text(text, Offset(s.width * .5, s.height * .43), _font, _textColor)); _selected = _items.length - 1; _editingText = false; _textController.clear(); });
    _textFocus.unfocus();
  }

  Future<void> _openEmojiPicker() async {
    if (_sharing) return;
    _finishMode();
    final emoji = await showModalBottomSheet<String>(context: context, useSafeArea: true, backgroundColor: const Color(0xFF111318), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))), builder: (c) => Padding(padding: const EdgeInsets.fromLTRB(18,12,18,22), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(99))), const SizedBox(height:14), const Align(alignment:Alignment.centerLeft,child:Text('Emoji',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))), const SizedBox(height:16), GridView.builder(shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:6,mainAxisSpacing:8,crossAxisSpacing:8), itemCount:_emojis.length, itemBuilder:(_,i)=>InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>Navigator.pop(c,_emojis[i]),child:Center(child:Text(_emojis[i],style:const TextStyle(fontSize:34)))))])));
    if (!mounted || emoji == null) return;
    final s = MediaQuery.sizeOf(context);
    setState(() { _items.add(_OverlayItem.emoji(emoji, Offset(s.width*.5,s.height*.43))); _selected = _items.length-1; });
  }

  Future<void> _addPhotos() async {
    final picked = await _picker.pickMultiImage(); if (!mounted || picked.isEmpty) return;
    final s=MediaQuery.sizeOf(context); final remaining=math.max(0,10-_items.where((e)=>e.photo!=null).length);
    setState(() { for(final x in picked.take(remaining)){_items.add(_OverlayItem.photo(File(x.path),Offset(s.width*.5,s.height*.43)));} if(_items.isNotEmpty)_selected=_items.length-1; });
  }

  Future<void> _openMentionPicker() async {
    _finishMode();
    final choice=await showModalBottomSheet<_Mention>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:const Color(0xFF101216),builder:(_)=>const _MentionSheet());
    if(!mounted||choice==null)return; final s=MediaQuery.sizeOf(context);
    setState((){_items.add(_OverlayItem.mention('@${choice.label}',choice.uid,Offset(s.width*.5,s.height*.46)));_selected=_items.length-1;});
  }

  Future<void> _openContextTemplates() async {
    _finishMode(); final selected=await Navigator.push<StoryContextTemplateSelection>(context,MaterialPageRoute(builder:(_)=>const StoryContextTemplatePicker())); if(!mounted||selected==null)return;
    final s=MediaQuery.sizeOf(context); setState((){_contextTemplate=selected;_layoutCount=selected.slotCount;_layoutSlots..clear()..addAll(List<File?>.filled(selected.slotCount,null)); if(selected.contextType!='free'&&selected.contextName.trim().isNotEmpty){_items.add(_OverlayItem.context('${_contextIcon(selected.contextType)} ${selected.contextName}',Offset(s.width*.5,s.height*.17)));} _items.add(_OverlayItem.context(selected.templateTitle,Offset(s.width*.5,s.height*.84),compact:true));_selected=_items.length-1;});
  }
  String _contextIcon(String t)=>t=='event'?'🎟️':t=='venue'?'📍':t=='spot'?'🗺️':'✨';

  Future<void> _chooseLayout() async {
    _finishMode();
    final count=await showModalBottomSheet<int>(context:context,useSafeArea:true,backgroundColor:const Color(0xFF101216),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(c)=>Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Yerleşim',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Her bölmeye ayrı fotoğraf ekle.',style:TextStyle(color:Colors.white60)),const SizedBox(height:16),Row(children:[for(final n in [2,4,8]) Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:FilledButton(onPressed:()=>Navigator.pop(c,n),child:Text('$n’li'))))]),if(_layoutCount>0)TextButton(onPressed:()=>Navigator.pop(c,0),child:const Text('Yerleşimi kaldır'))])));
    if(!mounted||count==null)return; setState((){_contextTemplate=null;_layoutCount=count;_layoutSlots..clear()..addAll(List<File?>.filled(count,null));_editingBackground=false;});
  }

  Future<void> _pickLayoutPhoto(int index) async {
    if(_sharing||_exporting||index<0||index>=_layoutSlots.length)return;
    final picked=await _picker.pickImage(source:ImageSource.gallery,imageQuality:95); if(!mounted||picked==null)return; setState(()=>_layoutSlots[index]=File(picked.path));
  }

  void _toggleDraw(){setState((){_drawing=!_drawing;_editingText=false;_editingBackground=false;_selected=null;});}
  void _toggleBackground(){if(_layoutCount>0)return;setState((){_editingBackground=!_editingBackground;_drawing=false;_editingText=false;_selected=null;});}
  void _removeSelected(){final i=_selected;if(i==null||i>=_items.length)return;setState((){_items.removeAt(i);_selected=null;_moving=false;_overTrash=false;});}

  Future<File> _renderStory() async {
    setState((){_selected=null;_editingText=false;_drawing=false;_editingBackground=false;_exporting=true;}); await WidgetsBinding.instance.endOfFrame;
    final object=_canvasKey.currentContext?.findRenderObject(); if(object is! RenderRepaintBoundary)throw Exception('Story hazırlanamadı.');
    try{final image=await object.toImage(pixelRatio:math.max(3.0,MediaQuery.devicePixelRatioOf(context)));final data=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();if(data==null)throw Exception('Story oluşturulamadı.');final file=File('${Directory.systemTemp.path}/tbt_story_${DateTime.now().microsecondsSinceEpoch}.png');await file.writeAsBytes(data.buffer.asUint8List());return file;}finally{if(mounted)setState(()=>_exporting=false);}
  }

  Future<void> _share() async {
    if(_sharing)return;setState(()=>_sharing=true);File? rendered;
    try{rendered=await _renderStory();final mentions=_items.map((e)=>e.targetUserId).whereType<String>().toSet().toList();await StoryService.instance.createStory(rendered,mentionedUserIds:mentions);final t=_contextTemplate;if(t!=null){await StoryContextLinkService.instance.attachToLatestOwnStory(contextType:t.contextType,contextId:t.contextId,contextName:t.contextName,templateId:t.templateId,templateTitle:t.templateTitle,slotCount:t.slotCount);}if(mounted)Navigator.pop(context,true);}catch(e){if(mounted){setState(()=>_sharing=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}finally{try{if(rendered!=null&&await rendered.exists())await rendered.delete();}catch(_){}}
  }

  Widget _background(){
    if(_layoutCount>0)return _layout();
    return ColoredBox(color:Colors.black,child:Transform.translate(offset:_bgOffset,child:Transform.rotate(angle:_bgRotation,child:Transform.scale(scale:_bgScale,child:Image.file(widget.photo,fit:BoxFit.contain,filterQuality:FilterQuality.high)))));
  }

  Widget _layout(){
    final rows=(_layoutCount/2).ceil();
    return ColoredBox(color:Colors.black,child:Column(children:List.generate(rows,(r)=>Expanded(child:Row(children:List.generate(2,(c){final i=r*2+c;if(i>=_layoutCount)return const Expanded(child:SizedBox());final f=_layoutSlots[i];return Expanded(child:Padding(padding:const EdgeInsets.all(2),child:Material(color:const Color(0xFF111318),child:InkWell(onTap:_exporting?null:()=>_pickLayoutPhoto(i),child:f==null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.add_rounded,size:36,color:Colors.white70),Text('${i+1}. fotoğraf',style:const TextStyle(color:Colors.white54))])):Image.file(f,fit:BoxFit.cover,width:double.infinity,height:double.infinity)))));}))))) );
  }

  @override
  Widget build(BuildContext context)=>PopScope(canPop:!_sharing,child:Scaffold(resizeToAvoidBottomInset:false,backgroundColor:Colors.black,body:Stack(children:[
    Positioned.fill(child:RepaintBoundary(key:_canvasKey,child:Stack(fit:StackFit.expand,children:[
      if(_layoutCount>0) _background() else GestureDetector(behavior:HitTestBehavior.opaque,onTap:_finishMode,child:_background()),
      IgnorePointer(ignoring:!_drawing,child:CustomPaint(painter:_Painter(_strokes,_activeStroke))),
      ...List.generate(_items.length,_buildItem),
    ]))),
    if(_editingBackground)Positioned.fill(child:GestureDetector(behavior:HitTestBehavior.translucent,onTap:_finishMode,onScaleStart:(d){_bgStartScale=_bgScale;_bgStartRotation=_bgRotation;},onScaleUpdate:(d)=>setState((){_bgOffset+=d.focalPointDelta;_bgScale=(_bgStartScale*d.scale).clamp(.05,30.0);_bgRotation=_bgStartRotation+d.rotation;}))),
    if(_drawing)Positioned.fill(child:GestureDetector(behavior:HitTestBehavior.translucent,onTap:_finishMode,onPanStart:(d)=>setState(()=>_activeStroke=_Stroke(_drawColor,5.5,[d.localPosition])),onPanUpdate:(d)=>setState(()=>_activeStroke?.points.add(d.localPosition)),onPanEnd:(_){final x=_activeStroke;setState((){if(x!=null&&x.points.length>1)_strokes.add(x);_activeStroke=null;});})),
    if(!_editingText)_chrome(),if(_editingText)_textComposer(),if(_moving)_trash()
  ]))));

  Widget _chrome()=>Positioned.fill(child:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(12,10,12,14),child:Stack(children:[
    Align(alignment:Alignment.topLeft,child:_Round(icon:Icons.close_rounded,onTap:_sharing?null:()=>Navigator.pop(context,false))),
    if(!_drawing&&!_editingBackground)Align(alignment:Alignment.topRight,child:SingleChildScrollView(child:Column(children:[
      _Tool(Icons.auto_awesome_mosaic_outlined,'Şablon',_openContextTemplates),const SizedBox(height:7),_Tool(Icons.text_fields_rounded,'Yazı',_openText),const SizedBox(height:7),_Tool(Icons.emoji_emotions_outlined,'Emoji',_openEmojiPicker),const SizedBox(height:7),_Tool(Icons.alternate_email_rounded,'Bahset',_openMentionPicker),const SizedBox(height:7),_Tool(Icons.grid_view_rounded,'Yerleşim',_chooseLayout),const SizedBox(height:7),_Tool(Icons.add_photo_alternate_outlined,'Fotoğraf',_addPhotos),const SizedBox(height:7),_Tool(Icons.draw_outlined,'Çiz',_toggleDraw),const SizedBox(height:7),_Tool(Icons.crop_free_rounded,'Kadraj',_toggleBackground,disabled:_layoutCount>0)
    ]))),
    if(_drawing)Align(alignment:Alignment.topRight,child:Container(width:150,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(18)),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[const Expanded(child:Text('Çizim',style:TextStyle(fontWeight:FontWeight.w900))),IconButton(onPressed:_finishMode,icon:const Icon(Icons.check))]),Wrap(spacing:5,children:_colors.map((c)=>GestureDetector(onTap:()=>setState(()=>_drawColor=c),child:CircleAvatar(radius:12,backgroundColor:c))).toList())]))),
    if(_editingBackground)Align(alignment:Alignment.topRight,child:Container(width:155,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(18)),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[const Expanded(child:Text('Kadraj',style:TextStyle(fontWeight:FontWeight.w900))),IconButton(onPressed:_finishMode,icon:const Icon(Icons.check))]),const Text('Sürükle ve iki parmakla ölçekle',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.white70))]))),
    if(_selected!=null&&!_moving&&!_drawing&&!_editingBackground)Align(alignment:Alignment.bottomCenter,child:Padding(padding:const EdgeInsets.only(bottom:70),child:IconButton.filled(onPressed:_removeSelected,icon:const Icon(Icons.delete_outline)))),
    if(!_drawing&&!_editingBackground)Align(alignment:Alignment.bottomCenter,child:SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:_sharing?null:_share,style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:Colors.black),icon:const Icon(Icons.arrow_upward_rounded),label:Text(_sharing?'Paylaşılıyor…':'Story’ni paylaş',style:const TextStyle(fontWeight:FontWeight.w900)))))
  ]))));

  Widget _textComposer()=>Positioned.fill(child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:_commitText,child:ColoredBox(color:Colors.black45,child:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[TextButton(onPressed:(){_textController.clear();_finishMode();},child:const Text('Vazgeç')),const Spacer(),FilledButton(onPressed:_commitText,child:const Text('Bitti'))])),
    const Spacer(),GestureDetector(onTap:(){},child:Padding(padding:const EdgeInsets.symmetric(horizontal:24),child:TextField(controller:_textController,focusNode:_textFocus,autofocus:true,maxLength:180,maxLines:5,textAlign:TextAlign.center,style:TextStyle(fontFamily:_font,color:_textColor,fontSize:34,fontWeight:FontWeight.w900),decoration:const InputDecoration(border:InputBorder.none,counterText:'',hintText:'Bir şey yaz…')))),const Spacer(),
    SizedBox(height:40,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14),itemCount:_fonts.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i)=>ChoiceChip(label:Text(['Modern','Klasik','Daktilo','Yuvarlak','İnce'][i]),selected:_font==_fonts[i],onSelected:(_)=>setState(()=>_font=_fonts[i])))),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.center,children:_colors.map((c)=>GestureDetector(onTap:()=>setState(()=>_textColor=c),child:Container(width:28,height:28,margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:_textColor==c?Colors.white:Colors.white38,width:2))))).toList()),const SizedBox(height:18)
  ])))));

  Widget _buildItem(int i){final x=_items[i];return Positioned(left:x.position.dx,top:x.position.dy,child:FractionalTranslation(translation:const Offset(-.5,-.5),child:GestureDetector(behavior:HitTestBehavior.translucent,onTap:()=>setState(()=>_selected=i),onScaleStart:(d){x.startScale=x.scale;x.startRotation=x.rotation;setState((){_selected=i;_moving=true;});},onScaleUpdate:(d)=>setState((){x.position+=d.focalPointDelta;x.scale=(x.startScale*d.scale).clamp(.05,30.0);x.rotation=x.startRotation+d.rotation;_overTrash=d.focalPoint.dy>MediaQuery.sizeOf(context).height-125;}),onScaleEnd:(_){if(_overTrash){_removeSelected();}else{setState((){_moving=false;_overTrash=false;});}},child:Transform.rotate(angle:x.rotation,child:Transform.scale(scale:x.scale,child:_itemBody(x,i==_selected))))));}

  Widget _itemBody(_OverlayItem x,bool selected){
    if(x.photo!=null)return Container(width:168,height:216,decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:selected&&!_moving?Border.all(color:Colors.white,width:2):null),clipBehavior:Clip.antiAlias,child:Image.file(x.photo!,fit:BoxFit.cover));
    if(x.emoji)return Text(x.text!,style:const TextStyle(fontSize:62));
    if(x.targetUserId!=null)return Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Text(x.text!,style:const TextStyle(color:Colors.black,fontSize:20,fontWeight:FontWeight.w900)));
    if(x.context)return Container(constraints:const BoxConstraints(maxWidth:300),padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(18)),child:Text(x.text!,textAlign:TextAlign.center,style:TextStyle(fontSize:x.compact?14:17,fontWeight:FontWeight.w900)));
    return Text(x.text!,textAlign:TextAlign.center,style:TextStyle(fontFamily:x.font,color:x.color,fontSize:34,fontWeight:FontWeight.w900,shadows:const[Shadow(color:Colors.black54,blurRadius:5)]));
  }

  Widget _trash()=>Positioned(left:0,right:0,bottom:20,child:SafeArea(top:false,child:Center(child:CircleAvatar(radius:_overTrash?34:28,backgroundColor:_overTrash?Colors.redAccent:Colors.black87,child:const Icon(Icons.delete_outline)))));
}

class _MentionSheet extends StatefulWidget{const _MentionSheet();@override State<_MentionSheet> createState()=>_MentionSheetState();}
class _MentionSheetState extends State<_MentionSheet>{String q='';@override Widget build(BuildContext context){final me=FirebaseAuth.instance.currentUser?.uid;return SizedBox(height:MediaQuery.sizeOf(context).height*.72,child:Column(children:[const Padding(padding:EdgeInsets.all(14),child:Text('Bahset',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:TextField(autofocus:true,onChanged:(v)=>setState(()=>q=v.toLowerCase()),decoration:const InputDecoration(hintText:'Kullanıcı ara',prefixIcon:Icon(Icons.search)))),Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').limit(120).snapshots(),builder:(_,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final docs=s.data!.docs.where((d){if(d.id==me)return false;final x=d.data();final n=(x['displayName']??x['username']??'').toString().toLowerCase();return q.isEmpty||n.contains(q);}).toList();return ListView.builder(itemCount:docs.length,itemBuilder:(_,i){final d=docs[i],x=d.data();final name=(x['displayName']??x['username']??'Kullanıcı').toString(),user=(x['username']??'').toString();return ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(name),subtitle:user.isEmpty?null:Text('@$user'),onTap:()=>Navigator.pop(context,_Mention(d.id,user.isEmpty?name.replaceAll(' ',''):user.replaceFirst('@',''))));});}))]));}}
class _Mention{final String uid,label;const _Mention(this.uid,this.label);}

class _OverlayItem{String? text;File? photo;String? targetUserId,font;Color color;bool emoji,context,compact;Offset position;double scale=1,rotation=0,startScale=1,startRotation=0;_OverlayItem({this.text,this.photo,this.targetUserId,this.font,this.color=Colors.white,this.emoji=false,this.context=false,this.compact=false,required this.position});factory _OverlayItem.text(String t,Offset p,String f,Color c)=>_OverlayItem(text:t,position:p,font:f,color:c);factory _OverlayItem.emoji(String t,Offset p)=>_OverlayItem(text:t,position:p,emoji:true);factory _OverlayItem.photo(File f,Offset p)=>_OverlayItem(photo:f,position:p);factory _OverlayItem.mention(String t,String id,Offset p)=>_OverlayItem(text:t,targetUserId:id,position:p);factory _OverlayItem.context(String t,Offset p,{bool compact=false})=>_OverlayItem(text:t,position:p,context:true,compact:compact);}
class _Stroke{final Color color;final double width;final List<Offset> points;_Stroke(this.color,this.width,this.points);}
class _Painter extends CustomPainter{final List<_Stroke> strokes;final _Stroke? active;const _Painter(this.strokes,this.active);@override void paint(Canvas c,Size s){for(final x in [...strokes,if(active!=null)active!]){if(x.points.length<2)continue;final p=Paint()..color=x.color..strokeWidth=x.width..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;final path=Path()..moveTo(x.points.first.dx,x.points.first.dy);for(final pt in x.points.skip(1)){path.lineTo(pt.dx,pt.dy);}c.drawPath(path,p);}}@override bool shouldRepaint(covariant CustomPainter oldDelegate)=>true;}
class _Tool extends StatelessWidget{final IconData icon;final String label;final VoidCallback tap;final bool disabled;const _Tool(this.icon,this.label,this.tap,{this.disabled=false});@override Widget build(BuildContext context)=>Material(color:const Color(0xB3121418),borderRadius:BorderRadius.circular(18),child:InkWell(onTap:disabled?null:tap,borderRadius:BorderRadius.circular(18),child:SizedBox(width:58,height:50,child:Opacity(opacity:disabled?.35:1,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:21),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))])))));}
class _Round extends StatelessWidget{final IconData icon;final VoidCallback? onTap;const _Round({required this.icon,required this.onTap});@override Widget build(BuildContext context)=>Material(color:Colors.black54,shape:const CircleBorder(),child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:SizedBox(width:44,height:44,child:Icon(icon))));}
