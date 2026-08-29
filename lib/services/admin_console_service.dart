import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminConsoleService {
  AdminConsoleService._();
  static final instance = AdminConsoleService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
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
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unauthenticated') rethrow;
      // The native Functions SDK can briefly retain the previous auth token
      // after a custom-claim refresh. Refresh once and retry the admin action.
      await _ensureFreshAdminAuth();
      await callable.call(payload);
    }
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
