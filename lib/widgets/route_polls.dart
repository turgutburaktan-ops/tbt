import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';

class RoutePolls extends StatelessWidget {
  const RoutePolls({
    super.key,
    required this.planId,
    required this.ownerId,
    this.onlyPollId,
    this.showCreateButton = true,
  });
  final String planId, ownerId;
  final String? onlyPollId;
  final bool showCreateButton;
  CollectionReference<Map<String, dynamic>> get _polls => FirebaseFirestore
      .instance
      .collection('travel_plans')
      .doc(planId)
      .collection('polls');
  Future<void> _act(BuildContext c, Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> create(BuildContext context) async {
    final question = TextEditingController();
    final options = List.generate(4, (_) => TextEditingController());
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Oylama oluştur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLength: 180,
                decoration: const InputDecoration(
                  hintText: 'Ne karar veriyoruz?',
                ),
              ),
              for (var i = 0; i < 4; i++)
                TextField(
                  controller: options[i],
                  maxLength: 80,
                  decoration: InputDecoration(
                    hintText:
                        'Seçenek ${i + 1}${i > 1 ? ' (isteğe bağlı)' : ''}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final values = options
                  .map((t) => t.text.trim())
                  .where((t) => t.isNotEmpty)
                  .toSet();
              if (question.text.trim().isNotEmpty && values.length >= 2)
                Navigator.pop(c, true);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted)
      await _act(
        context,
        () => _polls.add({
          'authorId': FirebaseAuth.instance.currentUser!.uid,
          'question': question.text.trim(),
          'options': options
              .map((t) => t.text.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList(),
          'closed': false,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    question.dispose();
    for (final c in options) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showCreateButton)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => create(context),
            icon: const Icon(Icons.poll_outlined),
            label: const Text('Oylama oluştur'),
          ),
        ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            (onlyPollId == null
                    ? _polls.orderBy('createdAt', descending: true).limit(20)
                    : _polls.where(FieldPath.documentId, isEqualTo: onlyPollId))
                .snapshots(),
        builder: (_, s) {
          if (s.hasError) return Text(userFacingError(s.error!));
          return Column(
            children: (s.data?.docs ?? []).map((doc) {
              final d = doc.data();
              final choices = List<String>.from(d['options']);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${d['question']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (d['authorId'] == uid || ownerId == uid)
                            IconButton(
                              tooltip: d['closed'] == true
                                  ? 'Oylamayı aç'
                                  : 'Oylamayı bitir',
                              onPressed: () => _act(
                                context,
                                () => doc.reference.update({
                                  'closed': d['closed'] != true,
                                }),
                              ),
                              icon: Icon(
                                d['closed'] == true
                                    ? Icons.lock
                                    : Icons.lock_open,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: doc.reference.collection('votes').snapshots(),
                        builder: (_, v) {
                          final votes = v.data?.docs ?? [];
                          final mine = votes
                              .where((v) => v.id == uid)
                              .firstOrNull
                              ?.data()['choice'];
                          return Column(
                            children: [
                              for (var i = 0; i < choices.length; i++)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    mine == i
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: mine == i
                                        ? AppColors.cyan
                                        : AppColors.textMuted,
                                  ),
                                  title: Text(choices[i]),
                                  trailing: Text(
                                    '${votes.where((v) => v.data()['choice'] == i).length}',
                                  ),
                                  onTap: d['closed'] == true || uid == null
                                      ? null
                                      : () => _act(
                                          context,
                                          () => doc.reference
                                              .collection('votes')
                                              .doc(uid)
                                              .set({
                                                'choice': i,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              }),
                                        ),
                                ),
                              Text(
                                '${votes.length} oy${d['closed'] == true ? ' · Oylama bitti' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}
