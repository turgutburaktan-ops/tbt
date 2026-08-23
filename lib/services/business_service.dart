import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BusinessService {
  BusinessService._();
  static final instance = BusinessService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String venueKey(String category, String venueId) => '$category:$venueId';

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchClaim(
    String category,
    String venueId,
  ) => _db.collection('business_claims').doc(venueKey(category, venueId)).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMenu(
    String category,
    String venueId,
  ) => _db
      .collection('business_venues')
      .doc(venueKey(category, venueId))
      .collection('menu')
      .where('active', isEqualTo: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProgram(
    String category,
    String venueId,
  ) => _db
      .collection('business_venues')
      .doc(venueKey(category, venueId))
      .collection('program')
      .where('startsAt', isGreaterThanOrEqualTo: Timestamp.now())
      .snapshots();

  Future<void> submitClaim({
    required String category,
    required String venueId,
    required String venueName,
    required String businessEmail,
    required String businessPhone,
    required String legalName,
    required String taxOffice,
    required String taxNumberLast4,
    required File evidenceImage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('İşletme başvurusu için giriş yapmalısın.');
    if (!user.emailVerified) {
      throw Exception('Önce hesabındaki e-posta adresini doğrulamalısın.');
    }
    if (businessEmail.trim().isEmpty || businessPhone.trim().length < 10) {
      throw Exception('İşletme e-postası ve geçerli telefon zorunlu.');
    }
    if (legalName.trim().length < 3 || taxNumberLast4.trim().length != 4) {
      throw Exception('Yasal unvan ve vergi numarasının son 4 hanesi zorunlu.');
    }
    if (!await evidenceImage.exists() || await evidenceImage.length() <= 0) {
      throw Exception('Yetki kanıtı fotoğrafı zorunlu.');
    }
    if (await evidenceImage.length() > 15 * 1024 * 1024) {
      throw Exception('Kanıt görseli 15 MB sınırını aşıyor.');
    }

    final id = venueKey(category, venueId);
    final ref = _db.collection('business_claims').doc(id);
    final existing = await ref.get();
    final existingData = existing.data();
    if (existingData != null && existingData['status'] == 'verified') {
      throw Exception('Bu mekan zaten doğrulanmış bir işletme tarafından yönetiliyor.');
    }

    final evidenceRef = _storage
        .ref()
        .child('users/${user.uid}/business_claims/$id/evidence.jpg');
    await evidenceRef.putFile(
      evidenceImage,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final evidenceUrl = await evidenceRef.getDownloadURL();

    await ref.set({
      'venueKey': id,
      'venueId': venueId,
      'category': category,
      'venueName': venueName.trim(),
      'applicantUid': user.uid,
      'applicantEmail': user.email ?? '',
      'businessEmail': businessEmail.trim().toLowerCase(),
      'businessPhone': businessPhone.trim(),
      'legalName': legalName.trim(),
      'taxOffice': taxOffice.trim(),
      'taxNumberLast4': taxNumberLast4.trim(),
      'evidenceUrl': evidenceUrl,
      'evidenceStoragePath': evidenceRef.fullPath,
      'status': 'pending_review',
      'verificationLevel': 'none',
      'adminReviewRequired': true,
      'riskFlags': <String>[],
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'verifiedAt': null,
      'verifiedBy': null,
      'rejectionReason': '',
    });
  }

  Future<void> addMenuItem({
    required String category,
    required String venueId,
    required String name,
    required String section,
    required int priceMinor,
    String description = '',
  }) async {
    final owner = await _assertVerifiedOwner(category, venueId);
    final venueRef = _db.collection('business_venues').doc(venueKey(category, venueId));
    await venueRef.set({
      'ownerUid': owner,
      'category': category,
      'venueId': venueId,
      'verified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await venueRef.collection('menu').add({
      'name': name.trim(),
      'section': section.trim(),
      'description': description.trim(),
      'priceMinor': priceMinor,
      'currency': 'TRY',
      'active': true,
      'createdBy': owner,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addProgramItem({
    required String category,
    required String venueId,
    required String title,
    required DateTime startsAt,
    String description = '',
  }) async {
    final owner = await _assertVerifiedOwner(category, venueId);
    final venueRef = _db.collection('business_venues').doc(venueKey(category, venueId));
    await venueRef.set({
      'ownerUid': owner,
      'category': category,
      'venueId': venueId,
      'verified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await venueRef.collection('program').add({
      'title': title.trim(),
      'description': description.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'active': true,
      'createdBy': owner,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _assertVerifiedOwner(String category, String venueId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    final claim = await _db.collection('business_claims').doc(venueKey(category, venueId)).get();
    final data = claim.data();
    if (data == null || data['status'] != 'verified' || data['applicantUid'] != user.uid) {
      throw Exception('Menü ve program yönetimi yalnız doğrulanmış işletme sahibine açıktır.');
    }
    return user.uid;
  }
}
