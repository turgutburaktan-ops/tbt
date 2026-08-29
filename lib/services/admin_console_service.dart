import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

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
    if (token.claims?['admin'] != true) {
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

    await _ensureFreshAdminAuth();
    final callable = _functions.httpsCallable('adminReviewBusinessClaim');
    try {
      await callable.call(payload);
      return;
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unauthenticated') rethrow;
    }

    // Some Android/native Functions SDK paths can fail to forward the current
    // Firebase Auth context to a callable even though the same user has a
    // valid admin claim. Fall back to a normal HTTPS endpoint and attach the
    // freshly minted Firebase ID token explicitly. The backend verifies this
    // token with Firebase Admin and still requires admin=true.
    final token = await _freshAdminIdToken();
    final response = await http
        .post(
          _businessReviewHttp,
          headers: <String, String>{
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'İşletme onayı tamamlanamadı.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
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
}

class AdminInsightsData {
  final Map<String, dynamic> counts;
  final List<Map<String, dynamic>> errors;

  const AdminInsightsData({required this.counts, required this.errors});

  int value(String key) => (counts[key] as num?)?.toInt() ?? 0;
}
