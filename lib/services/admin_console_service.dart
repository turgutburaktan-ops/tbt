import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'admin_access.dart';

class AdminConsoleService {
  AdminConsoleService._();
  static final instance = AdminConsoleService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static final Uri _businessReviewHttp = Uri.parse(
    'https://europe-west1-en-iyi-cekim-noktasi.cloudfunctions.net/adminReviewBusinessClaimHttp',
  );

  Future<void> _ensureFreshAdminAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Yönetici işlemi için giriş gerekli.',
      );
    }
    await current.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Yönetici oturumu bulunamadı.',
      );
    }
    await refreshed.getIdToken(true);
    final token = await refreshed.getIdTokenResult();
    if (!AdminAccess.tokenMatches(refreshed, token)) {
      throw FirebaseAuthException(
        code: 'admin-claim-missing',
        message: 'Yönetici yetkisi doğrulanamadı.',
      );
    }
  }

  Future<String> _freshAdminIdToken() async {
    await _ensureFreshAdminAuth();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Yönetici oturumu bulunamadı.',
      );
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'token-missing',
        message: 'Yönetici kimlik belirteci alınamadı.',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> overview() async {
    await _ensureFreshAdminAuth();
    final result = await _functions.httpsCallable('adminGetOverview').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<List<Map<String, dynamic>>> recentUsers({int limit = 60}) async {
    await _ensureFreshAdminAuth();
    final result = await _functions
        .httpsCallable('adminListRecentUsers')
        .call({'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> businessClaims({int limit = 120}) async {
    await _ensureFreshAdminAuth();
    final result = await _functions
        .httpsCallable('getAdminBusinessClaims')
        .call({'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> reviewBusinessClaim({
    required String category,
    required String venueId,
    required bool approve,
    String reason = '',
  }) async {
    final payload = <String, dynamic>{
      'category': category,
      'venueId': venueId,
      'decision': approve ? 'verified' : 'rejected',
      'reason': reason.trim(),
    };

    // Business review intentionally bypasses the callable transport. On some
    // Android builds the native Functions SDK has returned UNAUTHENTICATED
    // despite Firebase Auth exposing a valid admin claim. Send the freshly
    // minted Firebase ID token explicitly and let the backend verify it with
    // Firebase Admin before applying the review.
    final token = await _freshAdminIdToken();
    final response = await http
        .post(
          _businessReviewHttp,
          headers: <String, String>{
            'authorization': 'Bearer $token',
            'content-type': 'application/json; charset=utf-8',
            'accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String code = 'http-${response.statusCode}';
    String message = 'İşletme onayı tamamlanamadı.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (decoded['error'] != null) code = decoded['error'].toString();
        if (decoded['message'] != null) message = decoded['message'].toString();
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        message = response.body.trim();
      }
    }
    throw Exception('[$code / HTTP ${response.statusCode}] $message');
  }

  Future<AdminInsightsData> insights() async {
    await _ensureFreshAdminAuth();
    final result = await _functions.httpsCallable('getAdminInsights').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final counts = Map<String, dynamic>.from(
      (data['counts'] as Map?) ?? const {},
    );
    final errors = ((data['errors'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return AdminInsightsData(counts: counts, errors: errors);
  }

  Future<void> deleteVenue({
    required String collection,
    required String id,
  }) async {
    await _ensureFreshAdminAuth();
    await _functions.httpsCallable('adminDeleteVenue').call({
      'collection': collection,
      'id': id,
    });
  }
}

class AdminInsightsData {
  final Map<String, dynamic> counts;
  final List<Map<String, dynamic>> errors;

  const AdminInsightsData({required this.counts, required this.errors});

  int value(String key) => (counts[key] as num?)?.toInt() ?? 0;
}
