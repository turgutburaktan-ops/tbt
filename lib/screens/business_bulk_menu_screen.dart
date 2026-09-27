import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tbt_dialog.dart';

int? menuPriceMinor(String input) {
  final value=input.trim().replaceAll(',', '.');
  if(!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value))return null;
  final parts=value.split('.'),whole=int.tryParse(parts.first);
  if(whole==null||whole>1000000)return null;
  final minor=whole*100+(parts.length==2?int.parse(parts[1].padRight(2,'0')):0);
  return minor<=100000000?minor:null;
}
class _Product {
  final name=TextEditingController(),price=TextEditingController(),description=TextEditingController();
  File? image; String? itemId; bool imageDone=false,skipped=false;
  bool get filled=>name.text.trim().isNotEmpty||price.text.trim().isNotEmpty||description.text.trim().isNotEmpty||image!=null;
  void dispose(){name.dispose();price.dispose();description.dispose();}
}
class _Section {
  final name=TextEditingController();final rows=<_Product>[_Product()];
  void dispose(){name.dispose();for(final row in rows){row.dispose();}}
}
class _Batch {
  _Batch(this.rows,this.values):requestId=FirebaseFirestore.instance.collection('business_menu_requests').doc().id;
  final List<_Product> rows;final List<Map<String,dynamic>> values;final String requestId;bool saved=false;
}
class BusinessBulkMenuScreen extends StatefulWidget {
  const BusinessBulkMenuScreen({super.key,required this.category,required this.venueId});
  final String category,venueId;
  @override
  State<BusinessBulkMenuScreen> createState()=>_BusinessBulkMenuScreenState();
}
class _BusinessBulkMenuScreenState extends State<BusinessBulkMenuScreen> {
  final _sections=<_Section>[_Section()];List<_Batch>? _batches;
  bool _busy=false,_done=false,_allowPop=false;String? _error;String _progress='';
  bool get _locked=>_batches!=null;
  @override
  void dispose(){for(final section in _sections){section.dispose();}super.dispose();}
  Future<void> _photo(_Product row)async{
    final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:1600,requestFullMetadata:false);
    if(file!=null&&mounted)setState(()=>row.image=File(file.path));
  }
  Future<void> _leave()async{
    if(_busy)return;
    if(!_done&&_sections.any((s)=>s.rows.any((r)=>r.filled))){
      final ok=await showTbtDialog<bool>(context:context,builder:(c)=>TbtDialog(
        title:const Text('Menüden çıkılsın mı?'),
        content:Text(_locked?'Kaydedilen ürünler menüde kalır. Tamamlanmayan fotoğrafları yüklemek için bu ekranda tekrar deneyebilirsin.':'Kaydedilmemiş ürünler silinecek.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Devam et')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Çık'))],
      ));if(ok!=true||!mounted)return;
    }
    setState(()=>_allowPop=true);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)Navigator.pop(context,_done);});
  }
  Future<void> _save()async{
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try{
      if(_batches==null){
        final rows=<_Product>[],values=<Map<String,dynamic>>[];
        for(var si=0;si<_sections.length;si++){
          final section=_sections[si];
          for(var ri=0;ri<section.rows.length;ri++){
            final row=section.rows[ri];if(!row.filled)continue;
            final price=menuPriceMinor(row.price.text),prefix='${si+1}. bölüm, ${ri+1}. ürün';
            if(section.name.text.trim().isEmpty||section.name.text.trim().length>80)throw Exception('$prefix: bölüm adını yaz.');
            if(row.name.text.trim().isEmpty||row.name.text.trim().length>120)throw Exception('$prefix: ürün adını yaz.');
            if(price==null)throw Exception('$prefix: geçerli fiyat yaz (ör. 125,50).');
            if(row.description.text.trim().length>500)throw Exception('$prefix: açıklama en fazla 500 karakter olabilir.');
            rows.add(row);values.add({'section':section.name.text.trim(),'name':row.name.text.trim(),'priceMinor':price,'description':row.description.text.trim(),'available':true});
          }
        }
        if(rows.isEmpty)throw Exception('En az bir ürün ekle.');
        _batches=[];
        for(var i=0;i<rows.length;i+=100){final end=(i+100).clamp(0,rows.length);_batches!.add(_Batch(rows.sublist(i,end),values.sublist(i,end)));}
      }
      final key=BusinessService.instance.venueKey(widget.category,widget.venueId);
      for(final batch in _batches!){
        if(batch.saved)continue;
        setState(()=>_progress='Ürünler kaydediliyor…');
        final result=await BusinessService.instance.authenticatedCall('addBusinessMenuItemsBulk',{'venueKey':key,'requestId':batch.requestId,'items':batch.values});
        final skipped=(result['skipped'] as List? ?? []).map((s)=>(s as Map)['row'] as int).toSet();
        final ids=List<String>.from(result['itemIds'] as List);var index=0;
        for(var i=0;i<batch.rows.length;i++){final row=batch.rows[i];row.skipped=skipped.contains(i+1);if(!row.skipped)row.itemId=ids[index++];}
        batch.saved=true;
      }
      for(final batch in _batches!){for(final row in batch.rows){
        if(row.skipped||row.image==null||row.imageDone)continue;
        setState(()=>_progress='${row.name.text}: fotoğraf yükleniyor…');
        final media=await BusinessService.instance.uploadMenuImage(category:widget.category,venueId:widget.venueId,itemId:row.itemId!,image:row.image!);
        await BusinessService.instance.updateContentItem(category:widget.category,venueId:widget.venueId,type:'menu',itemId:row.itemId!,changes:media);
        row.imageDone=true;
      }}
      final rows=_batches!.expand((b)=>b.rows).toList(),skipped=rows.where((r)=>r.skipped).length;
      if(mounted)setState((){_done=true;_progress='${rows.length-skipped} ürün kaydedildi.${skipped>0?' $skipped ürün menüde zaten bulunduğu için tekrar eklenmedi.':''}';});
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PopScope(
    canPop:_allowPop,onPopInvokedWithResult:(didPop,result){if(!didPop)_leave();},
    child:Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Toplu menü oluştur')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Menü bölümlerini oluştur, altlarına ürünlerini ekle. Fiyatlar TL olarak kaydedilir.'),
        const SizedBox(height:16),
        for(final section in _sections) Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextField(controller:section.name,enabled:!_locked&&!_busy,decoration:const InputDecoration(labelText:'Menü bölümü',hintText:'Örn. İçecekler')),
          for(final row in section.rows) Padding(padding:const EdgeInsets.only(top:16),child:Column(children:[
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:TextField(controller:row.name,enabled:!_locked&&!_busy,decoration:const InputDecoration(labelText:'Ürün adı'))),
              const SizedBox(width:8),SizedBox(width:90,child:TextField(controller:row.price,enabled:!_locked&&!_busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Fiyat ₺'))),
              IconButton(tooltip:'Ürün fotoğrafı',onPressed:_locked||_busy?null:()=>_photo(row),icon:row.image==null?const Icon(Icons.add_photo_alternate_outlined):ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(row.image!,width:40,height:40,fit:BoxFit.cover))),
            ]),
            TextField(controller:row.description,enabled:!_locked&&!_busy,maxLines:null,decoration:const InputDecoration(labelText:'Açıklama (isteğe bağlı)')),
            if(!_locked) Align(alignment:Alignment.centerRight,child:TextButton(onPressed:_busy?null:()=>setState((){section.rows.remove(row);row.dispose();}),child:const Text('Ürünü kaldır'))),
          ])),
          if(!_locked) TextButton.icon(onPressed:_busy?null:()=>setState(()=>section.rows.add(_Product())),icon:const Icon(Icons.add),label:const Text('Ürün ekle')),
        ]))),
        if(!_locked) OutlinedButton.icon(onPressed:_busy?null:()=>setState(()=>_sections.add(_Section())),icon:const Icon(Icons.add),label:const Text('Yeni menü bölümü')),
        if(_progress.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_progress)),
        if(_error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:const TextStyle(color:Colors.redAccent))),
        FilledButton(onPressed:_busy?null:_done?_leave:_save,child:Text(_busy?'Kaydediliyor…':_done?'Menüye dön':_locked?'Kaldığı yerden tekrar dene':'Tümünü kaydet')),
        const SizedBox(height:24),
      ]),
    ),
  );
}
