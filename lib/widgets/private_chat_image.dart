import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/private_chat_media.dart';

class PrivateChatImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const PrivateChatImage({super.key,required this.url,this.fit=BoxFit.cover});
  @override
  State<PrivateChatImage> createState()=>_PrivateChatImageState();
}
class _PrivateChatImageState extends State<PrivateChatImage> {
  Uint8List? _bytes;
  MemoryImage? _image;
  Object? _error;
  int _generation=0;
  StreamSubscription<dynamic>? _auth;
  @override
  void initState() {
    super.initState();
    _auth=FirebaseAuth.instance.authStateChanges().listen((_)=>_load());
  }
  @override
  void didUpdateWidget(covariant PrivateChatImage old) {
    super.didUpdateWidget(old);
    if (old.url!=widget.url) _load();
  }
  void _clear() {
    final image=_image; _image=null;
    if(image!=null) unawaited(image.evict());
    _bytes?.fillRange(0,_bytes!.length,0); _bytes=null;
  }
  Future<void> _load() async {
    final generation=++_generation;
    _clear(); _error=null;
    if(mounted) setState((){});
    try {
      final bytes=await PrivateChatMedia.read(widget.url);
      if(!mounted || generation!=_generation) {bytes.fillRange(0,bytes.length,0); return;}
      setState((){_bytes=bytes;_image=MemoryImage(bytes);});
    } catch(error) {
      if(mounted && generation==_generation) setState(()=>_error=error);
    }
  }
  @override
  void dispose() {++_generation;_auth?.cancel();_clear();super.dispose();}
  @override
  Widget build(BuildContext context) => _error!=null
    ? const Center(child:Icon(Icons.lock_outline,color:Colors.white54))
    : _image==null ? const Center(child:CircularProgressIndicator())
    : Image(image:_image!,fit:widget.fit,
        errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined));
}
