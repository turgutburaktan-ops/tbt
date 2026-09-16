import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/route_chat_bubble.dart';
import '../lib/widgets/profile_reward_surface.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test('action and message text retain readable contrast', () {
    final theme = AppTheme.dark;
    expect(contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textPrimary, AppColors.messageOutgoing), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textMuted, AppColors.surface), greaterThanOrEqualTo(4.5));
  });
  testWidgets('palette controls render and disabled actions remain disabled', (tester) async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')..addFont(File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf').readAsBytes().then(ByteData.sublistView));
        await font.load();
        final icon = FontLoader('MaterialIcons')..addFont(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView));
        await icon.load();
      });
    }
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark.copyWith(textTheme: AppTheme.dark.textTheme.apply(fontFamily:'Roboto')),
      home: RepaintBoundary(key: boundary, child: Scaffold(
        appBar: AppBar(title: const Text('TBT')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ProfileRewardSurface(profile: const {'selectedProfileTheme':'aurora'}, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Turgut Burak TAN', style: TextStyle(fontSize:22,fontWeight:FontWeight.w700)),
            const Text('@t.buraktan', style:TextStyle(color:AppColors.textMuted)),
            const SizedBox(height:12),
            OutlinedButton(onPressed:(){},child:const Text('Profili Düzenle')),
          ]))),
          const SizedBox(height:16),
          const Text('Etkinlikler',style:TextStyle(fontSize:22,fontWeight:FontWeight.w700)),
          const SizedBox(height:12),
          Card(child: Padding(padding: const EdgeInsets.all(16),child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Yürüyüşe çıkalım',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
            const Text('Bugün 20:30',style:TextStyle(color:AppColors.primary)),
            const Text('Elazığ · 3 katılımcı',style:TextStyle(color:AppColors.textMuted)),
            const SizedBox(height:12),
            FilledButton(onPressed:()=>taps++,child:const Text('Ben de geliyorum')),
            FilledButton(style:FilledButton.styleFrom(backgroundColor:AppColors.surfaceStrong,foregroundColor:AppColors.textPrimary),onPressed:(){},child:const Text('Detayları Gör')),
          ]))),
          const SizedBox(height:12),
          const TextField(decoration:InputDecoration(hintText:'Mekân veya yer ara',prefixIcon:Icon(Icons.search))),
          Wrap(spacing:8,children:[ChoiceChip(label:const Text('Bugün'),selected:true,onSelected:(_){}),ChoiceChip(label:const Text('Bu hafta'),selected:false,onSelected:(_) {})]),
          RouteChatBubble(mine:true,name:'Sen',text:'Akşam yürüyüşte görüşelim.',time:'20:15',onReply:(){}),
          const FilledButton(onPressed:null,child:Text('Dolu')),
        ]),
      ))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ben de geliyorum'));
    await tester.tap(find.text('Dolu'));
    expect(taps, 1);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio:2);
      final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
      await Directory('build/palette-review').create(recursive:true);
      await File('build/palette-review/palette.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
