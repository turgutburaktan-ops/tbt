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

  Future<User> _authenticatedUser() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Oturumun sona ermiş. Yeniden giriş yapmalısın.');
    await user.getIdToken(true);
    return user;
  }

  Future<Map<String, dynamic>> claimStatus(String category, String venueId) async {
    await _authenticatedUser();
    final result = await _functions.httpsCallable('getBusinessClaim').call({
      'category': category,
      'venueId': venueId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> entitlementStatus(
    String category,
    String venueId,
  ) async {
    final result = await _functions.httpsCallable('getBusinessEntitlement').call({
      'venueKey': venueKey(category.trim(), venueId.trim()),
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
    final user = await _authenticatedUser();
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

  Future<void> updateProfile({
    required String category,
    required String venueId,
    required String description,
    required String phone,
    required String website,
    required String openingHours,
  }) async {
    await _authenticatedUser();
    await _functions.httpsCallable('updateBusinessProfile').call({
      'category': category,
      'venueId': venueId,
      'description': description,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
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
    await _authenticatedUser();
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
    await _authenticatedUser();
    await _functions.httpsCallable('addBusinessProgramItem').call({
      'category': category,
      'venueId': venueId,
      'title': title,
      'description': description,
      'startsAtMs': startsAt.millisecondsSinceEpoch,
    });
  }

  Future<void> addCampaign({
    required String category,
    required String venueId,
    required String title,
    required String description,
    required DateTime validUntil,
  }) async {
    await _authenticatedUser();
    await _functions.httpsCallable('addBusinessCampaign').call({
      'category': category,
      'venueId': venueId,
      'title': title,
      'description': description,
      'validUntilMs': validUntil.millisecondsSinceEpoch,
    });
  }
}
