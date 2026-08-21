import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsernameService {
  UsernameService._();

  static final UsernameService instance = UsernameService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String normalize(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  String cleanDisplay(String value) =>
      value.trim().replaceFirst(RegExp(r'^@'), '');

  String? validate(String value) {
    final clean = cleanDisplay(value);
    if (clean.length < 3) return 'Kullanıcı adı en az 3 karakter olmalı.';
    if (clean.length > 30) return 'Kullanıcı adı en fazla 30 karakter olabilir.';
    if (!RegExp(r'^[A-Za-z0-9_.ÇĞİÖŞÜçğıöşü]+$').hasMatch(clean)) {
      return 'Kullanıcı adı yalnızca harf, sayı, nokta ve alt çizgi içerebilir.';
    }
    if (clean.startsWith('.') || clean.endsWith('.')) {
      return 'Kullanıcı adı nokta ile başlayamaz veya bitemez.';
    }
    if (clean.contains('..')) {
      return 'Kullanıcı adında art arda iki nokta kullanılamaz.';
    }
    return null;
  }

  Future<bool> isAvailable(String value) async {
    final validation = validate(value);
    if (validation != null) return false;
    final normalized = normalize(value);
    final doc = await _firestore.collection('usernames').doc(normalized).get();
    final currentUid = _auth.currentUser?.uid;
    return !doc.exists || doc.data()?['uid'] == currentUid;
  }

  Future<void> reserveForCurrentUser(String value) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı adı seçmek için giriş yapmalısın.');

    final validation = validate(value);
    if (validation != null) throw Exception(validation);

    final username = cleanDisplay(value);
    final normalized = normalize(username);
    final userRef = _firestore.collection('users').doc(user.uid);
    final usernameRef = _firestore.collection('usernames').doc(normalized);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final usernameSnapshot = await transaction.get(usernameRef);
      final oldNormalized =
          (userSnapshot.data()?['usernameNormalized'] ?? '').toString();

      DocumentSnapshot<Map<String, dynamic>>? oldReservation;
      DocumentReference<Map<String, dynamic>>? oldRef;
      if (oldNormalized.isNotEmpty && oldNormalized != normalized) {
        oldRef = _firestore.collection('usernames').doc(oldNormalized);
        oldReservation = await transaction.get(oldRef);
      }

      if (usernameSnapshot.exists &&
          (usernameSnapshot.data()?['uid'] ?? '').toString() != user.uid) {
        throw Exception('Bu kullanıcı adı zaten alınmış.');
      }

      transaction.set(
        usernameRef,
        {
          'uid': user.uid,
          'username': username,
          'normalized': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!usernameSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        userRef,
        {
          'uid': user.uid,
          'username': username,
          'usernameNormalized': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (oldRef != null &&
          oldReservation?.exists == true &&
          (oldReservation?.data()?['uid'] ?? '').toString() == user.uid) {
        transaction.delete(oldRef);
      }
    });
  }

  Future<String?> ownerUid(String value) async {
    final normalized = normalize(value);
    if (normalized.isEmpty) return null;
    final doc = await _firestore.collection('usernames').doc(normalized).get();
    if (!doc.exists) return null;
    final uid = (doc.data()?['uid'] ?? '').toString().trim();
    return uid.isEmpty ? null : uid;
  }
}
