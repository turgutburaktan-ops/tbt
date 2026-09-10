import 'package:cloud_firestore/cloud_firestore.dart';

int recordTimeMs(dynamic value) => value is Timestamp
    ? value.millisecondsSinceEpoch
    : value is DateTime
    ? value.millisecondsSinceEpoch
    : value is num
    ? value.toInt()
    : 0;
bool isActiveCoupon(Map<String, dynamic> data, DateTime now) =>
    data['status'] == 'ready' &&
    (data['token'] ?? '').toString().isNotEmpty &&
    recordTimeMs(data['validUntil']) > now.millisecondsSinceEpoch;
bool isActiveReservation(Map<String, dynamic> data, DateTime now) {
  if (!['pending', 'accepted'].contains(data['status'])) return false;
  final preparation = data['preparationStatus'];
  if (['completed', 'cancelled', 'no_show'].contains(preparation)) return false;
  if (['preparing', 'ready'].contains(preparation)) return true;
  return recordTimeMs(data['atMs'] ?? data['at']) >= now.millisecondsSinceEpoch;
}
