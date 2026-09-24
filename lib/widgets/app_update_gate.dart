import 'package:flutter/material.dart';
import '../services/app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}
class _AppUpdateGateState extends State<AppUpdateGate> {
  late final AppUpdateService _service;
  @override
  void initState() { super.initState(); _service = AppUpdateService()..start(); }
  @override
  void dispose() { _service.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _service,
    builder: (context, _) => Stack(children: [
      ExcludeSemantics(excluding: _service.offer != null, child: AbsorbPointer(absorbing: _service.offer != null, child: widget.child)),
      if (_service.offer case final offer?) Positioned.fill(child: Material(
        color: Colors.black54,
        child: SafeArea(child: Center(child: SingleChildScrollView(child: AlertDialog(
          title: Text(offer.downloaded ? 'Güncelleme hazır' : offer.required ? 'Güncelleme gerekli' : 'TBT’nin yeni sürümü hazır'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer.downloaded ? 'Kurulum için uygulama yeniden başlatılacak.' : offer.required ? 'TBT’yi kullanmaya devam etmek için yeni sürümü yükle.' : 'Yeni özellikler ve düzeltmeler için uygulamanı güncelle.'),
            if (_service.busy) const Padding(padding: EdgeInsets.only(top:16), child: LinearProgressIndicator()),
            if (_service.error != null) Padding(padding: const EdgeInsets.only(top:12),child:Text(_service.error!)),
          ]),
          actions: [
            if (!offer.required) TextButton(onPressed:_service.busy ? null : _service.postpone,child:const Text('Daha sonra')),
            FilledButton(onPressed:_service.busy ? null : _service.update,child:Text(offer.downloaded ? 'Yeniden başlat ve yükle' : 'Güncelle')),
          ],
        )))),
      )),
    ]),
  );
}
