import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;
import 'package:sensors_plus/sensors_plus.dart';

import '../services/ai_service.dart';
import 'ai_edit_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _ModeProfile {
  final int iso;
  final int shutterDenominator;
  final double ev;
  final double zoom;
  final String hint;
  const _ModeProfile(this.iso, this.shutterDenominator, this.ev, this.zoom, this.hint);
}

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();
  List<iris.CameraLensDescriptor> _lenses = [];
  int _lensIndex = 0;
  bool _initializing = true;
  bool _takingPhoto = false;
  bool _aiBusy = false;
  bool _aiEnabled = false;
  bool _showGrid = true;
  bool _locked = false;
  Offset? _focusPoint;
  String _mode = 'Normal';
  String _tip = 'Hazır';
  int _iso = 100;
  int _shutter = 125;
  double _ev = 0;
  double _zoom = 1;
  double _movement = 0;
  iris.PhotoFlashMode _flash = iris.PhotoFlashMode.auto;
  StreamSubscription<AccelerometerEvent>? _motionSub;

  static const modes = ['Normal', 'Portre', 'Manzara', 'Spor', 'Gece', 'Makro'];

  _ModeProfile get _profile {
    switch (_mode) {
      case 'Portre': return const _ModeProfile(100, 160, 0.0, 1.2, 'Yüzü kadraja al • gözlere netle');
      case 'Manzara': return const _ModeProfile(100, 160, -0.15, 1.0, 'Ufku düzle • parlak gökyüzünü koru');
      case 'Spor': return const _ModeProfile(400, 800, 0.0, 1.0, 'Hareketi takip et • hızlı çekim');
      case 'Gece': return const _ModeProfile(640, 30, 0.10, 1.0, 'Telefonu sabit tut • çoklu ışık toplama');
      case 'Makro': return const _ModeProfile(125, 200, -0.05, 1.0, 'Nesneye yaklaş • dokunarak netle');
      default: return const _ModeProfile(100, 125, 0.0, 1.0, 'Otomatik AF/AE');
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
    _motionSub = accelerometerEventStream().listen((e) {
      final m = (sqrt(e.x * e.x + e.y * e.y + e.z * e.z) - 9.81).abs();
      _movement = m;
    });
  }

  Future<void> _init() async {
    try {
      _lenses = await _camera.listAvailableLenses();
      if (_lenses.isNotEmpty) {
        await _camera.switchLens(_lenses.first.category);
        await _camera.initialize();
        await _applyMode();
      }
    } catch (e) { debugPrint('camera init: $e'); }
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _applyMode() async {
    final p = _profile;
    _iso = p.iso; _shutter = p.shutterDenominator; _ev = p.ev; _zoom = p.zoom;
    // Safety: never force dangerous manual exposure into the live preview.
    try { await _camera.setExposureMode(iris.ExposureMode.auto); } catch (_) {}
    try { await _camera.setFocusMode(_locked ? iris.FocusMode.locked : iris.FocusMode.auto); } catch (_) {}
    double minEv = -2, maxEv = 2;
    try { minEv = await _camera.getMinExposureOffset(); maxEv = await _camera.getMaxExposureOffset(); } catch (_) {}
    final safeEv = p.ev.clamp(max(-1.0, minEv), min(1.0, maxEv)).toDouble();
    try { await _camera.setExposureOffset(safeEv); } catch (_) {}
    try { await _camera.setZoom(p.zoom); } catch (_) {}
    if (_focusPoint != null) {
      try { await _camera.setFocus(point: _focusPoint!); await _camera.setExposurePoint(_focusPoint!); } catch (_) {}
    }
    if (mounted) setState(() { _ev = safeEv; _tip = p.hint; });
  }

  Future<void> _tapFocus(TapDownDetails d, BoxConstraints c) async {
    if (_locked) return;
    final p = Offset((d.localPosition.dx / c.maxWidth).clamp(0,1), (d.localPosition.dy / c.maxHeight).clamp(0,1));
    _focusPoint = p;
    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: p);
      await _camera.setExposurePoint(p);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _longPressLock(LongPressStartDetails d, BoxConstraints c) async {
    final p = Offset((d.localPosition.dx / c.maxWidth).clamp(0,1), (d.localPosition.dy / c.maxHeight).clamp(0,1));
    _focusPoint = p; _locked = true;
    try { await _camera.setFocus(point: p); await _camera.setExposurePoint(p); await _camera.setFocusMode(iris.FocusMode.locked); } catch (_) {}
    if (mounted) setState(() => _tip = 'AF/AE KİLİTLİ • açmak için uzun bas');
  }

  Future<void> _unlock() async {
    _locked = false; _focusPoint = null;
    try { await _camera.setFocusMode(iris.FocusMode.auto); } catch (_) {}
    await _applyMode();
  }

  Future<void> _selectMode(String m) async {
    if (_takingPhoto) return;
    setState(() { _mode = m; _tip = '$_mode hazırlanıyor…'; });
    await _applyMode();
    if (_aiEnabled) unawaited(_analyze());
  }

  Future<File> _capture() async {
    // Normal/portrait/landscape/macro let the phone's AE choose exposure.
    // Sport/night use bounded capture hints only; this prevents blown white frames.
    iris.PhotoCaptureOptions options;
    if (_mode == 'Spor') {
      options = iris.PhotoCaptureOptions(flashMode: _flash, iso: _iso.toDouble(), exposureDuration: Duration(microseconds: max(1000, (1000000 / _shutter).round())));
    } else if (_mode == 'Gece' && _movement < 0.8) {
      Duration wanted = Duration(microseconds: (1000000 / _shutter).round());
      try { final mx = await _camera.getMaxExposureDuration(); if (wanted > mx) wanted = mx; } catch (_) {}
      options = iris.PhotoCaptureOptions(flashMode: iris.PhotoFlashMode.off, iso: _iso.toDouble(), exposureDuration: wanted);
    } else {
      options = iris.PhotoCaptureOptions(flashMode: _flash);
    }
    final bytes = await _camera.capturePhoto(options: options);
    if (bytes.isEmpty) throw Exception('empty capture');
    final f = File('${Directory.systemTemp.path}/tbt_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<void> _takePhoto() async {
    // AI analysis must never block the shutter.
    if (_takingPhoto || _initializing) return;
    setState(() => _takingPhoto = true);
    try {
      final f = await _capture();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AiEditScreen(originalImagePath: f.path)));
    } catch (e) {
      debugPrint('capture: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf çekilemedi.')));
    } finally { if (mounted) setState(() => _takingPhoto = false); }
  }

  Future<void> _analyze() async {
    if (!_aiEnabled || _aiBusy || _takingPhoto) return;
    setState(() { _aiBusy = true; _tip = 'Sahne analiz ediliyor…'; });
    File? f;
    try {
      final bytes = await _camera.capturePhoto(options: const iris.PhotoCaptureOptions(flashMode: iris.PhotoFlashMode.off));
      f = File('${Directory.systemTemp.path}/ai_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await f.writeAsBytes(bytes);
      final a = await AiService.analyzeLiveFrame(imagePath: f.path, mode: _mode);
      if (mounted) setState(() => _tip = a.mainTip.isEmpty ? _profile.hint : a.mainTip);
      // AI is advisory. It may make a small bounded EV correction, never ISO/shutter explosions.
      final t = '${a.mainTip} ${a.lightTip}'.toLowerCase();
      var target = _profile.ev;
      if (t.contains('çok parlak') || t.contains('aşırı poz')) target -= .25;
      if (t.contains('karanlık') || t.contains('az ışık')) target += .15;
      target = target.clamp(-0.7, 0.7).toDouble();
      try { await _camera.setExposureOffset(target); _ev = target; } catch (_) {}
    } catch (e) { if (mounted) setState(() => _tip = _profile.hint); }
    finally { if (f != null) { try { await f.delete(); } catch (_) {} } if (mounted) setState(() => _aiBusy = false); }
  }

  Future<void> _toggleLens() async {
    if (_lenses.length < 2 || _takingPhoto) return;
    _lensIndex = (_lensIndex + 1) % _lenses.length;
    try { await _camera.switchLens(_lenses[_lensIndex].category); await _applyMode(); } catch (_) {}
  }

  Future<void> _gallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 94);
    if (x != null && mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => AiEditScreen(originalImagePath: x.path)));
  }

  void _cycleFlash() => setState(() { _flash = _flash == iris.PhotoFlashMode.off ? iris.PhotoFlashMode.auto : _flash == iris.PhotoFlashMode.auto ? iris.PhotoFlashMode.on : iris.PhotoFlashMode.off; });

  @override
  void dispose() { _motionSub?.cancel(); _camera.disposeSession(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    if (_lenses.isEmpty) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.white))));
    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: Column(children: [
      _top(),
      Expanded(child: _preview()),
      _hud(),
      _modes(),
      _bottom(),
    ])));
  }

  Widget _top() => SizedBox(height: 62, child: Row(children: [
    _circle(Icons.close, () => Navigator.pop(context)),
    Expanded(child: GestureDetector(onTap: () { setState(() => _aiEnabled = !_aiEnabled); if (_aiEnabled) unawaited(_analyze()); else setState(() => _tip = _profile.hint); }, child: Container(height: 44, margin: const EdgeInsets.all(7), decoration: BoxDecoration(color: _aiEnabled ? const Color(0xffffc107) : const Color(0xff151a22), borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Text('✨ AI AUTO PRO', style: TextStyle(color: _aiEnabled ? Colors.black : Colors.white, fontWeight: FontWeight.w900))))),
    _circle(_flash == iris.PhotoFlashMode.off ? Icons.flash_off : _flash == iris.PhotoFlashMode.auto ? Icons.flash_auto : Icons.flash_on, _cycleFlash),
    _circle(_showGrid ? Icons.grid_on : Icons.grid_off, () => setState(() => _showGrid = !_showGrid)),
  ]));

  Widget _preview() => Padding(padding: const EdgeInsets.all(8), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(fit: StackFit.expand, children: [
    LayoutBuilder(builder: (_, c) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _tapFocus(d,c),
      onLongPressStart: (d) => _locked ? _unlock() : _longPressLock(d,c),
      child: const iris.IrisCameraPreview(enableTapToFocus: false, showFocusIndicator: false),
    )),
    if (_showGrid) const IgnorePointer(child: _Grid()),
    if (_focusPoint != null) LayoutBuilder(builder: (_,c) => Positioned(left: _focusPoint!.dx*c.maxWidth-24, top: _focusPoint!.dy*c.maxHeight-24, child: IgnorePointer(child: Container(width:48,height:48,decoration:BoxDecoration(border:Border.all(color:const Color(0xffffc107),width:2),borderRadius:BorderRadius.circular(12)),child:_locked?const Icon(Icons.lock,color:Color(0xffffc107),size:16):null)))),
    Positioned(top:12,left:18,right:18,child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),decoration:BoxDecoration(color:Colors.black.withOpacity(.68),borderRadius:BorderRadius.circular(18)),child:Text(_aiBusy?'Sahne analiz ediliyor…':_tip,maxLines:2,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))))),
  ])));

  Widget _hud() => Container(height:58, margin:const EdgeInsets.symmetric(horizontal:10), padding:const EdgeInsets.symmetric(horizontal:14), decoration:BoxDecoration(color:const Color(0xff11151c),borderRadius:BorderRadius.circular(14)), child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    _param('MOD',_mode), _param('ISO','$_iso'), _param('S','1/$_shutter'), _param('ODAK',_locked?'AF-L':'AF'), _param('EV','${_ev>=0?'+':''}${_ev.toStringAsFixed(1)}')
  ]));

  Widget _modes() => SizedBox(height:62,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),itemCount:modes.length,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(_,i){final m=modes[i],s=m==_mode;return GestureDetector(onTap:()=>_selectMode(m),child:Container(padding:const EdgeInsets.symmetric(horizontal:20),alignment:Alignment.center,decoration:BoxDecoration(color:s?const Color(0xffffc107):const Color(0xff151a22),borderRadius:BorderRadius.circular(24)),child:Text(m,style:TextStyle(color:s?Colors.black:Colors.white,fontWeight:FontWeight.w800))));}));

  Widget _bottom() => SizedBox(height:112,child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
    _circle(Icons.photo_library_outlined,_gallery,size:56),
    GestureDetector(onTap:_takePhoto,child:Container(width:84,height:84,padding:const EdgeInsets.all(6),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white,width:4)),child:Container(decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xffffc107)),child:_takingPhoto?const Padding(padding:EdgeInsets.all(20),child:CircularProgressIndicator(color:Colors.black)):null))),
    _circle(Icons.cameraswitch_outlined,_toggleLens,size:56),
  ]));

  Widget _circle(IconData i, VoidCallback? f,{double size=44}) => GestureDetector(onTap:f,child:Container(width:size,height:size,margin:const EdgeInsets.all(5),decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xff151a22),border:Border.all(color:Colors.white12)),child:Icon(i,color:Colors.white)));
  Widget _param(String a,String b)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(a,style:const TextStyle(color:Colors.white54,fontSize:8)),const SizedBox(height:2),Text(b,style:TextStyle(color:a=='EV'?const Color(0xffffc107):Colors.white,fontSize:10,fontWeight:FontWeight.w800))]);
}

class _Grid extends StatelessWidget { const _Grid(); @override Widget build(BuildContext context)=>CustomPaint(painter:_GridPainter(),child:const SizedBox.expand()); }
class _GridPainter extends CustomPainter {
  @override void paint(Canvas c,Size s){final p=Paint()..color=Colors.white.withOpacity(.25)..strokeWidth=1;for(final x in [s.width/3,s.width*2/3])c.drawLine(Offset(x,0),Offset(x,s.height),p);for(final y in [s.height/3,s.height*2/3])c.drawLine(Offset(0,y),Offset(s.width,y),p);}
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
