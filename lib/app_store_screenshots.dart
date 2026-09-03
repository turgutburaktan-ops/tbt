import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ScreenshotApp());
}

class _ScreenshotApp extends StatelessWidget {
  const _ScreenshotApp();

  @override
  Widget build(BuildContext context) {
    final screen = Platform.environment['APP_STORE_SCREEN'] ?? 'home';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _ScreenshotPage(screen: screen),
    );
  }
}

class _ScreenshotPage extends StatelessWidget {
  final String screen;
  const _ScreenshotPage({required this.screen});

  @override
  Widget build(BuildContext context) {
    final spec = switch (screen) {
      'places' => ('Türkiye\'yi keşfet', 'Doğrulanmış noktalar, kafeler, lezzetler ve oteller', const _Places()),
      'detail' => ('Doğru anda, doğru kare', 'En iyi saat, açı ve rota önerileri tek yerde', const _SpotDetail()),
      'plan' => ('Rotanı birlikte oluştur', 'Seç, sırala ve yolculuğunu kolayca planla', const _Plan()),
      'nearby' => ('Çevrende ne var?', 'Yakındaki mekanları ve etkinlikleri anında gör', const _Nearby()),
      'profile' => ('Anılarını tek yerde yaşat', 'Paylaşımların, planların ve mekanların seninle', const _Profile()),
      _ => ('Keşfet. Paylaş. Yola çık.', 'Türkiye\'nin gezi ve mekan topluluğuna katıl', const _Home()),
    };
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF11102A), AppColors.background, Color(0xFF041316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Brand(),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.accentGradientHorizontal.createShader(bounds),
                  child: Text(
                    spec.$1,
                    style: const TextStyle(fontSize: 34, height: 1.02, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2),
                  ),
                ),
                const SizedBox(height: 9),
                Text(spec.$2, style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFFC7CBD6), fontWeight: FontWeight.w600)),
                const SizedBox(height: 22),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: AppColors.borderStrong, width: 1.2), borderRadius: BorderRadius.circular(30)),
                      child: spec.$3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 34, height: 34, decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.explore_rounded, color: Colors.white, size: 21)),
    const SizedBox(width: 10),
    const Text('TBT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Text('TR', style: TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w900))),
  ]);
}

class _PhoneTop extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PhoneTop(this.title, {this.icon = Icons.notifications_none_rounded});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
    child: Row(children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const Spacer(), Icon(icon, color: Colors.white70), const SizedBox(width: 8), const CircleAvatar(radius: 15, backgroundColor: AppColors.surfaceElevated, child: Icon(Icons.person_rounded, size: 18))]),
  );
}

class _Nav extends StatelessWidget {
  final int selected;
  const _Nav(this.selected);
  @override
  Widget build(BuildContext context) {
    const items = [(Icons.home_rounded, 'Ana Sayfa'), (Icons.place_rounded, 'Mekanlar'), (Icons.explore_rounded, 'Planla'), (Icons.near_me_rounded, 'Çevrende'), (Icons.person_rounded, 'Profil')];
    return Container(
      height: 65,
      decoration: const BoxDecoration(color: AppColors.navigation, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: List.generate(items.length, (i) => Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(items[i].$1, size: 21, color: i == selected ? AppColors.cyan : Colors.white30), const SizedBox(height: 3), Text(items[i].$2, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: i == selected ? Colors.white : Colors.white38))]))),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) => Column(children: [
    const _PhoneTop('Günaydın, Burak'),
    SizedBox(height: 68, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: const [_Story('Sen', Icons.add), _Story('Elif', Icons.landscape), _Story('Mert', Icons.hiking), _Story('Zeynep', Icons.restaurant)])),
    const SizedBox(height: 8),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Text('Senin için', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), Spacer(), Text('Keşfet', style: TextStyle(color: AppColors.violetBright, fontWeight: FontWeight.w800))])),
    const SizedBox(height: 10),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      _ImageCard(asset: 'assets/spot_thumbnails/harput-kalesi.webp', title: 'Harput\'ta gün batımı', subtitle: 'Burak Tan · Elazığ', tag: 'Gezilecek Yer'),
      const SizedBox(height: 10),
      _ImageCard(asset: 'assets/spot_thumbnails/auto-elz-hazarbaba.webp', title: 'Hafta sonu rotası hazır', subtitle: 'Hazarbaba · 12 km', tag: 'Plan'),
    ])),
    const _Nav(0),
  ]);
}

class _Story extends StatelessWidget {
  final String label; final IconData icon;
  const _Story(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 12), child: Column(children: [Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient, border: Border.all(color: AppColors.cyan)), child: Icon(icon, size: 22)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70))]));
}

class _ImageCard extends StatelessWidget {
  final String asset, title, subtitle, tag;
  const _ImageCard({required this.asset, required this.title, required this.subtitle, required this.tag});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: SizedBox(height: 174, width: double.infinity, child: Image.asset(asset, fit: BoxFit.cover))),
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(9)), child: Text(tag, style: const TextStyle(fontSize: 9, color: AppColors.violetBright, fontWeight: FontWeight.w800))), const Spacer(), const Icon(Icons.favorite_border_rounded, size: 20), const SizedBox(width: 12), const Icon(Icons.send_outlined, size: 19)]), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted))]))
    ]),
  );
}

