import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BusinessPublicActions extends StatelessWidget {
  final String venueKey;
  final bool reservationsEnabled;

  const BusinessPublicActions({
    super.key,
    required this.venueKey,
    this.reservationsEnabled = true,
  });

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> _follow(BuildContext context, bool follow) async {
    try {
      await _functions.httpsCallable('followBusiness').call({'venueKey': venueKey, 'follow': follow});
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')));
    }
  }

  Future<void> _reservation(BuildContext context) async {
    await _functions.httpsCallable('recordBusinessMetric').call({'venueKey': venueKey, 'metric': 'reservation_open'});
    if (!context.mounted) return;
    var at = DateTime.now().add(const Duration(hours: 2));
    var people = 2;
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rezervasyon talebi'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: people,
                decoration: const InputDecoration(labelText: 'Kişi sayısı'),
                items: List.generate(12, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v kişi'))).toList(),
                onChanged: (v) => setState(() => people = v ?? 2),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text('${at.day}.${at.month}.${at.year} • ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'),
                onTap: () async {
                  final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDate: at);
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(at));
                  if (time != null) setState(() => at = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                try {
                  await _functions.httpsCallable('requestBusinessReservation').call({
                    'venueKey': venueKey,
                    'partySize': people,
                    'atMs': at.millisecondsSinceEpoch,
                    'note': note.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rezervasyon talebin işletmeye gönderildi.')));
                } on FirebaseFunctionsException catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Talep gönderilemedi.')));
                }
              },
              child: const Text('Talep Gönder'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final followRef = FirebaseFirestore.instance.collection('business_venues').doc(venueKey).collection('followers').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followRef.snapshots(),
      builder: (context, snapshot) {
        final following = snapshot.data?.exists == true;
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _follow(context, !following),
              icon: Icon(following ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
              label: Text(following ? 'Takip Ediliyor' : 'Takip Et'),
            ),
          ),
          if (reservationsEnabled) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _reservation(context),
                icon: const Icon(Icons.event_seat_outlined),
                label: const Text('Rezervasyon'),
              ),
            ),
          ],
        ]);
      },
    );
  }
}
