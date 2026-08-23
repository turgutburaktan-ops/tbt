import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BusinessService {
  BusinessService._();
  static final instance = BusinessService._();

  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  String venueKey(String category, String venueId) => '$category:$venueId';

  Future<Map<String, dynamic>> claimStatus(String category, String venueId) async {
    final result = await _functions.httpsCallable('getBusinessClaim').call({
      'category': category,
      'venueId': venueId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

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
    if (!await evidenceImage.exists() || await evidenceImage.length() <= 0) {
      throw Exception('Yetki kanıtı fotoğrafı zorunlu.');
    }
    if (await evidenceImage.length() > 15 * 1024 * 1024) {
      throw Exception('Kanıt görseli 15 MB sınırını aşıyor.');
    }

    final id = venueKey(category, venueId);
    final evidenceRef = _storage
        .ref()
        .child('users/${user.uid}/business_claims/$id/evidence.jpg');
    await evidenceRef.putFile(
      evidenceImage,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final evidenceUrl = await evidenceRef.getDownloadURL();

    await _functions.httpsCallable('submitBusinessClaim').call({
      'category': category,
      'venueId': venueId,
      'venueName': venueName,
      'businessEmail': businessEmail,
      'businessPhone': businessPhone,
      'legalName': legalName,
      'taxOffice': taxOffice,
      'taxNumberLast4': taxNumberLast4,
      'evidenceUrl': evidenceUrl,
      'evidenceStoragePath': evidenceRef.fullPath,
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
    await _functions.httpsCallable('addBusinessMenuItem').call({
      'category': category,
      'venueId': venueId,
      'name': name,
      'section': section,
      'description': description,
      'priceMinor': priceMinor,
    });
  }

  Future<void> addProgramItem({
    required String category,
    required String venueId,
    required String title,
    required DateTime startsAt,
    String description = '',
  }) async {
    await _functions.httpsCallable('addBusinessProgramItem').call({
      'category': category,
      'venueId': venueId,
      'title': title,
      'description': description,
      'startsAtMs': startsAt.millisecondsSinceEpoch,
    });
  }
}
