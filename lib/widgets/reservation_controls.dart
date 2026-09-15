import 'tbt_dialog.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

String preparationLabel(Map<String, dynamic> d) =>
    const {
      'awaiting_confirmation': 'Müşteri hazırlık onayı bekleniyor',
      'confirmed': 'Müşteri hazırlığa onay verdi',
      'preparing': 'Hazırlanıyor',
      'ready': 'Sipariş hazır',
      'completed': 'Tamamlandı',
      'no_show': 'Gelmedi bildirildi',
      'cancelled': 'İptal edildi',
    }[d['preparationStatus']] ??
    'Müşteri hazırlık onayı bekleniyor';

class ReservationControls extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool owner;
  final Future<void> Function() refresh;
  const ReservationControls({
    super.key,
    required this.data,
    required this.refresh,
    this.owner = false,
  });
  @override
  State<ReservationControls> createState() => _ReservationControlsState();
}

class _ReservationControlsState extends State<ReservationControls> {
  bool _busy = false;
  Future<void> _action(String action) async {
    if (_busy) return;
    final d = widget.data;
    final extra = <String, dynamic>{};
    if (action == 'reschedule') {
      final date = await showDatePicker(
        context: context,
        builder: (context, child) =>
            Theme(data: tbtDialogTheme(Theme.of(context)), child: child!),
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 180)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        builder: (context, child) =>
            Theme(data: tbtDialogTheme(Theme.of(context)), child: child!),
        initialTime: TimeOfDay.now(),
      );
      if (time == null || !mounted) return;
      extra['atMs'] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).millisecondsSinceEpoch;
    } else if (action == 'dispute') {
      final controller = TextEditingController();
      final reason = await showTbtDialog<String>(
        context: context,
        builder: (ctx) => TbtDialog(
          title: const Text('İtiraz nedeni'),
          content: TextField(
            controller: controller,
            maxLength: 700,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length >= 5)
                  Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text('Gönder'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
      extra['reason'] = reason;
    } else if (['cancel', 'no_show', 'start', 'complete'].contains(action)) {
      final message = {
        'cancel': 'Rezervasyonu iptal etmek istiyor musun? Hazırlık başladıysa bu iptal geçmişine işlenir.',
        'no_show':
            'Müşteri gelmedi mi? Müşteriye bildirim ve itiraz hakkı verilecek.',
        'start': 'Müşteri onay verdi. Hazırlığa başlıyor musun?',
        'complete': 'Sipariş teslim edildi ve tamamlandı mı?',
      }[action]!;
      final yes = await showTbtDialog<bool>(
        context: context,
        builder: (ctx) => TbtDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('reservationPreparationAction')
          .call({
            'venueKey': d['venueKey'],
            'reservationId': d['id'],
            'expectedAtMs': d['atMs'],
            'action': action,
            ...extra,
          });
      await widget.refresh();
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem tamamlanamadı. Yeniden dene.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data,
        prep = (d['preparationStatus'] ?? 'awaiting_confirmation').toString();
    final at = (d['atMs'] as num? ?? 0).toInt(),
        now = DateTime.now().millisecondsSinceEpoch;
    final started = (d['preparationStartedAtMs'] as num? ?? 0) > 0,
        order = (d['orderItems'] as List? ?? []).isNotEmpty;
    final actions = <String, String>{};
    if (!widget.owner) {
      if (d['status'] == 'accepted' &&
          order &&
          prep == 'awaiting_confirmation' &&
          now >= at - 900000 &&
          now < at + 1800000)
        actions['confirm'] = 'Hazırlığa başla';
      if (['pending', 'accepted'].contains(d['status']) &&
          !['completed', 'no_show'].contains(prep)) {
        if (!started) actions['reschedule'] = 'Saati değiştir';
        actions['cancel'] = started ? 'Hazırlık sonrası iptal et' : 'İptal et';
      }
      if (['reported', 'cancelled'].contains(d['incidentStatus']))
        actions['dispute'] = 'İtiraz et';
    } else if (d['status'] == 'accepted' && order) {
      if (prep == 'confirmed' && now < at + 1800000)
        actions['start'] = 'Hazırlamaya başla';
      if (prep == 'preparing') actions['ready'] = 'Sipariş hazır';
      if (['preparing', 'ready'].contains(prep)) {
        actions['complete'] = 'Teslim edildi / tamamlandı';
        if (now >= at + 1800000 && now <= at + 604800000)
          actions['no_show'] = 'Müşteri gelmedi';
      }
    }
    final h = d['customerHistory'] is Map ? d['customerHistory'] as Map : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.owner &&
            h != null &&
            ((h['cancelled'] as num? ?? 0) > 0 ||
                (h['noShows'] as num? ?? 0) > 0))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Son 90 gündeki ${h['prepared']} hazırlığı başlayan siparişte: ${h['cancelled']} hazırlık sonrası iptal · ${h['noShows']} kesinleşmiş gelmeme kaydı.',
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (order) Text(preparationLabel(d)),
        if (d['incidentStatus'] == 'reported')
          const Text(
            'Gelmedi bildirimi ilk 72 saat kesinleşmiş sayıya eklenmez. İtiraz edebilirsin.',
          ),
        if (d['incidentStatus'] == 'disputed')
          const Text('İtiraz inceleniyor; kesinleşmiş sayıya dahil değil.'),
        if ((d['incidentResolution'] ?? '').toString().isNotEmpty)
          Text('İtiraz sonucu: ${d['incidentResolution']}'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: actions.entries
              .map(
                (e) => OutlinedButton(
                  onPressed: _busy ? null : () => _action(e.key),
                  child: Text(e.value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
