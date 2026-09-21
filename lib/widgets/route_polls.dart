import '../screens/route_poll_create_screen.dart';
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
    final result=await Navigator.push<RoutePollDraft>(context,MaterialPageRoute(builder:(_)=>const RoutePollCreateScreen()));
    if(result==null||!context.mounted)return;
    await _act(context,()=>_polls.add({
      'authorId':FirebaseAuth.instance.currentUser!.uid,'question':result.question,'options':result.options,
      'allowMultiple':result.multiple,if(result.closesAt!=null)'closesAt':Timestamp.fromDate(result.closesAt!),
      'closed':false,'createdAt':FieldValue.serverTimestamp(),
    }));
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
              final closed=d['closed']==true || (d['closesAt'] is Timestamp && !(d['closesAt'] as Timestamp).toDate().isAfter(DateTime.now()));
              List<int> selections(Map<String,dynamic> vote)=>vote['choices'] is List?List<int>.from(vote['choices']):vote['choice'] is int?[vote['choice']]:[];
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
                          if (v.hasError)
                            return Text(userFacingError(v.error!));
                          final votes = v.data?.docs ?? [];
                          final mine=selections(votes.where((v)=>v.id==uid).firstOrNull?.data()??{});
                          return Column(
                            children: [
                              for (var i = 0; i < choices.length; i++)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    mine.contains(i)
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: mine.contains(i)
                                        ? AppColors.cyan
                                        : AppColors.textMuted,
                                  ),
                                  title: Text(choices[i]),
                                  trailing: Text(
                                    '${votes.where((v) => selections(v.data()).contains(i)).length}',
                                  ),
                                  onTap: closed || uid == null
                                      ? null
                                      : () => _act(
                                          context,
                                          () => doc.reference
                                              .collection('votes')
                                              .doc(uid)
                                              .set({
                                                if(d['allowMultiple']==true)'choices': (({...mine}.contains(i)?({...mine}..remove(i)):({...mine}..add(i))).toList()..sort()),
                                                if(d['allowMultiple']!=true)'choice': i,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              }),
                                        ),
                                ),
                              Text(
                                '${votes.length} oy${closed ? ' · Oylama bitti' : ''}',
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