class _Places extends StatelessWidget {
  const _Places();
  @override
  Widget build(BuildContext context) => Column(children: [
    const _PhoneTop('Mekanlar', icon: Icons.tune_rounded),
    const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 10), child: _Search()),
    SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: const [_Chip('Tümü', true), _Chip('Gezilecek'), _Chip('Lezzet'), _Chip('Kafeler'), _Chip('Oteller')])),
    const SizedBox(height: 5),
    Expanded(child: ListView(padding: const EdgeInsets.all(12), children: const [
      _PlaceTile('assets/spot_thumbnails/harput-kalesi.webp', 'Harput Kalesi', 'Elazığ · Gezilecek Yer', '4.9'),
      _PlaceTile('assets/spot_thumbnails/elazig-alacali-camii.webp', 'Alacalı Camii', 'Elazığ · Tarih', '4.8'),
      _PlaceTile('assets/spot_thumbnails/auto-elz-hazarbaba.webp', 'Hazarbaba', 'Sivrice · Doğa', '4.7'),
    ])),
    const _Nav(1),
  ]);
}

class _Search extends StatelessWidget { const _Search(); @override Widget build(BuildContext context) => Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: const Row(children: [Icon(Icons.search_rounded, color: AppColors.textMuted, size: 19), SizedBox(width: 8), Text('Yer, kafe, lezzet veya otel ara', style: TextStyle(color: AppColors.textSubtle, fontSize: 11))])); }

class _Chip extends StatelessWidget { final String text; final bool active; const _Chip(this.text, [this.active=false]); @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(right: 7, bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: BoxDecoration(gradient: active ? AppColors.accentGradientHorizontal : null, color: active ? null : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? Colors.transparent : AppColors.border)), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))); }

class _PlaceTile extends StatelessWidget { final String asset, name, meta, rating; const _PlaceTile(this.asset,this.name,this.meta,this.rating); @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.asset(asset, width: 92, height: 82, fit: BoxFit.cover)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 5), Text(meta, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)), const SizedBox(height: 9), Row(children: [const Icon(Icons.star_rounded, color: AppColors.warning, size: 16), const SizedBox(width: 3), Text(rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), const Spacer(), const Icon(Icons.add_road_rounded, color: AppColors.cyan, size: 18)])]))])); }

class _SpotDetail extends StatelessWidget {
  const _SpotDetail();
  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(child: Stack(children: [
      Positioned.fill(child: Image.asset('assets/spot_thumbnails/harput-kalesi.webp', fit: BoxFit.cover)),
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xF005060A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
      Positioned(left: 15, right: 15, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Chip('Doğrulanmış Nokta', true),
        const SizedBox(height: 10),
        const Text('Harput Kalesi', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4), const Text('Elazığ · 4.9 ★', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 16),
        Row(children: const [Expanded(child: _Info(Icons.schedule_rounded, 'En iyi saat', '18:10–19:20')), SizedBox(width: 8), Expanded(child: _Info(Icons.camera_alt_outlined, 'Önerilen açı', 'Batı surları'))]),
        const SizedBox(height: 9),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.borderStrong)), child: const Row(children: [Icon(Icons.route_rounded, color: AppColors.cyan), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Rotana ekle', style: TextStyle(fontWeight: FontWeight.w900)), Text('Yol tarifi ve çekim önerileri hazır', style: TextStyle(color: AppColors.textMuted, fontSize: 10))])), Icon(Icons.chevron_right_rounded)])),
      ])),
    ])),
  ]);
}

class _Info extends StatelessWidget { final IconData icon; final String title, value; const _Info(this.icon,this.title,this.value); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xDD10131B), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.borderStrong)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppColors.violetBright, size: 20), const SizedBox(height: 8), Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))])); }

class _Plan extends StatelessWidget {
  const _Plan();
  @override
  Widget build(BuildContext context) => Column(children: [
    const _PhoneTop('Planla', icon: Icons.group_add_outlined),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: AppColors.subtleGradient, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderAccent)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.auto_awesome_rounded, color: AppColors.cyan), SizedBox(height: 9), Text('Akıllı rota oluştur', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), SizedBox(height: 4), Text('Süreni ve ilgi alanlarını seç, TBT rotanı hazırlasın.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)), SizedBox(height: 12), Row(children: [Expanded(child: _SmallButton('Başla', Icons.arrow_forward_rounded)), SizedBox(width: 8), Expanded(child: _SmallButton('Arkadaş çağır', Icons.people_outline_rounded))])]))),
    const Padding(padding: EdgeInsets.fromLTRB(14, 18, 14, 10), child: Row(children: [Text('Cumartesi rotası', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Spacer(), Text('3 durak · 4 sa.', style: TextStyle(color: AppColors.cyan, fontSize: 10))])),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: const [_RouteStep('1', 'Harput Kalesi', '17:30 · Gün batımı'), _RouteStep('2', 'Alacalı Camii', '18:50 · Tarih'), _RouteStep('3', 'Kürsübaşı Lezzetleri', '20:00 · Akşam yemeği')])),
    const _Nav(2),
  ]);
}

class _SmallButton extends StatelessWidget { final String text; final IconData icon; const _SmallButton(this.text,this.icon); @override Widget build(BuildContext context) => Container(height: 40, decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(width: 6), Icon(icon, size: 16)])); }
class _RouteStep extends StatelessWidget { final String n,title,meta; const _RouteStep(this.n,this.title,this.meta); @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 34,height:34,alignment:Alignment.center,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:AppColors.accentGradient),child:Text(n,style:const TextStyle(fontWeight:FontWeight.w900))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(meta,style:const TextStyle(color:AppColors.textMuted,fontSize:10))])),const Icon(Icons.drag_indicator_rounded,color:Colors.white30)])); }

class _Nearby extends StatelessWidget {
  const _Nearby();
  @override
  Widget build(BuildContext context) => Column(children: [
    const _PhoneTop('Çevrende', icon: Icons.layers_outlined),
    Expanded(child: Stack(children: [
      Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFF111B2B), Color(0xFF0C2020)])), child: CustomPaint(painter: _MapPainter(), child: const SizedBox.expand())),
      const Positioned(left: 27, top: 38, child: _MapPin(Icons.restaurant, 'Lezzet', AppColors.warning)),
      const Positioned(right: 36, top: 112, child: _MapPin(Icons.local_cafe, 'Kafe', AppColors.violetBright)),
      const Positioned(left: 98, top: 205, child: _MapPin(Icons.event, 'Etkinlik', AppColors.cyan)),
      Positioned(left: 25, right: 25, bottom: 26, child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xF2131722), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)), child: const Row(children: [CircleAvatar(backgroundColor: AppColors.cyanSoft, child: Icon(Icons.near_me_rounded, color: AppColors.cyan)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('12 mekan yakınında', style: TextStyle(fontWeight: FontWeight.w900)), Text('3 etkinlik bugün başlıyor', style: TextStyle(color: AppColors.textMuted, fontSize: 10))])), Icon(Icons.chevron_right_rounded)]))),
    ])),
    const _Nav(3),
  ]);
}

class _MapPainter extends CustomPainter { const _MapPainter(); @override void paint(Canvas c,Size s){final p=Paint()..color=const Color(0xFF26394A)..strokeWidth=2; for(double y=25;y<s.height;y+=58){c.drawLine(Offset(0,y),Offset(s.width,y+35),p);} for(double x=20;x<s.width;x+=76){c.drawLine(Offset(x,0),Offset(x-30,s.height),p);} } @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false; }
class _MapPin extends StatelessWidget { final IconData icon; final String text; final Color color; const _MapPin(this.icon,this.text,this.color); @override Widget build(BuildContext context)=>Column(children:[Container(width:42,height:42,decoration:BoxDecoration(color:color,shape:BoxShape.circle,boxShadow:[BoxShadow(color:color.withValues(alpha:.35),blurRadius:14)]),child:Icon(icon,color:Colors.black87,size:21)),Container(margin:const EdgeInsets.only(top:4),padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(8)),child:Text(text,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w900)))]); }

class _Profile extends StatelessWidget {
  const _Profile();
  @override
  Widget build(BuildContext context) => Column(children: [
    const _PhoneTop('Profil', icon: Icons.settings_outlined),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(children: [CircleAvatar(radius: 34, backgroundColor: AppColors.surfaceElevated, child: Icon(Icons.person_rounded, size: 38, color: AppColors.violetBright)), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Burak Tan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('@t.buraktan · Elazığ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)), SizedBox(height: 8), Row(children: [Text('128 Gönderi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)), SizedBox(width: 12), Text('2,4B Takipçi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))])]))])),
    const SizedBox(height: 16),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: const [Expanded(child: _ProfileAction(Icons.storefront_outlined, 'Mekanlarım')), SizedBox(width: 8), Expanded(child: _ProfileAction(Icons.bookmark_outline_rounded, 'Kaydedilenler')), SizedBox(width: 8), Expanded(child: _ProfileAction(Icons.route_outlined, 'Planlarım'))])),
    const Padding(padding: EdgeInsets.fromLTRB(14, 18, 14, 10), child: Row(children: [Text('Paylaşımlarım', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Spacer(), Icon(Icons.grid_view_rounded, color: AppColors.cyan, size: 19)])),
    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: GridView.count(crossAxisCount: 2, mainAxisSpacing: 7, crossAxisSpacing: 7, children: ['assets/spot_thumbnails/harput-kalesi.webp','assets/spot_thumbnails/auto-elz-hazarbaba.webp','assets/spot_thumbnails/elazig-alacali-camii.webp'].map((a)=>ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.asset(a,fit:BoxFit.cover))).toList()))),
    const _Nav(4),
  ]);
}

class _ProfileAction extends StatelessWidget { final IconData icon; final String text; const _ProfileAction(this.icon,this.text); @override Widget build(BuildContext context)=>Container(height:68,decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(15),border:Border.all(color:AppColors.border)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:AppColors.violetBright,size:22),const SizedBox(height:5),Text(text,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))])); }
